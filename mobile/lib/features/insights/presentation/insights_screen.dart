import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pro_gate.dart';
import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../surveys/data/survey_aggregate.dart';
import '../../surveys/data/survey_scoring.dart';
import '../../surveys/providers/surveys_provider.dart';
import '../providers/insights_provider.dart';
import 'radar_chart_widget.dart';

// ─── Dimension metadata ────────────────────────────────────────────────────────

const _kDimensionOrder = [
  'overallMood',
  'workStress',
  'teamHarmony',
  'personalGrowth',
  'workLifeBalance',
];

const _kDimensionMeta = [
  _DimensionMeta(key: 'overallMood',      label: 'Ruh Hali', emoji: '😊', color: AppColors.blue),
  _DimensionMeta(key: 'workStress',       label: 'Stres',    emoji: '😌', color: AppColors.amber),
  _DimensionMeta(key: 'teamHarmony',      label: 'Takım',    emoji: '🤝', color: AppColors.sage),
  _DimensionMeta(key: 'personalGrowth',   label: 'Gelişim',  emoji: '🌱', color: Color(0xFF8AA67A)),
  _DimensionMeta(key: 'workLifeBalance',  label: 'Denge',    emoji: '⚖️', color: AppColors.blue),
];

const _kFakeDeltas = [0.4, -0.2, 0.5, 0.0, 0.3];

// Trend chart series data
const _kTrendSeries = [
  [3.6, 3.8, 4.0, 4.2], // blue  – Ruh Hali
  [3.8, 3.6, 3.7, 3.5], // amber – Stres
  [4.0, 4.2, 4.3, 4.5], // sage  – Takım
  [4.0, 4.0, 4.0, 4.0], // moss  – Gelişim
  [3.7, 3.8, 3.9, 4.0], // sky   – Denge
];

const _kTrendColors = [
  AppColors.blue,
  AppColors.amber,
  AppColors.sage,
  Color(0xFF8AA67A), // moss
  Color(0xFFA6C6E8), // sky
];

const _kXLabels = ['H-3', 'H-2', 'H-1', 'Bu'];

