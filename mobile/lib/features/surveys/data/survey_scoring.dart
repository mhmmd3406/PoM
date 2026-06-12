import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'survey_model.dart';

/// Survey scoring engine — pure Dart, UI-independent.
///
/// Ported from the admin portal's single source of truth
/// (admin/src/pages/portal/PortalSurveyResultsPage.tsx, lines 9–134) so the
/// mobile personal-result view and the web aggregate view stay numerically
/// consistent. The mobile app cannot read `survey_responses` (firestore.rules
/// restrict it to admins / company members), so the only data available here is
/// the user's OWN answers — this computes a *personal* breakdown, not the team
/// aggregate. Team aggregation needs a Cloud Function (out of scope).

/// Normalize any single answer to a 1–5 scale. Returns null for text / invalid.
///
/// Mirrors `normalizeAnswer` in the TSX engine, with one mobile-specific twist:
/// emoji5 answers are stored 0-indexed on mobile (`survey_answer_screen.dart`
/// emits the tapped index 0..4), whereas the web stores 1..5. We therefore add
/// 1 to emoji5 values before scoring so both platforms agree.
double? normalizeAnswer(
  Object? answer,
  SurveyQuestionType type, {
  bool reverseScore = false,
}) {
  if (answer == null) return null;
  switch (type) {
    case SurveyQuestionType.emoji5:
      // Mobile stores 0..4; map to 1..5.
      final n = answer is int
          ? answer
          : (answer is num ? answer.toInt() : null);
      if (n == null) return null;
      final v = n + 1;
      if (v < 1 || v > 5) return null;
      return v.toDouble();
    case SurveyQuestionType.scale5:
      final n = answer is num ? answer.toDouble() : null;
      if (n == null || n < 1 || n > 5) return null;
      return n;
    case SurveyQuestionType.scale10:
      final n = answer is num ? answer.toDouble() : null;
      if (n == null || n < 0 || n > 10) return null;
      // Map 0–10 → 1–5 linearly: score = (n/10)*4 + 1.
      return (n / 10) * 4 + 1;
    case SurveyQuestionType.yesno:
    case SurveyQuestionType.trueFalse:
      if (answer is! bool) return null;
      // reverseScore=true: positively-framed Evet is bad (mobbing, overtime…).
      return answer
          ? (reverseScore ? 1.0 : 5.0)
          : (reverseScore ? 5.0 : 1.0);
    case SurveyQuestionType.text:
      return null; // text questions carry no numeric score
  }
}

class CategoryResult {
  const CategoryResult({
    required this.name,
    required this.score,
    required this.count,
  });

  final String name;
  final double score; // 1–5 average
  final int count; // number of contributing questions
}

/// Per-category 1–5 averages for a single respondent.
///
/// For one user each question has at most one answer, so a category's score is
/// simply the mean of its normalizable answers.
List<CategoryResult> calcCategoryScores(
  List<SurveyQuestion> questions,
  Map<String, Object?> answers,
) {
  final catScores = <String, List<double>>{};

  for (final q in questions) {
    final cat = q.category?.trim();
    if (cat == null || cat.isEmpty || q.type == SurveyQuestionType.text) {
      continue;
    }
    final norm = normalizeAnswer(answers[q.id], q.type,
        reverseScore: q.reverseScore);
    if (norm == null) continue;
    catScores.putIfAbsent(cat, () => []).add(norm);
  }

  return catScores.entries.map((e) {
    final avg = e.value.reduce((a, b) => a + b) / e.value.length;
    return CategoryResult(name: e.key, score: avg, count: e.value.length);
  }).toList();
}

enum EnpsGroup { promoter, passive, detractor }

class PersonalEnps {
  const PersonalEnps({required this.score, required this.group});

  final int score; // raw 0–10
  final EnpsGroup group;

  String get label => switch (group) {
        EnpsGroup.promoter => 'Destekleyen',
        EnpsGroup.passive => 'Pasif',
        EnpsGroup.detractor => 'Eleştiren',
      };

  String get sublabel => switch (group) {
        EnpsGroup.promoter => '9–10 · Şirketini tavsiye edersin',
        EnpsGroup.passive => '7–8 · Memnunsun ama isteksizsin',
        EnpsGroup.detractor => '0–6 · Tavsiye etme olasılığın düşük',
      };

  Color get color => switch (group) {
        EnpsGroup.promoter => AppColors.sage,
        EnpsGroup.passive => AppColors.amber,
        EnpsGroup.detractor => AppColors.rose,
      };
}

/// Classify this user's own eNPS answer (the population −100…+100 metric is
/// meaningless for n=1, so we surface their individual group instead).
PersonalEnps? classifyEnps(
  List<SurveyQuestion> questions,
  Map<String, Object?> answers,
) {
  final q = questions.where((q) =>
      q.isEnps && q.type == SurveyQuestionType.scale10);
  if (q.isEmpty) return null;
  final raw = answers[q.first.id];
  if (raw is! num) return null;
  final score = raw.toInt();
  if (score < 0 || score > 10) return null;
  final group = score >= 9
      ? EnpsGroup.promoter
      : score >= 7
          ? EnpsGroup.passive
          : EnpsGroup.detractor;
  return PersonalEnps(score: score, group: group);
}

class ScoreBand {
  const ScoreBand({
    required this.label,
    required this.color,
    required this.wash,
  });

  final String label;
  final Color color; // primary accent / text
  final Color wash; // soft background
}

/// 1–5 → qualitative band. Mirrors `scoreBand` (TSX 114–119), mapped onto the
/// PoM palette: high = sage, mid = amber, low = rose.
ScoreBand scoreBand(double score) {
  if (score >= 4.21) {
    return const ScoreBand(
        label: 'Çok Yüksek', color: AppColors.sageDeep, wash: AppColors.sageWash);
  }
  if (score >= 3.41) {
    return const ScoreBand(
        label: 'Yüksek', color: AppColors.sage, wash: AppColors.sageWash);
  }
  if (score >= 2.61) {
    return const ScoreBand(
        label: 'Orta', color: AppColors.amberDeep, wash: AppColors.amberWash);
  }
  if (score >= 1.81) {
    return const ScoreBand(
        label: 'Düşük', color: AppColors.amberDeep, wash: AppColors.amberWash);
  }
  return const ScoreBand(
      label: 'Çok Düşük', color: AppColors.rose, wash: AppColors.roseSoft);
}

/// 1–5 → risk label. Mirrors `riskLevel` (TSX 128–134).
String riskLabel(double score) {
  if (score >= 4.2) return 'Düşük Risk';
  if (score >= 3.5) return 'İzleme Gerekli';
  if (score >= 2.8) return 'Orta Risk';
  if (score >= 2.0) return 'Yüksek Risk';
  return 'Kritik Risk';
}
