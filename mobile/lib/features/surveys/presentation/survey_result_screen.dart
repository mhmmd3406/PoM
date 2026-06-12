import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/survey_scoring.dart';
import '../providers/surveys_provider.dart';

/// Personal survey result view. Renders the current user's OWN answers as a
/// scored breakdown (category scores + eNPS group + strongest/weakest areas)
/// using the shared [survey_scoring] engine. Source data is the owner-readable
/// `users/{uid}.surveyAnswers[surveyId]` map — the app cannot read the
/// aggregate `survey_responses` (firestore.rules restrict it).
class SurveyResultScreen extends ConsumerWidget {
  const SurveyResultScreen({super.key, required this.surveyId});

  final String surveyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final ink = isDark ? AppColors.darkInk : AppColors.lightInk;
    final ink2 = isDark ? AppColors.darkInk2 : AppColors.lightInk2;
    final ink3 = isDark ? AppColors.darkInk3 : AppColors.lightInk3;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final surveyAsync = ref.watch(surveyByIdProvider(surveyId));
    final user = ref.watch(currentUserProvider);
    final answers = user?.surveyAnswers[surveyId];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ink2),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/surveys'),
        ),
        title: Text(
          'Sonuçların',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: surveyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _MessageState(
            emoji: '⚠️',
            title: 'Anket yüklenemedi',
            message: 'Lütfen daha sonra tekrar deneyin.',
            ink: ink,
            ink2: ink2,
          ),
          data: (survey) {
            if (survey == null) {
              return _MessageState(
                emoji: '🔍',
                title: 'Anket bulunamadı',
                message: 'Bu anket artık mevcut değil.',
                ink: ink,
                ink2: ink2,
              );
            }
            if (answers == null || answers.isEmpty) {
              return _MessageState(
                emoji: '📭',
                title: 'Sonuçlar kaydedilmedi',
                message:
                    'Bu anketin kişisel sonuçları cihazında bulunamadı. Sonuçlar '
                    'yalnızca anketi bu uygulamadan yanıtlayan hesabın için saklanır.',
                ink: ink,
                ink2: ink2,
              );
            }

            final categories = calcCategoryScores(survey.questions, answers);
            final enps = classifyEnps(survey.questions, answers);

            // Overall: mean of category scores when categories exist, else the
            // mean of every normalizable answer so there is still a headline.
            double? overall;
            if (categories.isNotEmpty) {
              overall =
                  categories.map((c) => c.score).reduce((a, b) => a + b) /
                      categories.length;
            } else {
              final all = <double>[];
              for (final q in survey.questions) {
                final n = normalizeAnswer(answers[q.id], q.type,
                    reverseScore: q.reverseScore);
                if (n != null) all.add(n);
              }
              if (all.isNotEmpty) {
                overall = all.reduce((a, b) => a + b) / all.length;
              }
            }

            final sortedCats = [...categories]
              ..sort((a, b) => b.score.compareTo(a.score));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SurveyHeader(
                  emoji: survey.emoji,
                  title: survey.title,
                  ink: ink,
                  ink3: ink3,
                ),
                const SizedBox(height: 16),

                if (overall != null) ...[
                  _OverallCard(
                    overall: overall,
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink3: ink3,
                  ),
                  const SizedBox(height: 12),
                ],

                if (enps != null) ...[
                  _EnpsCard(
                    enps: enps,
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                    ink3: ink3,
                  ),
                  const SizedBox(height: 12),
                ],

                if (sortedCats.isNotEmpty) ...[
                  _CategoryCard(
                    categories: sortedCats,
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                    ink3: ink3,
                  ),
                  const SizedBox(height: 12),
                  _HighlightCards(
                    strongest: sortedCats.first,
                    weakest: sortedCats.last,
                    ink: ink,
                    ink2: ink2,
                  ),
                ] else
                  _MessageInline(
                    message:
                        'Bu ankette kategori bazlı skorlama yok. Yukarıdaki genel '
                        'skor, tüm sayısal yanıtlarının ortalamasıdır.',
                    surface: surface,
                    border: border,
                    ink2: ink2,
                  ),

                const SizedBox(height: 16),
                _PrivacyNote(ink3: ink3),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _SurveyHeader extends StatelessWidget {
  const _SurveyHeader({
    required this.emoji,
    required this.title,
    required this.ink,
    required this.ink3,
  });

  final String emoji;
  final String title;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KİŞİSEL SONUÇLARIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: ink3,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1.2,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Overall score card ──────────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  const _OverallCard({
    required this.overall,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final double overall;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final band = scoreBand(overall);
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: band.wash,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  overall.toStringAsFixed(1),
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: band.color,
                    height: 1.0,
                  ),
                ),
                Text('/ 5', style: TextStyle(fontSize: 11, color: ink3)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GENEL DEĞERLENDİRME',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ink3,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  band.label,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: band.color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  riskLabel(overall),
                  style: TextStyle(fontSize: 12.5, color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Personal eNPS card ──────────────────────────────────────────────────────

class _EnpsCard extends StatelessWidget {
  const _EnpsCard({
    required this.enps,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final PersonalEnps enps;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: enps.color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${enps.score}',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: enps.color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAVSİYE SKORUN (eNPS)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ink3,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enps.label,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: enps.color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enps.sublabel,
                  style: TextStyle(fontSize: 12.5, color: ink2, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Category heatmap card ───────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.categories,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final List<CategoryResult> categories;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KATEGORİ SKORLARIN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ink3,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(categories.length, (i) {
            final cat = categories[i];
            final band = scoreBand(cat.score);
            return Padding(
              padding:
                  EdgeInsets.only(bottom: i < categories.length - 1 ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cat.score.toStringAsFixed(1),
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: band.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ((cat.score - 1) / 4).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: band.wash,
                      valueColor: AlwaysStoppedAnimation<Color>(band.color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Strongest / weakest highlight cards ─────────────────────────────────────

class _HighlightCards extends StatelessWidget {
  const _HighlightCards({
    required this.strongest,
    required this.weakest,
    required this.ink,
    required this.ink2,
  });

  final CategoryResult strongest;
  final CategoryResult weakest;
  final Color ink;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    // Only show a distinct "weakest" card when there is more than one category.
    final showWeakest = weakest.name != strongest.name;
    return Column(
      children: [
        _HighlightCard(
          badge: 'EN GÜÇLÜ ALANIN',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.sageDeep,
          bgColor: AppColors.sageWash,
          borderColor: AppColors.sage,
          subject: strongest.name,
          description:
              '${strongest.score.toStringAsFixed(1)}/5 ile en yüksek skorun. '
              'Bu alandaki güçlü deneyimin sürüyor.',
          ink: ink,
          ink2: ink2,
        ),
        if (showWeakest) ...[
          const SizedBox(height: 10),
          _HighlightCard(
            badge: 'GELİŞİME AÇIK ALAN',
            icon: Icons.flag_rounded,
            color: AppColors.amberDeep,
            bgColor: AppColors.amberWash,
            borderColor: AppColors.amber,
            subject: weakest.name,
            description:
                '${weakest.score.toStringAsFixed(1)}/5 ile en düşük skorun. '
                'Bu boyut senin için zorlayıcı olabilir.',
            ink: ink,
            ink2: ink2,
          ),
        ],
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.badge,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.subject,
    required this.description,
    required this.ink,
    required this.ink2,
  });

  final String badge;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String subject;
  final String description;
  final Color ink;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subject,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 12.5, color: ink2, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ─── Inline + privacy notes ──────────────────────────────────────────────────

class _MessageInline extends StatelessWidget {
  const _MessageInline({
    required this.message,
    required this.surface,
    required this.border,
    required this.ink2,
  });

  final String message;
  final Color surface;
  final Color border;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: ink2, height: 1.5),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.ink3});

  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 14, color: ink3),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Bu sonuçlar yalnızca sana özeldir ve cihazındaki hesabına bağlıdır. '
            'Yöneticilerin yalnızca anonim, toplu sonuçları görür.',
            style: TextStyle(fontSize: 11.5, color: ink3, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ─── Full-screen message state ───────────────────────────────────────────────

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.emoji,
    required this.title,
    required this.message,
    required this.ink,
    required this.ink2,
  });

  final String emoji;
  final String title;
  final String message;
  final Color ink;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ink2, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
