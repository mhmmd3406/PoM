import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../data/benchmarking_repository.dart';
import '../providers/benchmarking_provider.dart';
import '../../insights/presentation/radar_chart_widget.dart';

class BenchmarkingScreen extends ConsumerWidget {
  const BenchmarkingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyA = ref.watch(selectedCompanyAProvider);
    final companyB = ref.watch(selectedCompanyBProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Şirket Karşılaştırması'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Intro
            Text(
              'İki şirketi refah boyutlarında yan yana karşılaştırın.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),

            // Company selectors
            Row(
              children: [
                Expanded(
                  child: _CompanySelector(
                    selected: companyA,
                    badgeColor: const Color(AppConstants.colorPersonal),
                    label: 'Şirket A',
                    onSelect: (c) =>
                        ref.read(selectedCompanyAProvider.notifier).state = c,
                    onClear: () =>
                        ref.read(selectedCompanyAProvider.notifier).state = null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CompanySelector(
                    selected: companyB,
                    badgeColor: const Color(AppConstants.colorCompany),
                    label: 'Şirket B',
                    onSelect: (c) =>
                        ref.read(selectedCompanyBProvider.notifier).state = c,
                    onClear: () =>
                        ref.read(selectedCompanyBProvider.notifier).state = null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Comparison content
            if (companyA == null && companyB == null)
              const _EmptyState()
            else ...[
              // Radar comparison
              if (companyA != null && companyB != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Radar Karşılaştırması',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 20),
                        if (!companyA.hasEnoughData || !companyB.hasEnoughData)
                          _InsufficientDataBanner(
                            companyA: companyA,
                            companyB: companyB,
                          )
                        else
                          RadarChartWidget(
                            personalScores: companyA.scores != null
                                ? _toOrderedList(companyA.scores!)
                                : List.filled(5, 3.0),
                            companyScores: companyB.scores != null
                                ? _toOrderedList(companyB.scores!)
                                : null,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Side-by-side score cards
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (companyA != null)
                    Expanded(
                      child: _CompanyScoreCard(
                        company: companyA,
                        color: const Color(AppConstants.colorPersonal),
                      ),
                    ),
                  if (companyA != null && companyB != null)
                    const SizedBox(width: 12),
                  if (companyB != null)
                    Expanded(
                      child: _CompanyScoreCard(
                        company: companyB,
                        color: const Color(AppConstants.colorCompany),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Dimension breakdown table
              if (companyA != null &&
                  companyB != null &&
                  companyA.hasEnoughData &&
                  companyB.hasEnoughData) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Boyut Karşılaştırması',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        _DimensionTable(a: companyA, b: companyB),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static const _dimensionOrder = [
    'overallMood',
    'workStress',
    'teamHarmony',
    'personalGrowth',
    'workLifeBalance',
  ];

  List<double> _toOrderedList(Map<String, double> map) {
    return _dimensionOrder.map((k) => map[k] ?? 3.0).toList();
  }
}

// ─── Company Selector ─────────────────────────────────────────────────────────

class _CompanySelector extends ConsumerStatefulWidget {
  const _CompanySelector({
    required this.selected,
    required this.badgeColor,
    required this.label,
    required this.onSelect,
    required this.onClear,
  });

  final CompanySummary? selected;
  final Color badgeColor;
  final String label;
  final ValueChanged<CompanySummary> onSelect;
  final VoidCallback onClear;

  @override
  ConsumerState<_CompanySelector> createState() => _CompanySelectorState();
}

class _CompanySelectorState extends ConsumerState<_CompanySelector> {
  void _openSearchDialog() async {
    final result = await showModalBottomSheet<CompanySummary>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _CompanySearchSheet(),
    );
    if (result != null) widget.onSelect(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.selected == null ? _openSearchDialog : null,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.selected != null
              ? widget.badgeColor.withOpacity(0.1)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.selected != null
                ? widget.badgeColor
                : scheme.outlineVariant,
            width: widget.selected != null ? 2 : 1,
          ),
        ),
        child: widget.selected == null
            ? Column(
                children: [
                  Icon(Icons.add_business_rounded,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Seç',
                    style: TextStyle(
                      color: widget.badgeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.selected!.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onClear,
                        child: Icon(Icons.close_rounded,
                            size: 16, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.selected!.industry,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.selected!.hasEnoughData
                        ? '${widget.selected!.n} çalışan'
                        : 'Yetersiz veri',
                    style: TextStyle(
                      color: widget.selected!.hasEnoughData
                          ? widget.badgeColor
                          : scheme.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Company Search Sheet ─────────────────────────────────────────────────────

class _CompanySearchSheet extends ConsumerStatefulWidget {
  const _CompanySearchSheet();

  @override
  ConsumerState<_CompanySearchSheet> createState() =>
      _CompanySearchSheetState();
}

class _CompanySearchSheetState extends ConsumerState<_CompanySearchSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resultsAsync = ref.watch(companySearchResultsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Şirket Ara',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Şirket adını girin...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) {
                  ref.read(companySearchQueryProvider.notifier).state = v;
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: resultsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (companies) {
                  if (_controller.text.isEmpty) {
                    return const Center(
                      child: Text('Aramaya başlamak için yazın.'),
                    );
                  }
                  if (companies.isEmpty) {
                    return const Center(
                      child: Text('Şirket bulunamadı.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: companies.length,
                    itemBuilder: (ctx, i) {
                      final c = companies[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business_rounded),
                        ),
                        title: Text(c.name),
                        subtitle: Text(c.industry),
                        trailing: c.hasEnoughData
                            ? null
                            : const Text(
                                'Yetersiz veri',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange),
                              ),
                        onTap: () => Navigator.of(ctx).pop(c),
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

// ─── Company Score Card ───────────────────────────────────────────────────────

class _CompanyScoreCard extends StatelessWidget {
  const _CompanyScoreCard({
    required this.company,
    required this.color,
  });

  final CompanySummary company;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            Text(
              company.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              company.industry,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (company.hasEnoughData && company.scores != null)
              Text(
                company.averageScore.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor(company.averageScore),
                ),
              )
            else
              Text(
                'Yetersiz veri',
                style: TextStyle(
                    color: scheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            if (company.hasEnoughData)
              Text(
                '${company.n} çalışan',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 4) return const Color(0xFF4CAF50);
    if (score >= 3) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }
}

// ─── Dimension Table ──────────────────────────────────────────────────────────

class _DimensionTable extends StatelessWidget {
  const _DimensionTable({required this.a, required this.b});

  final CompanySummary a;
  final CompanySummary b;

  static const _dimensionOrder = [
    'overallMood',
    'workStress',
    'teamHarmony',
    'personalGrowth',
    'workLifeBalance',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const colorA = Color(AppConstants.colorPersonal);
    const colorB = Color(AppConstants.colorCompany);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
      },
      children: [
        // Header
        TableRow(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text('Boyut',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                a.name.length > 10 ? '${a.name.substring(0, 10)}...' : a.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: colorA),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                b.name.length > 10 ? '${b.name.substring(0, 10)}...' : b.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: colorB),
              ),
            ),
          ],
        ),
        // Dimension rows
        ...List.generate(_dimensionOrder.length, (i) {
          final key = _dimensionOrder[i];
          final scoreA = a.scores?[key] ?? 0;
          final scoreB = b.scores?[key] ?? 0;
          final diff = scoreA - scoreB;

          return TableRow(
            decoration: i.isEven
                ? BoxDecoration(
                    color: scheme.surface,
                    border: Border(
                      bottom: BorderSide(
                          color: scheme.outlineVariant.withOpacity(0.5)),
                    ),
                  )
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                          color: scheme.outlineVariant.withOpacity(0.5)),
                    ),
                  ),
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  AppConstants.checkinDimensions[i],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  scoreA.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: diff > 0
                        ? const Color(0xFF4CAF50)
                        : diff < 0
                            ? const Color(0xFFF44336)
                            : scheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  scoreB.toStringAsFixed(1),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: diff < 0
                        ? const Color(0xFF4CAF50)
                        : diff > 0
                            ? const Color(0xFFF44336)
                            : scheme.onSurface,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

// ─── Insufficient data banner ─────────────────────────────────────────────────

class _InsufficientDataBanner extends StatelessWidget {
  const _InsufficientDataBanner({
    required this.companyA,
    required this.companyB,
  });

  final CompanySummary companyA;
  final CompanySummary companyB;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missing = [
      if (!companyA.hasEnoughData) companyA.name,
      if (!companyB.hasEnoughData) companyB.name,
    ].join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$missing için yeterli veri yok '
              '(minimum ${AppConstants.defaultCompanyMinN} çalışan gerekli). '
              'Radar grafiği gösterilemiyor.',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Text('🏢', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'Karşılaştırmak için\nikişirket seçin',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Seçilen şirketlerin refah skorlarını\nyan yana görüntüleyin.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
