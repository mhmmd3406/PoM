import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/metric_bar.dart';

final _insightsProvider = FutureProvider.autoDispose
    .family<InsightData?, ({String bankId, int year, int month})>(
  (ref, args) => ref.read(firestoreServiceProvider).queryInsights(
        bankId: args.bankId,
        year: args.year,
        month: args.month,
      ),
);

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        return StreamBuilder<PomUser>(
          stream: ref.read(firestoreServiceProvider).userStream(user.uid),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            final pomUser = snap.data!;
            if (!pomUser.isProfileComplete) {
              return const Scaffold(
                body: Center(child: Text('Complete your profile first.')),
              );
            }
            return _InsightsBody(pomUser: pomUser);
          },
        );
      },
    );
  }
}

class _InsightsBody extends ConsumerStatefulWidget {
  const _InsightsBody({required this.pomUser});
  final PomUser pomUser;

  @override
  ConsumerState<_InsightsBody> createState() => _InsightsBodyState();
}

class _InsightsBodyState extends ConsumerState<_InsightsBody> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  @override
  Widget build(BuildContext context) {
    final args = (
      bankId: widget.pomUser.bankId!,
      year: _year,
      month: _month,
    );
    final insightsAsync = ref.watch(_insightsProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined),
            tooltip: 'Get More Credits',
            onPressed: () => context.push('/purchase'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_insightsProvider(args)),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _CreditBanner(credits: widget.pomUser.credits)
                  .animate()
                  .fadeIn(duration: 400.ms),
            ),
            SliverToBoxAdapter(
              child: _MonthSelector(
                year: _year,
                month: _month,
                onChanged: (y, m) => setState(() { _year = y; _month = m; }),
              ),
            ),
            SliverToBoxAdapter(
              child: insightsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(80),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ErrorCard(error: '$e'),
                data: (data) => data == null
                    ? const _InsufficientDataCard()
                    : _InsightCards(data: data),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditBanner extends StatelessWidget {
  const _CreditBanner({required this.credits});
  final int credits;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Text('$credits queries remaining',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textPrimary)),
            const Spacer(),
            if (credits == 0)
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/purchase'),
                child: const Text(
                  'Get More',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
          ],
        ),
      );
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.year,
    required this.month,
    required this.onChanged,
  });
  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy').format(DateTime(year, month));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Period', style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.textMuted)),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                iconSize: 20,
                onPressed: () {
                  final prev = DateTime(year, month - 1);
                  onChanged(prev.year, prev.month);
                },
              ),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                iconSize: 20,
                onPressed: DateTime(year, month)
                        .isBefore(DateTime.now())
                    ? () {
                        final next = DateTime(year, month + 1);
                        onChanged(next.year, next.month);
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCards extends StatelessWidget {
  const _InsightCards({required this.data});
  final InsightData data;

  static const _metricLabels = {
    'salary': ('💰', 'Salary'),
    'benefits': ('🏥', 'Benefits'),
    'work_model': ('🏠', 'Work Model'),
    'culture': ('🤝', 'Culture'),
    'wlb': ('⚖️', 'Work-Life Balance'),
    'overall': ('⭐', 'Overall'),
  };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Overall score hero
            _ScoreHero(score: data.overallScore)
                .animate()
                .scale(begin: const Offset(0.9, 0.9), duration: 500.ms,
                    curve: Curves.easeOutCubic),
            const SizedBox(height: 20),

            // Per-metric bars
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Breakdown',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    ...['salary', 'benefits', 'work_model', 'culture', 'wlb']
                        .map((key) {
                      final meta = _metricLabels[key]!;
                      final bankVal = data.bankAverages[key] ?? 0;
                      final sectorVal = data.sectorAverages?[key];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: MetricBar(
                          emoji: meta.$1,
                          label: meta.$2,
                          value: bankVal,
                          sectorValue: sectorVal,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.1, end: 0),

            const SizedBox(height: 12),
            if (data.sectorAverages != null)
              Row(children: [
                Container(width: 12, height: 3,
                    color: AppColors.accent.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text('Your bank    ',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Container(width: 12, height: 3,
                    color: AppColors.textMuted.withOpacity(0.5)),
                const SizedBox(width: 6),
                Text('Sector avg',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ]),
          ],
        ),
      );
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.ratingColors[((score - 1).clamp(0, 4)).round()];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(score.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: -2)),
          const SizedBox(height: 4),
          Text('Overall Happiness Score',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InsufficientDataCard extends StatelessWidget {
  const _InsufficientDataCard();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Text('🔒', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('Not enough data yet',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'We need at least 7 responses from your department to protect everyone\'s anonymity.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.negative, size: 40),
              const SizedBox(height: 12),
              Text(error,
                  style:
                      const TextStyle(color: AppColors.negative, fontSize: 13),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}
