import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/surveys_provider.dart';

// ─── Screen ────────────────────────────────────────────────────────────────────

class SurveysScreen extends ConsumerStatefulWidget {
  const SurveysScreen({super.key});

  @override
  ConsumerState<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends ConsumerState<SurveysScreen> {
  String _activeTab = 'active';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink3    = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final bgAlt   = isDark ? AppColors.darkBgAlt    : AppColors.lightBgAlt;
    final border  = isDark ? AppColors.borderDark   : AppColors.borderLight;

    final pendingAsync   = ref.watch(pendingSurveysProvider);
    final completedAsync = ref.watch(completedSurveysProvider);

    final pendingList   = pendingAsync.valueOrNull   ?? [];
    final completedList = completedAsync.valueOrNull ?? [];
    final isLoading     = pendingAsync.isLoading || completedAsync.isLoading;

    final surveys = _activeTab == 'completed' ? completedList : pendingList;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Anketler',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (isLoading)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink3,
                      ),
                    ),
                ],
              ),
            ),

            // Tab pill
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: bgAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _TabSegment(
                      label: 'Aktif',
                      count: pendingList.length,
                      active: _activeTab == 'active',
                      surface: surface,
                      ink: ink,
                      ink3: ink3,
                      onTap: () => setState(() => _activeTab = 'active'),
                    ),
                    _TabSegment(
                      label: 'Tamamlanan',
                      count: completedList.length,
                      active: _activeTab == 'completed',
                      surface: surface,
                      ink: ink,
                      ink3: ink3,
                      onTap: () => setState(() => _activeTab = 'completed'),
                    ),
                  ],
                ),
              ),
            ),

            // Survey list
            Expanded(
              child: isLoading && surveys.isEmpty
                  ? _LoadingSkeleton(surface: surface, border: border)
                  : surveys.isEmpty
                      ? _SurveysEmptyState(
                          activeTab: _activeTab, ink: ink, ink3: ink3)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          itemCount: surveys.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _SurveyCard(
                            survey: surveys[i],
                            isDone: _activeTab == 'completed',
                            isDark: isDark,
                            surface: surface,
                            border: border,
                            ink: ink,
                            ink3: ink3,
                            bgAlt: bgAlt,
                          ),
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          const routes = ['/', '/checkin', '/insights', '/surveys', '/profile'];
          context.go(routes[index]);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Check-in',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'İçgörüler',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Anketler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// ─── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.surface, required this.border});
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _SurveysEmptyState extends StatelessWidget {
  const _SurveysEmptyState({
    required this.activeTab,
    required this.ink,
    required this.ink3,
  });

  final String activeTab;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final (emoji, title, subtitle) = activeTab == 'completed'
        ? ('📋', 'Henüz tamamlanan yok',
            'Yanıtladığın anketler burada görünecek.')
        : ('📭', 'Şu an aktif anket yok',
            'Bir sonraki anket yakında gelecek.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ink,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: ink3, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab segment ───────────────────────────────────────────────────────────────

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.label,
    required this.count,
    required this.active,
    required this.surface,
    required this.ink,
    required this.ink3,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final Color surface;
  final Color ink;
  final Color ink3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? ink : ink3,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.blueSoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        active ? AppColors.blueDeep : ink3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Survey card ───────────────────────────────────────────────────────────────

class _SurveyCard extends StatelessWidget {
  const _SurveyCard({
    required this.survey,
    required this.isDone,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
    required this.bgAlt,
  });

  final SurveyModel survey;
  final bool isDone;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;
  final Color bgAlt;

  String _deadlineLabel() {
    final d = survey.deadline;
    if (d == null) return '';
    return DateFormat('d MMM', 'tr_TR').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final sourceLabel =
        survey.isAdminSurvey ? 'PoM Platform' : 'Şirketiniz';

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isDone
            ? null
            : () => context.push('/survey/${survey.id}/answer'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bgAlt,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(survey.emoji,
                        style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          survey.title,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: ink,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$sourceLabel · ${survey.questionCount} soru',
                          style: TextStyle(fontSize: 11.5, color: ink3),
                        ),
                      ],
                    ),
                  ),
                  if (isDone)
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.sage)
                  else
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: ink3),
                ],
              ),

              // Participation row
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'KATILIM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ink3,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(width: 3, height: 3, decoration: BoxDecoration(color: ink3, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    '${survey.responseCount} yanıt',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDone ? AppColors.sageDeep : ink3,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isDone
                        ? 'Tamamlandı ✓'
                        : survey.deadline != null
                            ? '${_deadlineLabel()}\'a kadar'
                            : 'Süresiz',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? AppColors.sageDeep
                          : (isDark ? AppColors.darkInk2 : AppColors.lightInk2),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: survey.minNThreshold > 0
                      ? (survey.responseCount / survey.minNThreshold)
                          .clamp(0.0, 1.0)
                      : 0,
                  minHeight: 3,
                  backgroundColor: isDark
                      ? AppColors.darkBgAlt
                      : AppColors.lightBgAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDone ? AppColors.sage : AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
