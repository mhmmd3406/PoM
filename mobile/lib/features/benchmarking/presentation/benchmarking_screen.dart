import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/benchmarking_repository.dart';
import '../providers/benchmarking_provider.dart';

// Up to 6 companies; one color each.
const _kColors = [
  Color(0xFF2196F3),
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFFF44336),
  Color(0xFF00BCD4),
];

const _kDimOrder = [
  'overallMood',
  'workStress',
  'teamHarmony',
  'personalGrowth',
  'workLifeBalance',
];

const _kDimLabels = [
  'Ruh\nHali',
  'İş\nStresi',
  'Takım\nUyumu',
  'Kişisel\nGelişim',
  'İş-Yaşam\nDengesi',
];

const _kPeriods = [
  ('30d', 'Son 30 Gün'),
  ('90d', 'Son 90 Gün'),
  ('all', 'Tüm Zamanlar'),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class BenchmarkingScreen extends ConsumerWidget {
  const BenchmarkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companies = ref.watch(selectedCompaniesProvider);
    final period = ref.watch(selectedPeriodProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Şirket Karşılaştırması'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            _PeriodSelector(
              selected: period,
              onSelect: (p) =>
                  ref.read(selectedPeriodProvider.notifier).state = p,
            ),
            const SizedBox(height: 16),

            // Company chips + add button
            _CompanyChips(
              companies: companies,
              onAdd: () => _openSearch(context, ref, companies),
              onRemove: (c) {
                ref.read(selectedCompaniesProvider.notifier).update(
                      (list) => list.where((x) => x.id != c.id).toList(),
                    );
              },
            ),
            const SizedBox(height: 20),

            if (companies.isEmpty)
              const _EmptyState()
            else ...[
              // Period info banner
              _PeriodBanner(period: period, count: companies.length),
              const SizedBox(height: 16),

              // Line chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boyut Karşılaştırma Grafiği',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Her çizgi bir şirketi, her nokta bir refah boyutunu gösterir.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      _LineChart(companies: companies),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Score cards
              Text(
                'Genel Skor Özeti',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _ScoreGrid(companies: companies),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSearch(
    BuildContext context,
    WidgetRef ref,
    List<CompanySummary> current,
  ) async {
    if (current.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En fazla 6 şirket karşılaştırılabilir.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final result = await showModalBottomSheet<CompanySummary>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SearchSheet(alreadySelected: current),
    );
    if (result != null) {
      ref
          .read(selectedCompaniesProvider.notifier)
          .update((list) => [...list, result]);
    }
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onSelect,
  });

  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 15, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              'Dönem:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _kPeriods.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label:
                            Text(p.$2, style: const TextStyle(fontSize: 12)),
                        selected: p.$1 == selected,
                        onSelected: (_) => onSelect(p.$1),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Company chips ────────────────────────────────────────────────────────────

class _CompanyChips extends StatelessWidget {
  const _CompanyChips({
    required this.companies,
    required this.onAdd,
    required this.onRemove,
  });

  final List<CompanySummary> companies;
  final VoidCallback onAdd;
  final ValueChanged<CompanySummary> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Seçili Şirketler',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${companies.length}/6',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...companies.asMap().entries.map((e) {
              final color = _kColors[e.key % _kColors.length];
              return Chip(
                avatar: CircleAvatar(
                    backgroundColor: color, radius: 8),
                label: Text(e.value.name,
                    style: const TextStyle(fontSize: 13)),
                deleteIcon:
                    const Icon(Icons.close_rounded, size: 14),
                onDeleted: () => onRemove(e.value),
                backgroundColor: color.withOpacity(0.1),
                side: BorderSide(color: color.withOpacity(0.4)),
              );
            }),
            if (companies.length < 6)
              ActionChip(
                avatar:
                    const Icon(Icons.add_rounded, size: 16),
                label: const Text('Şirket Ekle',
                    style: TextStyle(fontSize: 13)),
                onPressed: onAdd,
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Period banner ────────────────────────────────────────────────────────────

class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner({required this.period, required this.count});

  final String period;
  final int count;

  String _label() {
    switch (period) {
      case '30d':
        return 'Son 30 Gün';
      case 'all':
        return 'Tüm Zamanlar';
      default:
        return 'Son 90 Gün';
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: scheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            '$count şirket · ${_label()} verileri',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Line Chart ───────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  const _LineChart({required this.companies});

  final List<CompanySummary> companies;

  List<LineChartBarData> _buildLines() {
    final lines = <LineChartBarData>[];
    for (int i = 0; i < companies.length; i++) {
      final c = companies[i];
      if (!c.hasEnoughData || c.scores == null) continue;
      final color = _kColors[i % _kColors.length];
      lines.add(LineChartBarData(
        spots: _kDimOrder.asMap().entries
            .map((e) => FlSpot(
                e.key.toDouble(), c.scores![e.value] ?? 3.0))
            .toList(),
        isCurved: true,
        curveSmoothness: 0.25,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 4.5,
            color: color,
            strokeColor: Colors.white,
            strokeWidth: 1.5,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(0.07),
        ),
      ));
    }
    return lines;
  }

  // Map bar index (only valid companies) back to the original company index.
  int _companyIndex(int barIndex) {
    int bar = 0;
    for (int i = 0; i < companies.length; i++) {
      if (companies[i].hasEnoughData && companies[i].scores != null) {
        if (bar == barIndex) return i;
        bar++;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = _buildLines();

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: lines.isEmpty
              ? Center(
                  child: Text(
                    'Seçili şirketler için yeterli veri yok.',
                    style:
                        TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 4,
                    minY: 1,
                    maxY: 5,
                    clipData: const FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      horizontalInterval: 1,
                      drawVerticalLine: true,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.outlineVariant.withOpacity(0.35),
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (_) => FlLine(
                        color: scheme.outlineVariant.withOpacity(0.2),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                          color:
                              scheme.outlineVariant.withOpacity(0.4)),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            if (value < 1 || value > 5) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 46,
                          getTitlesWidget: (value, _) {
                            final idx = value.round();
                            if ((value - idx).abs() > 0.01 ||
                                idx < 0 ||
                                idx >= _kDimLabels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _kDimLabels[idx],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: scheme.onSurface,
                                  height: 1.3,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: lines,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            scheme.surfaceContainerHigh,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (spots) {
                          return spots.map((spot) {
                            final ci = _companyIndex(spot.barIndex);
                            final color = _kColors[ci % _kColors.length];
                            final name = companies[ci].name.length > 14
                                ? '${companies[ci].name.substring(0, 14)}…'
                                : companies[ci].name;
                            return LineTooltipItem(
                              '$name\n',
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                              children: [
                                TextSpan(
                                  text: spot.y.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        // Legend
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: companies.asMap().entries.map((e) {
            final color = _kColors[e.key % _kColors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  e.value.name,
                  style:
                      Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─── Score grid ───────────────────────────────────────────────────────────────

class _ScoreGrid extends StatelessWidget {
  const _ScoreGrid({required this.companies});

  final List<CompanySummary> companies;

  Color _scoreColor(double v) {
    if (v >= 4) return const Color(0xFF4CAF50);
    if (v >= 3) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (int i = 0; i < companies.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: _card(context, scheme, i)),
            const SizedBox(width: 10),
            if (i + 1 < companies.length)
              Expanded(child: _card(context, scheme, i + 1))
            else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < companies.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  Widget _card(BuildContext context, ColorScheme scheme, int idx) {
    final c = companies[idx];
    final color = _kColors[idx % _kColors.length];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(c.industry,
                style: TextStyle(
                    color: scheme.onSurfaceVariant, fontSize: 11)),
            const SizedBox(height: 10),
            if (c.hasEnoughData && c.scores != null) ...[
              Text(
                c.averageScore.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor(c.averageScore),
                ),
              ),
              Text('${c.n} çalışan',
                  style: TextStyle(
                      color: scheme.onSurfaceVariant, fontSize: 11)),
            ] else
              Text('Yetersiz veri',
                  style: TextStyle(
                      color: scheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─── Company search sheet ─────────────────────────────────────────────────────

class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet({required this.alreadySelected});

  final List<CompanySummary> alreadySelected;

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(companySearchResultsProvider);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Şirket Ekle',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Şirket adını girin...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) {
                  ref
                      .read(companySearchQueryProvider.notifier)
                      .state = v;
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: resultsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Hata: $e')),
                data: (list) {
                  if (_ctrl.text.isEmpty) {
                    return const Center(
                        child:
                            Text('Aramaya başlamak için yazın.'));
                  }
                  if (list.isEmpty) {
                    return const Center(
                        child: Text('Şirket bulunamadı.'));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final c = list[i];
                      final isSelected = widget.alreadySelected
                          .any((x) => x.id == c.id);
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business_rounded),
                        ),
                        title: Text(c.name),
                        subtitle: Text(
                            '${c.industry} · ${c.n} çalışan'),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded,
                                color: scheme.primary)
                            : null,
                        onTap: isSelected
                            ? null
                            : () => Navigator.of(ctx).pop(c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          children: [
            const Text('📊', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Karşılaştırmak için
şirket ekleyin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'En fazla 6 şirketi aynı grafikte\nyan yana görebilirsiniz.',
              style: TextStyle(
                  color: scheme.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