// ─── Screen ────────────────────────────────────────────────────────────────────

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _selectedView = 'personal';

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsStreamProvider);
    final isPro = ref.watch(currentUserProvider)?.isPro ?? false;
    final experience = ref.watch(experienceResultProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg      = isDark ? AppColors.darkBg      : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface  : AppColors.lightSurface;
    final ink     = isDark ? AppColors.darkInk      : AppColors.lightInk;
    final ink2    = isDark ? AppColors.darkInk2     : AppColors.lightInk2;
    final ink3    = isDark ? AppColors.darkInk3     : AppColors.lightInk3;
    final border  = isDark ? AppColors.borderDark   : AppColors.borderLight;
    final bgAlt   = isDark ? AppColors.darkBgAlt    : AppColors.lightBgAlt;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: insightsAsync.when(
          loading: () => const _InsightsSkeleton(),
          error: (e, _) => _ErrorState(message: e.toString()),
          data: (insights) {
            // The survey result is independent of check-in data: a user may
            // have completed the Genel Anket without any check-ins. Only fall
            // back to the full-screen empty state when BOTH are absent.
            if (insights == null) {
              if (experience == null) {
                return _EmptyState(isDark: isDark, ink: ink, ink2: ink2);
              }
              return _SurveyOnlyView(
                experience: experience,
                surface: surface,
                ink: ink,
                ink2: ink2,
                ink3: ink3,
                border: border,
              );
            }
            return _InsightsContent(
              insights: insights,
              experience: experience,
              selectedView: _selectedView,
              onViewChanged: (v) => setState(() => _selectedView = v),
              isPro: isPro,
              isDark: isDark,
              bg: bg,
              surface: surface,
              ink: ink,
              ink2: ink2,
              ink3: ink3,
              border: border,
              bgAlt: bgAlt,
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
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

// ─── Full content ──────────────────────────────────────────────────────────────

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({
    required this.insights,
    required this.experience,
    required this.selectedView,
    required this.onViewChanged,
    required this.isPro,
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
    required this.bgAlt,
  });

  final InsightModel insights;
  final ExperienceResult? experience;
  final String selectedView;
  final ValueChanged<String> onViewChanged;
  final bool isPro;
  final bool isDark;
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;
  final Color bgAlt;

  @override
  Widget build(BuildContext context) {
    final personalList = insights.personalList;
    final companyList  = insights.companyList.isNotEmpty ? insights.companyList : null;

    // Derive highlight data from personalScores
    final scores = insights.personalScores;
    final sortedKeys = _kDimensionOrder
        .where((k) => scores.containsKey(k))
        .toList()
      ..sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));

    final strongestKey = sortedKeys.isNotEmpty ? sortedKeys.first : null;
    final weakestKey   = sortedKeys.length > 1  ? sortedKeys.last  : null;

    final strongestMeta = strongestKey != null
        ? _kDimensionMeta.firstWhere((m) => m.key == strongestKey,
            orElse: () => _kDimensionMeta.first)
        : null;
    final weakestMeta = weakestKey != null
        ? _kDimensionMeta.firstWhere((m) => m.key == weakestKey,
            orElse: () => _kDimensionMeta.last)
        : null;

    // Advanced views are Pro-only: free users see a blurred teaser + upsell.
    final companyLocked = selectedView == 'company' && !isPro;
    final comparisonLocked = selectedView == 'comparison' && !isPro;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Page header ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'İçgörüler',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                // F4: entry point to the Pro 6-company benchmark page. Previously
                // /benchmarking existed but was unreachable from the UI. The route
                // itself shows a Pro upsell for non-Pro users, so this is safe for
                // everyone.
                GestureDetector(
                  onTap: () => context.push('/benchmarking'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bar_chart_rounded,
                            size: 16, color: AppColors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Karşılaştır',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: ink),
                        ),
                        if (!isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amberDeep,
                                  letterSpacing: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Genel Deneyim Anketi section (the "esas veri") ───────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _SurveyInsightsSection(
              experience: experience,
              surface: surface,
              border: border,
              ink: ink,
              ink2: ink2,
              ink3: ink3,
            ),
          ),
        ),

        // ── Weekly-pulse section header (delineates the two data worlds) ─────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text(
              'HAFTALIK NABIZ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ink3,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),

        // ── Toggle pill ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: _TogglePill(
              selected: selectedView,
              onChanged: onViewChanged,
              isPro: isPro,
              isDark: isDark,
              bgAlt: bgAlt,
              surface: surface,
              ink: ink,
              ink3: ink3,
            ),
          ),
        ),

        if (selectedView != 'comparison') ...[
          if (companyLocked) ...[
            // ── Locked 'Şirket' view: blurred radar+trend teaser + upsell ─────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ProGate(
                  locked: true,
                  title: 'Şirket görünümü Pro\'ya özel',
                  message: 'Şirketinin boyut bazında nabzını ve haftalık '
                      'trendini Pro ile gör.',
                  child: Column(
                    children: [
                      _RadarCard(
                        displayScore: insights.companyAverage,
                        personalList: personalList,
                        companyList: companyList,
                        isDark: isDark,
                        surface: surface,
                        border: border,
                        ink: ink,
                        ink3: ink3,
                      ),
                      const SizedBox(height: 12),
                      _TrendCard(
                        isDark: isDark,
                        surface: surface,
                        border: border,
                        ink: ink,
                        ink2: ink2,
                        ink3: ink3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // ── Radar card ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _RadarCard(
                  displayScore: selectedView == 'company'
                      ? insights.companyAverage
                      : insights.personalAverage,
                  personalList: personalList,
                  companyList: companyList,
                  isDark: isDark,
                  surface: surface,
                  border: border,
                  ink: ink,
                  ink3: ink3,
                ),
              ),
            ),

            // ── Trend lines card ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _TrendCard(
                  isDark: isDark,
                  surface: surface,
                  border: border,
                  ink: ink,
                  ink2: ink2,
                  ink3: ink3,
                ),
              ),
            ),

            // ── Delta cards ─────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _DeltaSection(
                  insights: insights,
                  isDark: isDark,
                  surface: surface,
                  border: border,
                  ink: ink,
                  ink2: ink2,
                  ink3: ink3,
                ),
              ),
            ),

            // ── Highlights ──────────────────────────────────────────────────────
            if (strongestMeta != null || weakestMeta != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _HighlightsSection(
                    scores: scores,
                    strongestMeta: strongestMeta,
                    weakestMeta: weakestMeta,
                    ink: ink,
                    ink2: ink2,
                  ),
                ),
              ),
          ],
        ] else ...[
          // ── Comparison content (Pro-only) ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ProGate(
                locked: comparisonLocked,
                title: 'Karşılaştırma Pro\'ya özel',
                message: 'Departman kırılımı ve sektör benchmark\'larını '
                    'Pro ile aç.',
                child: _SurveyComparisonSection(
                  experience: experience,
                  surface: surface,
                  border: border,
                  ink: ink,
                  ink2: ink2,
                  ink3: ink3,
                  bgAlt: bgAlt,
                ),
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

// ─── Toggle pill ───────────────────────────────────────────────────────────────

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.selected,
    required this.onChanged,
    required this.isPro,
    required this.isDark,
    required this.bgAlt,
    required this.surface,
    required this.ink,
    required this.ink3,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final bool isPro;
  final bool isDark;
  final Color bgAlt;
  final Color surface;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bgAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _PillSegment(
            label: 'Sen',
            active: selected == 'personal',
            surface: surface,
            ink: ink,
            ink3: ink3,
            onTap: () => onChanged('personal'),
          ),
          _PillSegment(
            label: 'Şirket',
            active: selected == 'company',
            locked: !isPro,
            surface: surface,
            ink: ink,
            ink3: ink3,
            onTap: () => onChanged('company'),
          ),
          _PillSegment(
            label: 'Karşılaştırma',
            active: selected == 'comparison',
            locked: !isPro,
            surface: surface,
            ink: ink,
            ink3: ink3,
            onTap: () => onChanged('comparison'),
          ),
        ],
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  const _PillSegment({
    required this.label,
    required this.active,
    required this.surface,
    required this.ink,
    required this.ink3,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool active;
  final Color surface;
  final Color ink;
  final Color ink3;
  final VoidCallback onTap;
  final bool locked;

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
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (locked) ...[
                Icon(Icons.lock_rounded,
                    size: 11, color: active ? ink : ink3),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? ink : ink3,
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

// ─── Radar card ────────────────────────────────────────────────────────────────

class _RadarCard extends StatelessWidget {
  const _RadarCard({
    required this.displayScore,
    required this.personalList,
    required this.companyList,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final double displayScore;
  final List<double> personalList;
  final List<double>? companyList;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final avg = displayScore;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: label + score
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '5 BOYUT · SON 4 HAFTA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ink3,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${avg.toStringAsFixed(1)}/5',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        color: ink,
                        height: 1.0,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: legend
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendItem(
                    color: AppColors.blue,
                    label: 'Sen',
                    dashed: false,
                    ink3: ink3,
                  ),
                  const SizedBox(height: 6),
                  _LegendItem(
                    color: ink3,
                    label: 'Şirket',
                    dashed: true,
                    ink3: ink3,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Radar chart
          Center(
            child: RadarChartWidget(
              personalScores: personalList,
              companyScores: companyList,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.dashed,
    required this.ink3,
  });

  final Color color;
  final String label;
  final bool dashed;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!dashed)
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          )
        else
          SizedBox(
            width: 12,
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 2,
                    margin: EdgeInsets.only(right: i < 2 ? 2 : 0),
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ink3,
          ),
        ),
      ],
    );
  }
}

