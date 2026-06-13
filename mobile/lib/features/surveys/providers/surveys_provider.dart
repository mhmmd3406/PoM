import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../data/survey_aggregate.dart';
import '../data/survey_benchmark.dart';
import '../data/survey_model.dart';
import '../data/survey_scoring.dart';
import '../data/surveys_repository.dart';

export '../data/survey_model.dart';
export '../data/surveys_repository.dart' show hashUserId, surveysRepositoryProvider;

// All surveys visible to the current user (admin + company), unfiltered by status.
final _eligibleSurveysProvider = StreamProvider<List<SurveyModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref
      .watch(surveysRepositoryProvider)
      .watchEligibleSurveys(user.companyId);
});

// Set of surveyIds the current user has already answered. Sourced from the
// user document's answeredSurveyIds (loaded at sign-in, refreshed locally after
// each submit) — NOT from a survey_responses query, which firestore.rules
// restrict to admins / company members and which caused PERMISSION_DENIED for
// platform (__admin__) surveys.
final myResponseSurveyIdsProvider = Provider<Set<String>>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.answeredSurveyIds.toSet() ?? <String>{};
});

// Active surveys the user hasn't answered yet.
final pendingSurveysProvider = Provider<AsyncValue<List<SurveyModel>>>((ref) {
  final surveys = ref.watch(_eligibleSurveysProvider);
  final answered = ref.watch(myResponseSurveyIdsProvider);
  return surveys.whenData((list) {
    return list
        .where((s) =>
            s.status == SurveyStatus.active && !answered.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  });
});

// Surveys the current user has already answered.
final completedSurveysProvider = Provider<AsyncValue<List<SurveyModel>>>((ref) {
  final surveys = ref.watch(_eligibleSurveysProvider);
  final answered = ref.watch(myResponseSurveyIdsProvider);
  return surveys.whenData((list) {
    return list
        .where((s) => answered.contains(s.id))
        .toList()
      ..sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  });
});

// Single survey by Firestore document ID.
final surveyByIdProvider =
    FutureProvider.family<SurveyModel?, String>((ref, id) {
  return ref.watch(surveysRepositoryProvider).getSurvey(id);
});

// ─── Experience-survey personal result ────────────────────────────────────────

/// A "deep experience survey" is any answered survey whose questions carry
/// categories (the weekly check-in is a separate flow; ordinary company surveys
/// without categories are skipped). This is the 48-question Genel Çalışan
/// Deneyimi Anketi in practice.
bool _isExperienceSurvey(SurveyModel s) =>
    s.questions.any((q) => q.category != null && q.category!.isNotEmpty);

/// The current user's OWN scored breakdown for their most recent answered
/// experience survey. Computed entirely client-side from the owner-readable
/// `users/{uid}.surveyAnswers` map + the shared [survey_scoring] engine — no
/// `survey_responses` read (firestore.rules block it). Drives the home
/// "Deneyim Karnem" card and the insights survey section. Returns null when the
/// user hasn't completed an experience survey yet (or answers aren't on-device).
class ExperienceResult {
  const ExperienceResult({
    required this.survey,
    required this.overall,
    required this.categories,
    required this.enps,
  });

  final SurveyModel survey;
  final double overall; // 1–5, unweighted mean of category scores
  final List<CategoryResult> categories; // sorted high → low
  final PersonalEnps? enps;

  ScoreBand get band => scoreBand(overall);
  CategoryResult get strongest => categories.first;
  CategoryResult get weakest => categories.last;
  bool get hasDistinctWeakest =>
      categories.length > 1 && weakest.name != strongest.name;
}

final experienceResultProvider = Provider<ExperienceResult?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final completed = ref.watch(completedSurveysProvider).valueOrNull ?? const [];
  final experienceSurveys = completed.where(_isExperienceSurvey).toList()
    ..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  if (experienceSurveys.isEmpty) return null;

  final survey = experienceSurveys.first;
  final answers = user.surveyAnswers[survey.id];
  if (answers == null || answers.isEmpty) return null;

  final categories = calcCategoryScores(survey.questions, answers)
    ..sort((a, b) => b.score.compareTo(a.score));
  if (categories.isEmpty) return null;

  final overall =
      categories.map((c) => c.score).reduce((a, b) => a + b) /
          categories.length;
  final enps = classifyEnps(survey.questions, answers);

  return ExperienceResult(
    survey: survey,
    overall: overall,
    categories: categories,
    enps: enps,
  );
});

// ─── Survey aggregate (company / department / sector — Cloud Function) ─────────

/// Min-N-protected company aggregate for a survey, read from
/// `survey_aggregates/{surveyId}__{companyId}` (written by the
/// computeSurveyAggregate CF). Drives the insights "Karşılaştırma" view.
/// firestore.rules only allow the caller to read their own company's doc.
final surveyAggregateProvider = FutureProvider.family<SurveyAggregate?,
    ({String surveyId, String companyId})>((ref, args) async {
  final db = ref.watch(firestoreProvider);
  final doc = await db
      .collection('survey_aggregates')
      .doc('${args.surveyId}__${args.companyId}')
      .get();
  if (!doc.exists) return null;
  return SurveyAggregate.fromFirestore(doc);
});

// ─── Cross-company survey benchmark (Şirket Karşılaştırması) ───────────────────

/// The experience survey to benchmark — the answered one if available, else the
/// most recent categorized survey the user is eligible for (so the comparison
/// works even before the user completes it; "Sen" is just omitted until then).
final experienceSurveyIdProvider = Provider<String?>((ref) {
  final answered = ref.watch(experienceResultProvider);
  if (answered != null) return answered.survey.id;
  final eligible = ref.watch(_eligibleSurveysProvider).valueOrNull ?? const [];
  final exp = eligible.where(_isExperienceSurvey).toList()
    ..sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return exp.isEmpty ? null : exp.first.id;
});

/// Cross-company, min-N-protected survey benchmark from `survey_benchmarks/{id}`
/// (written by computeSurveyAggregate). Readable by any authenticated user —
/// anonymized company + sector averages. Drives the "Şirket Karşılaştırması"
/// survey comparison.
final surveyBenchmarkProvider =
    FutureProvider.family<SurveyBenchmark?, String>((ref, surveyId) async {
  final db = ref.watch(firestoreProvider);
  final doc =
      await db.collection('survey_benchmarks').doc(surveyId).get();
  if (!doc.exists) return null;
  return SurveyBenchmark.fromFirestore(doc);
});
