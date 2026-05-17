import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/insight_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/insights_provider.dart';
import 'radar_chart_widget.dart';

const _kDimensionOrder = [
  'overallMood',
  'workStress',
  'teamHarmony',
  'personalGrowth',
  'workLifeBalance',
];

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsStreamProvider);
    final user = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İçgörülerim'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(insightsStreamProvider),
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: insightsAsync.when(
        loading: () => const _InsightsSkeleton(),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (insights) {
          if (insights == null) {
            return _EmptyState(
              onCheckin: () => context.go('/checkin'),
            );
          }
          return _InsightsContent(insights: insights, userRole: user?.role ?? 'free');
        },
      ),
    );
  }
}

// ─── Content ──────────────────────────────────────────────────────────────────

class _InsightsContent extends StatelessWidget {
  const _InsightsContent({
    required this.insights,
    required this.userRole,
  });

  final InsightModel insights;
  final String userRole;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMMM yyyy', 'tr_TR');

    final hasPro = userRole == 'pro' || userRole == 'enterprise' || userRole == 'daas';

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScoreCard(
              personalAvg: insights.personalAverage,
              companyAvg: insights.companyAverage,
              trend: insights.trend,
              lastUpdated: dateFormat.format(insights.updatedAt),
              totalCheckins: insights.totalCheckins,
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boyut Analizi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '5 boyutlu refah haritanız',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 20),
                    RadarChartWidget(
                      personalScores: insights.personalList,
                      companyScores: hasPro && insights.companyList.isNotEmpty
                          ? insights.companyList
                          : null,
                      benchmarkScores:
                          insights.benchmarkList.isNotEmpty
                              ? insights.benchmarkList
                              : null,
                    ),
                    if (!hasPro) ...[
                      const SizedBox(height: 12),
                      _ProUpgradeBanner(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boyut Detayları',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(
                      AppConstants.checkinDimensions.length,
                      (i) {
                        final key = _kDimensionOrder[i];
                        final personal = insights.personalScores[key] ?? 0;
                        final company = insights.companyScores?[key];
                        return _DimensionRow(
                          dimension: AppConstants.checkinDimensions[i],
                          personalScore: personal,
                          companyScore: hasPro ? company : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Score Card ───────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.personalAvg,
    required this.companyAvg,
    required this.trend,
    required this.lastUpdated,
    required this.totalCheckins,
  });

  final double personalAvg;
  final double companyAvg;
  final int? trend;
  final String lastUpdated;
  final int totalCheckins;

  String _trendLabel(int? trend) {
    if (trend == null) return '';
    if (trend > 0) return '↑ İyileşiyor';
    if (trend < 0) return '↓ Düşüyor';
    return '→ Stabil';
  }

  Color _trendColor(BuildContext context, int? trend) {
    if (trend == null) return Colors.transparent;
    if (trend > 0) return const Color(0xFF4CAF50);
    if (trend < 0) return const Color(0xFFF44336);
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Color _scoreColor(double score) {
    if (score >= 4) return const Color(0xFF4CAF50);
    if (score >= 3) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Genel Skor',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            personalAvg.toStringAsFixed(1),
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _scoreColor(personalAvg),
                                ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6, left: 4),
                            child: Text('/5.0'),
                          ),
                        ],
                      ),
                      if (trend != null)
                        Text(
                          _trendLabel(trend),
                          style: TextStyle(
                            color: _trendColor(context, trend),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatBadge(
                      icon: Icons.calendar_today_rounded,
                      label: '$totalCheckins check-in',
                    ),
                    const SizedBox(height: 6),
                    _StatBadge(
                      icon: Icons.update_rounded,
                      label: lastUpdated,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Dimension row ────────────────────────────────────────────────────────────

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimension,
    required this.personalScore,
    this.companyScore,
  });

  final String dimension;
  final double personalScore;
  final double? companyScore;

  Color _barColor(double score) {
    if (score >= 4.0) return const Color(0xFF4CAF50);
    if (score >= 3.0) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dimension,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Row(
                children: [
                  Text(
                    personalScore.toStringAsFixed(1),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _barColor(personalScore),
                    ),
                  ),
                  if (companyScore != null) ...[
                    Text(
                      ' / ${companyScore!.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: Colors.transparent,
                ),
              ),
              if (companyScore != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: companyScore! / 5,
                    minHeight: 8,
                    backgroundColor: Colors.transparent,
                    color: const Color(AppConstants.colorCompany).withOpacity(0.4),
                  ),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: personalScore / 5,
                  minHeight: 8,
                  backgroundColor: Colors.transparent,
                  color: _barColor(personalScore),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Pro upgrade banner ───────────────────────────────────────────────────────

class _ProUpgradeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded,
              color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Şirket karşılaştırması için Pro plana geçin.',
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => GoRouter.of(context).go('/subscription'),
            child: Text(
              'Yükselt',
              style: TextStyle(color: scheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCheckin});

  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Henüz veri yok',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'İçgörülerinizi görmek için ilk check-in\'inizi yapın.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCheckin,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Check-in Yap'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _InsightsSkeleton extends StatelessWidget {
  const _InsightsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _SkeletonBox(height: 110, borderRadius: 16),
          const SizedBox(height: 16),
          _SkeletonBox(height: 340, borderRadius: 16),
          const SizedBox(height: 16),
          _SkeletonBox(height: 240, borderRadius: 16),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height, required this.borderRadius});

  final double height;
  final double borderRadius;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(_animation.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'İçgörüler yüklenemedi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