// ─── Trend card ────────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final bool isDark;
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son 4 Check-in',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBgAlt : AppColors.lightBgAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '4 Hafta',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ink3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chart
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(
              painter: _TrendChartPainter(
                isDark: isDark,
                dividerColor: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Dimension legend dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kDimensionMeta.length, (i) {
              final meta = _kDimensionMeta[i];
              final color = _kTrendColors[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: ink3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Trend chart painter ───────────────────────────────────────────────────────

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({
    required this.isDark,
    required this.dividerColor,
  });

  final bool isDark;
  final Color dividerColor;

  static const double _minY = 0.0;
  static const double _maxY = 5.0;
  static const double _leftPad  = 28.0;
  static const double _rightPad = 8.0;
  static const double _topPad   = 8.0;
  static const double _bottomPad = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width  - _leftPad - _rightPad;
    final chartH = size.height - _topPad  - _bottomPad;

    double xOf(int col) => _leftPad + col * chartW / (_kXLabels.length - 1);
    double yOf(double v) => _topPad + (1 - (v - _minY) / (_maxY - _minY)) * chartH;

    // ── Grid lines at y = 1, 2, 3, 4 ──────────────────────────────────────────
    final gridPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final labelStyle = TextStyle(
      color: isDark ? AppColors.darkInk3 : AppColors.lightInk3,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );

    for (final yVal in [1.0, 2.0, 3.0, 4.0]) {
      final y = yOf(yVal);
      canvas.drawLine(Offset(_leftPad, y), Offset(_leftPad + chartW, y), gridPaint);

      // Y label
      final tp = TextPainter(
        text: TextSpan(text: yVal.toInt().toString(), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // ── X axis labels ──────────────────────────────────────────────────────────
    for (int i = 0; i < _kXLabels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(text: _kXLabels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(xOf(i) - tp.width / 2, _topPad + chartH + 8),
      );
    }

    // ── Series lines + dots ────────────────────────────────────────────────────
    for (int s = 0; s < _kTrendSeries.length; s++) {
      final data  = _kTrendSeries[s];
      final color = _kTrendColors[s];

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < data.length; i++) {
        final x = xOf(i);
        final y = yOf(data[i]);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);

      // Dots
      for (int i = 0; i < data.length; i++) {
        final x = xOf(i);
        final y = yOf(data[i]);
        const r = 3.0;

        // White fill
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()..color = Colors.white,
        );
        // Colored stroke
        canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = color
            ..strokeWidth = 1.6
            ..style = PaintingStyle.stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrendChartPainter old) =>
      old.isDark != isDark || old.dividerColor != dividerColor;
}

// ─── Delta section ─────────────────────────────────────────────────────────────

class _DeltaSection extends StatelessWidget {
  const _DeltaSection({
    required this.insights,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final InsightModel insights;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final scores = insights.personalScores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'BOYUT BAZINDA DEĞİŞİM',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ink3,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // First 4 in 2-column grid
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _DeltaCard(
                    meta: _kDimensionMeta[0],
                    score: scores[_kDimensionMeta[0].key] ?? 3.0,
                    delta: _kFakeDeltas[0],
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),
                  const SizedBox(height: 8),
                  _DeltaCard(
                    meta: _kDimensionMeta[2],
                    score: scores[_kDimensionMeta[2].key] ?? 3.0,
                    delta: _kFakeDeltas[2],
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                children: [
                  _DeltaCard(
                    meta: _kDimensionMeta[1],
                    score: scores[_kDimensionMeta[1].key] ?? 3.0,
                    delta: _kFakeDeltas[1],
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),
                  const SizedBox(height: 8),
                  _DeltaCard(
                    meta: _kDimensionMeta[3],
                    score: scores[_kDimensionMeta[3].key] ?? 3.0,
                    delta: _kFakeDeltas[3],
                    surface: surface,
                    border: border,
                    ink: ink,
                    ink2: ink2,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Last card spans full width
        _DeltaCard(
          meta: _kDimensionMeta[4],
          score: scores[_kDimensionMeta[4].key] ?? 3.0,
          delta: _kFakeDeltas[4],
          surface: surface,
          border: border,
          ink: ink,
          ink2: ink2,
          fullWidth: true,
        ),
      ],
    );
  }
}

class _DeltaCard extends StatelessWidget {
  const _DeltaCard({
    required this.meta,
    required this.score,
    required this.delta,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    this.fullWidth = false,
  });

  final _DimensionMeta meta;
  final double score;
  final double delta;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isUp    = delta > 0;
    final isFlat  = delta == 0;
    final chipBg  = isFlat
        ? (border)
        : (isUp ? AppColors.sageWash : AppColors.amberWash);
    final chipFg  = isFlat
        ? ink2
        : (isUp ? AppColors.sageDeep : AppColors.amberDeep);
    final deltaStr = isFlat
        ? '±0.0'
        : (isUp ? '+${delta.toStringAsFixed(1)}' : delta.toStringAsFixed(1));

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(meta.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meta.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: ink2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  height: 1.0,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  deltaStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipFg,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Highlights section ────────────────────────────────────────────────────────

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({
    required this.scores,
    required this.strongestMeta,
    required this.weakestMeta,
    required this.ink,
    required this.ink2,
  });

  final Map<String, double> scores;
  final _DimensionMeta? strongestMeta;
  final _DimensionMeta? weakestMeta;
  final Color ink;
  final Color ink2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (strongestMeta != null)
          _HighlightCard(
            badge: 'EN GÜÇLÜ ALANIN',
            icon: Icons.auto_awesome_rounded,
            iconColor: AppColors.sageDeep,
            bgColor: AppColors.sageWash,
            borderColor: AppColors.sage,
            subject: '${strongestMeta!.emoji} ${strongestMeta!.label}',
            description:
                '${scores[strongestMeta!.key]?.toStringAsFixed(1) ?? '–'}/5 ile en yüksek skorun. '
                'Bu alandaki güçlü performansın devam ediyor.',
            ink: ink,
            ink2: ink2,
          ),
        if (strongestMeta != null && weakestMeta != null)
          const SizedBox(height: 10),
        if (weakestMeta != null)
          _HighlightCard(
            badge: 'DİKKAT EDİLECEK ALAN',
            icon: Icons.notifications_rounded,
            iconColor: AppColors.amberDeep,
            bgColor: AppColors.amberWash,
            borderColor: AppColors.amber,
            subject: '${weakestMeta!.emoji} ${weakestMeta!.label}',
            description:
                '${scores[weakestMeta!.key]?.toStringAsFixed(1) ?? '–'}/5 ile gelişime açık alan. '
                'Bu boyuta biraz daha dikkat etmeni öneririz.',
            ink: ink,
            ink2: ink2,
          ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.badge,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.subject,
    required this.description,
    required this.ink,
    required this.ink2,
  });

  final String badge;
  final IconData icon;
  final Color iconColor;
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
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
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
            style: TextStyle(
              fontSize: 12.5,
              color: ink2,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isDark,
    required this.ink,
    required this.ink2,
  });

  final bool isDark;
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.blueSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.blue,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Henüz check-in yok',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk haftalık check-in\'ini yaparak refah yolculuğuna başla. Sadece 60 saniye sürer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: ink2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/checkin'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'İlk Check-in\'i Yap',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 48),
            const SizedBox(height: 16),
            Text(
              'Bir hata oluştu',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.lightInk2),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ──────────────────────────────────────────────────────────────────

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shimmer = isDark ? const Color(0xFF1B2233) : const Color(0xFFEFE9DE);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonBox(width: 160, height: 32, color: shimmer),
          const SizedBox(height: 16),
          _SkeletonBox(width: double.infinity, height: 44, color: shimmer, radius: 12),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 280, color: shimmer, radius: 20),
          const SizedBox(height: 12),
          _SkeletonBox(width: double.infinity, height: 220, color: shimmer, radius: 20),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 8,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─── Survey-based comparison (Sen / Şirket / Sektör) ───────────────────────────

/// Replaces the old hard-coded comparison demo with the real Genel Anket
/// aggregate. "Sen" = the user's personal category scores (experienceResult,
/// computed on-device); "Şirket" / "Sektör" = min-N-protected aggregates from
/// survey_aggregates (computeSurveyAggregate CF). Below the company min-N the
/// company block is locked, so we show an honest notice instead of fabricated
/// numbers.
class _SurveyComparisonSection extends ConsumerWidget {
  const _SurveyComparisonSection({
    required this.experience,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.bgAlt,
  });

  final ExperienceResult? experience;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color bgAlt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exp = experience;
    final user = ref.watch(currentUserProvider);
    final companyId = user?.companyId;

    if (exp == null) {
      return _ComparisonNotice(
        surface: surface, border: border, ink: ink, ink2: ink2,
        emoji: '📋',
        title: 'Karşılaştırma için anketi tamamla',
        message: 'Genel Çalışan Deneyimi Anketi\'ni tamamladığında kendi '
            'skorlarını şirket ve sektör ortalamalarıyla karşılaştırabilirsin.',
      );
    }
    if (companyId == null) {
      return _ComparisonNotice(
        surface: surface, border: border, ink: ink, ink2: ink2,
        emoji: '🏢',
        title: 'Şirket bilgisi yok',
        message: 'Karşılaştırma için hesabının bir şirkete bağlı olması gerekir.',
      );
    }

    final aggAsync = ref.watch(surveyAggregateProvider(
        (surveyId: exp.survey.id, companyId: companyId)));

    return aggAsync.when(
      loading: () => _ComparisonNotice(
        surface: surface, border: border, ink: ink, ink2: ink2,
        emoji: '⏳', title: 'Yükleniyor',
        message: 'Şirket karşılaştırması hazırlanıyor…',
      ),
      error: (_, __) => _ComparisonNotice(
        surface: surface, border: border, ink: ink, ink2: ink2,
        emoji: '⚠️', title: 'Karşılaştırma yüklenemedi',
        message: 'Lütfen daha sonra tekrar dene.',
      ),
      data: (agg) {
        if (agg == null || agg.company.locked) {
          final n = agg?.company.n ?? 0;
          final floor = agg?.companyMinN ?? 15;
          return _ComparisonNotice(
            surface: surface, border: border, ink: ink, ink2: ink2,
            emoji: '🔒',
            title: 'Şirket sonuçları henüz gizli',
            message: 'Anonimliği korumak için şirket ortalaması en az $floor '
                'yanıt toplandığında görünür (şu an $n).',
          );
        }
        final company = agg.company;
        final sector = agg.sector;
        final personalCats = {for (final c in exp.categories) c.name: c.score};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ComparisonHero(
              personal: exp.overall,
              company: company.overall,
              sector: sector?.overall,
              surface: surface, border: border, ink: ink, ink2: ink2, ink3: ink3,
            ),
            const SizedBox(height: 12),
            _ComparisonCategoryCard(
              personalCats: personalCats,
              companyCats: company.categories,
              sectorCats: sector?.categories ?? const {},
              surface: surface, border: border, ink: ink, ink2: ink2, ink3: ink3,
            ),
            const SizedBox(height: 12),
            _DepartmentCard(
              department: user?.department,
              agg: agg,
              surface: surface, border: border, ink: ink, ink2: ink2, ink3: ink3,
            ),
          ],
        );
      },
    );
  }
}

const _kCmpPersonal = AppColors.blue;
const _kCmpCompany = AppColors.sage;
const _kCmpSector = Color(0xFFB8AE9C); // warm grey

class _ComparisonHero extends StatelessWidget {
  const _ComparisonHero({
    required this.personal,
    required this.company,
    required this.sector,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final double personal;
  final double? company;
  final double? sector;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final delta = company != null ? personal - company! : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GENEL · SEN vs ŞİRKET vs SEKTÖR',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: ink3, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _HeroStat(label: 'Sen', value: personal, color: _kCmpPersonal, ink: ink, ink3: ink3),
              _HeroDivider(border: border),
              _HeroStat(label: 'Şirket', value: company, color: _kCmpCompany, ink: ink, ink3: ink3),
              _HeroDivider(border: border),
              _HeroStat(label: 'Sektör', value: sector, color: _kCmpSector, ink: ink, ink3: ink3),
            ],
          ),
          if (delta != null) ...[
            const SizedBox(height: 12),
            Text(
              delta >= 0.05
                  ? 'Şirket ortalamasının ${delta.toStringAsFixed(1)} puan üzerindesin.'
                  : delta <= -0.05
                      ? 'Şirket ortalamasının ${delta.abs().toStringAsFixed(1)} puan altındasın.'
                      : 'Şirket ortalamasıyla aynı seviyedesin.',
              style: TextStyle(fontSize: 12.5, color: ink2, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
    required this.ink,
    required this.ink3,
  });

  final String label;
  final double? value;
  final Color color;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, color: ink3)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value != null ? value!.toStringAsFixed(1) : '—',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 26, fontWeight: FontWeight.w700, color: ink, height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider({required this.border});
  final Color border;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 38, color: border);
}

class _ComparisonCategoryCard extends StatelessWidget {
  const _ComparisonCategoryCard({
    required this.personalCats,
    required this.companyCats,
    required this.sectorCats,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final Map<String, double> personalCats;
  final Map<String, double> companyCats;
  final Map<String, double> sectorCats;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    // Show every category present anywhere, sorted by the personal score desc.
    final names = <String>{...personalCats.keys, ...companyCats.keys}.toList()
      ..sort((a, b) =>
          (personalCats[b] ?? companyCats[b] ?? 0)
              .compareTo(personalCats[a] ?? companyCats[a] ?? 0));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KATEGORİ BAZINDA',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: ink3, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Legend
          Wrap(
            spacing: 12,
            children: const [
              _LegendDot(color: _kCmpPersonal, label: 'Sen'),
              _LegendDot(color: _kCmpCompany, label: 'Şirket'),
              _LegendDot(color: _kCmpSector, label: 'Sektör'),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(names.length, (i) {
            final name = names[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < names.length - 1 ? 14 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500, color: ink),
                  ),
                  const SizedBox(height: 6),
                  _CmpBar(value: personalCats[name], color: _kCmpPersonal, ink3: ink3),
                  const SizedBox(height: 4),
                  _CmpBar(value: companyCats[name], color: _kCmpCompany, ink3: ink3),
                  const SizedBox(height: 4),
                  _CmpBar(value: sectorCats[name], color: _kCmpSector, ink3: ink3),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CmpBar extends StatelessWidget {
  const _CmpBar({required this.value, required this.color, required this.ink3});
  final double? value;
  final Color color;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final t = value != null ? ((value! - 1) / 4).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: t,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 26,
          child: Text(
            value != null ? value!.toStringAsFixed(1) : '—',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8577))),
      ],
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.agg,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final String? department;
  final SurveyAggregate agg;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final dept = department;
    final myDept = dept != null ? agg.departments[dept] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DEPARTMANIN',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: ink3, letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'n ≥ ${agg.departmentMinN} görünür',
                  style: TextStyle(fontSize: 10, color: ink3, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dept == null)
            Text('Departman bilgin yok.',
                style: TextStyle(fontSize: 13, color: ink2))
          else if (myDept == null)
            Text('"$dept" için veri bulunamadı.',
                style: TextStyle(fontSize: 13, color: ink2))
          else if (myDept.locked)
            Row(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$dept departmanı en az ${agg.departmentMinN} yanıt '
                    'toplandığında görünür (şu an ${myDept.n}).',
                    style: TextStyle(fontSize: 12.5, color: ink2, height: 1.4),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  myDept.overall!.toStringAsFixed(1),
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: _kCmpCompany, height: 1.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 4),
                  child: Text('/5', style: TextStyle(fontSize: 12, color: ink3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$dept · ${myDept.n} yanıt',
                    style: TextStyle(fontSize: 12.5, color: ink2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ComparisonNotice extends StatelessWidget {
  const _ComparisonNotice({
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.emoji,
    required this.title,
    required this.message,
  });

  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final String emoji;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 17, fontWeight: FontWeight.w600, color: ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: ink2, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ─── Dimension metadata value type ────────────────────────────────────────────

class _DimensionMeta {
  const _DimensionMeta({
    required this.key,
    required this.label,
    required this.emoji,
    required this.color,
  });

  final String key;
  final String label;
  final String emoji;
  final Color color;
}

// ─── Genel Deneyim Anketi section ──────────────────────────────────────────────

/// Personal result of the 48-question Genel Çalışan Deneyimi Anketi, rendered as
/// a top section in Insights (the survey is the product's primary data). Uses the
/// shared [survey_scoring] engine; aggregate/company comparison is Faz 2 (needs a
/// Cloud Function). When [experience] is null the user hasn't completed it yet, so
/// a CTA card invites them in.
class _SurveyInsightsSection extends StatelessWidget {
  const _SurveyInsightsSection({
    required this.experience,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
  });

  final ExperienceResult? experience;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;

  static const _months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];

  @override
  Widget build(BuildContext context) {
    final exp = experience;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 10),
          child: Text(
            'GENEL DENEYİM ANKETİ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: ink3,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (exp == null)
          _SurveyCtaCard(
            surface: surface,
            border: border,
            ink: ink,
            ink3: ink3,
          )
        else ...[
          _SurveyHeroCard(
            result: exp,
            surface: surface,
            border: border,
            ink: ink,
            ink2: ink2,
            ink3: ink3,
            monthLabel: exp.survey.createdAt != null
                ? '${_months[exp.survey.createdAt!.month - 1]} '
                    '${exp.survey.createdAt!.year}'
                : null,
          ),
          const SizedBox(height: 12),
          _SurveyCategoryCard(
            categories: exp.categories,
            surface: surface,
            border: border,
            ink: ink,
            ink3: ink3,
          ),
          const SizedBox(height: 12),
          _HighlightCard(
            badge: 'EN GÜÇLÜ ALANIN',
            icon: Icons.auto_awesome_rounded,
            iconColor: AppColors.sageDeep,
            bgColor: AppColors.sageWash,
            borderColor: AppColors.sage,
            subject: exp.strongest.name,
            description:
                '${exp.strongest.score.toStringAsFixed(1)}/5 ile en yüksek '
                'skorun. Bu alandaki güçlü deneyimin sürüyor.',
            ink: ink,
            ink2: ink2,
          ),
          if (exp.hasDistinctWeakest) ...[
            const SizedBox(height: 10),
            _HighlightCard(
              badge: 'GELİŞİME AÇIK ALAN',
              icon: Icons.flag_rounded,
              iconColor: AppColors.amberDeep,
              bgColor: AppColors.amberWash,
              borderColor: AppColors.amber,
              subject: exp.weakest.name,
              description:
                  '${exp.weakest.score.toStringAsFixed(1)}/5 ile en düşük '
                  'skorun. Bu boyut senin için zorlayıcı olabilir.',
              ink: ink,
              ink2: ink2,
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                context.push('/survey/${exp.survey.id}/result'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Detaylı sonuçları gör',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: AppColors.blue),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SurveyHeroCard extends StatelessWidget {
  const _SurveyHeroCard({
    required this.result,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.monthLabel,
  });

  final ExperienceResult result;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final String? monthLabel;

  @override
  Widget build(BuildContext context) {
    final band = result.band;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      result.overall.toStringAsFixed(1),
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
                    Row(
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
                        const Spacer(),
                        if (monthLabel != null)
                          Text(monthLabel!,
                              style: TextStyle(fontSize: 11, color: ink3)),
                      ],
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
                      riskLabel(result.overall),
                      style: TextStyle(fontSize: 12.5, color: ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (result.enps != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: result.enps!.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      size: 16, color: result.enps!.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12.5, color: ink2),
                        children: [
                          const TextSpan(text: 'Şirket bağlılığın: '),
                          TextSpan(
                            text: result.enps!.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: result.enps!.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurveyCategoryCard extends StatelessWidget {
  const _SurveyCategoryCard({
    required this.categories,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final List<CategoryResult> categories;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
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

class _SurveyCtaCard extends StatelessWidget {
  const _SurveyCtaCard({
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/surveys'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.blueSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_rounded,
                  color: AppColors.blue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deneyim karneni gör',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Genel anketi tamamladığında kişisel sonuçların burada belirir.',
                    style: TextStyle(fontSize: 12.5, color: ink3, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18, color: ink3),
          ],
        ),
      ),
    );
  }
}

/// Shown when the user has a survey result but no check-in data yet, so the
/// full-screen "no check-in" empty state would otherwise hide their survey
/// results. Renders the header + survey section + a compact check-in nudge.
class _SurveyOnlyView extends StatelessWidget {
  const _SurveyOnlyView({
    required this.experience,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.border,
  });

  final ExperienceResult experience;
  final Color surface;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Text(
            'İçgörüler',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: ink,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SurveyInsightsSection(
            experience: experience,
            surface: surface,
            border: border,
            ink: ink,
            ink2: ink2,
            ink3: ink3,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HAFTALIK NABIZ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ink3,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Henüz check-in yok',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'İlk haftalık check-in\'ini yaparak boyut bazında nabzını da '
                  'görmeye başla.',
                  style: TextStyle(fontSize: 13, color: ink2, height: 1.45),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.go('/checkin'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Check-in Yap',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
