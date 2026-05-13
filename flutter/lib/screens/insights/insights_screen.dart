import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/radar_chart.dart';

// ── Provider ───────────────────────────────────────────────────────────────

final _insightsProvider = FutureProvider.autoDispose
    .family<InsightData?, ({String bankId, int year, int month})>(
        (ref, args) async {
  return ref.read(firestoreServiceProvider).queryInsights(
        bankId: args.bankId,
        year: args.year,
        month: args.month,
      );
});

// ── Screen ─────────────────────────────────────────────────────────────────

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final args = (bankId: user.uid, year: now.year, month: now.month);
    final async = ref.watch(_insightsProvider(args));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights'),
        actions: [
          TextButton(
            onPressed: () => ref.invalidate(_insightsProvider(args)),
            child: const Text('Refresh'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(e.toString()),
        data: (data) => data == null
            ? const _PrivacyGateView()
            : _InsightsBody(data: data),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────

class _InsightsBody extends StatelessWidget {
  const _InsightsBody({required this.data});
  final InsightData data;

  static const _metricKeys = ['salary', 'benefits', 'work_model', 'culture', 'wlb'];
  static const _metricLabels = ['Salary', 'Benefits', 'Work Model', 'Culture', 'WLB'];
  static const _metricIcons = ['💰', '🎁', '🏠', '🤝', '⚖️'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period header
            _PeriodHeader(data: data).animate().fadeIn().slideY(begin: 0.15),
            const SizedBox(height: 24),

            // Radar chart
            Center(
              child: _RadarSection(data: data),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 28),

            // Per-metric bars
            Text('Metric Breakdown',
                    style: Theme.of(context).textTheme.titleMedium)
                .animate()
                .fadeIn(delay: 160.ms),
            const SizedBox(height: 14),

            ...List.generate(_metricKeys.length, (i) {
              final key = _metricKeys[i];
              final bank = data.bankAverages[key] ?? 0;
              final sector = data.sectorAverages?[key];
              return _MetricBar(
                icon: _metricIcons[i],
                label: _metricLabels[i],
                bankScore: bank,
                sectorScore: sector,
                i: i,
              );
            }),

            const SizedBox(height: 20),
            _LegendRow(hasSector: data.sectorAverages != null)
                .animate()
                .fadeIn(delay: 500.ms),
          ],
        ),
      );
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.data});
  final InsightData data;

  @override
  Widget build(BuildContext context) {
    final period = DateFormat('MMMM yyyy')
        .format(DateTime(data.year, data.month));
    final overall = data.overallScore;
    final color = overall >= 4
        ? AppColors.positive
        : overall >= 3
            ? AppColors.warning
            : AppColors.negative;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(period,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 2),
              const Text('Your Bank\'s Score',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text('${data.bankEntryCount} responses',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        // Overall score orb
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.5), width: 2),
          ),
          child: Center(
            child: Text(
              overall.toStringAsFixed(1),
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _RadarSection extends StatelessWidget {
  const _RadarSection({required this.data});
  final InsightData data;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          RadarChart(
            bankValues: data.bankAverages,
            sectorValues: data.sectorAverages,
            size: 260,
          ),
          const SizedBox(height: 8),
          if (data.sectorAverages != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: AppColors.accent, label: 'Your Bank'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.warning, label: 'Sector Avg', dashed: true),
              ],
            ),
        ],
      );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, this.dashed = false});
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 12,
            height: 3,
            decoration: BoxDecoration(
              color: dashed ? Colors.transparent : color,
              border: dashed ? Border.all(color: color) : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.icon,
    required this.label,
    required this.bankScore,
    required this.sectorScore,
    required this.i,
  });
  final String icon;
  final String label;
  final double bankScore;
  final double? sectorScore;
  final int i;

  @override
  Widget build(BuildContext context) {
    final pct = bankScore / 5.0;
    final color = bankScore >= 4
        ? AppColors.positive
        : bankScore >= 3
            ? AppColors.warning
            : AppColors.negative;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              Text(bankScore.toStringAsFixed(1),
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              if (sectorScore != null) ...[
                const SizedBox(width: 4),
                Text('/ ${sectorScore!.toStringAsFixed(1)} avg',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              // Background track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Sector avg line
              if (sectorScore != null)
                FractionallySizedBox(
                  widthFactor: sectorScore! / 5.0,
                  child: Container(
                    height: 8,
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: 2,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              // Bank fill
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ).animate().fadeIn(delay: (i * 60 + 200).ms).slideX(begin: 0.1),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.hasSector});
  final bool hasSector;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _LegendItem(
                color: AppColors.positive, label: '4.0 – 5.0  Thriving'),
            _LegendItem(
                color: AppColors.warning, label: '3.0 – 3.9  Average'),
            _LegendItem(
                color: AppColors.negative, label: '< 3.0  Needs attention'),
            if (hasSector) ...[
              const Divider(height: 14),
              Row(
                children: [
                  Container(
                    width: 2,
                    height: 12,
                    color: AppColors.warning.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  const Text('Vertical bar = sector average',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
}

// ── Privacy gate ──────────────────────────────────────────────────────────

class _PrivacyGateView extends StatelessWidget {
  const _PrivacyGateView();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.accent.withOpacity(0.3), width: 2),
                ),
                child: const Center(
                  child: Text('🔒', style: TextStyle(fontSize: 36)),
                ),
              ).animate().scale(
                  begin: const Offset(0.6, 0.6), curve: Curves.elasticOut),
              const SizedBox(height: 24),
              const Text('Your Privacy is Protected',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700))
                  .animate()
                  .fadeIn(delay: 200.ms),
              const SizedBox(height: 10),
              Text(
                'Insights are only shown when 7+ employees from your bank have shared a pulse. This protects individual anonymity.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14, height: 1.5),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Invite Colleagues'),
              ).animate().fadeIn(delay: 450.ms),
            ],
          ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 14)),
            ],
          ),
        ),
      );
}
