import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
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

const _kFakeDeltas = [+0.4, -0.2, +0.5, +0.0, +0.3];

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
            if (insights == null) {
              return _EmptyState(isDark: isDark, ink: ink, ink2: ink2);
            }
            return _InsightsContent(
              insights: insights,
              selectedView: _selectedView,
              onViewChanged: (v) => setState(() => _selectedView = v),
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
    required this.selectedView,
    required this.onViewChanged,
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
  final String selectedView;
  final ValueChanged<String> onViewChanged;
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Page header ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Text(
              'İçgörülerim',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: ink,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),

        // ── Toggle pill ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: _TogglePill(
              selected: selectedView,
              onChanged: onViewChanged,
              isDark: isDark,
              bgAlt: bgAlt,
              surface: surface,
              ink: ink,
              ink3: ink3,
            ),
          ),
        ),

        // ── Radar card ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _RadarCard(
              insights: insights,
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

        // ── Trend lines card ──────────────────────────────────────────────────
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

        // ── Delta cards ───────────────────────────────────────────────────────
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

        // ── Highlights ────────────────────────────────────────────────────────
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
    required this.isDark,
    required this.bgAlt,
    required this.surface,
    required this.ink,
    required this.ink3,
  });

  final String selected;
  final ValueChanged<String> onChanged;
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
            surface: surface,
            ink: ink,
            ink3: ink3,
            onTap: () => onChanged('company'),
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
  });

  final String label;
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
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: active ? ink : ink3,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Radar card ────────────────────────────────────────────────────────────────

class _RadarCard extends StatelessWidget {
  const _RadarCard({
    required this.insights,
    required this.personalList,
    required this.companyList,
    required this.isDark,
    required this.surface,
    required this.border,
    required this.ink,
    required this.ink3,
  });

  final InsightModel insights;
  final List<double> personalList;
  final List<double>? companyList;
  final bool isDark;
  final Color surface;
  final Color border;
  final Color ink;
  final Color ink3;

  @override
  Widget build(BuildContext context) {
    final avg = insights.personalAverage;

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
              'Henüz veri yok',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İçgörülerin burada görüntülenmesi\niçin ilk check-in\'ini yap.',
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
                'İlk check-in\'ini yap',
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
