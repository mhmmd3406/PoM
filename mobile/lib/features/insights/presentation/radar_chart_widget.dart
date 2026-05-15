import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

class RadarChartWidget extends StatefulWidget {
  const RadarChartWidget({
    super.key,
    required this.personalScores,
    this.companyScores,
    this.benchmarkScores,
    this.dimensions,
  });

  /// 5 scores in order: overallMood, workStress, teamHarmony, personalGrowth,
  /// workLifeBalance — each 1.0–5.0.
  final List<double> personalScores;
  final List<double>? companyScores;
  final List<double>? benchmarkScores;
  final List<String>? dimensions;

  @override
  State<RadarChartWidget> createState() => _RadarChartWidgetState();
}

class _RadarChartWidgetState extends State<RadarChartWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  static const _personalColor = Color(AppConstants.colorPersonal);
  static const _companyColor = Color(AppConstants.colorCompany);
  static const _benchmarkColor = Color(AppConstants.colorBenchmark);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<RadarDataSet> _buildDataSets(double animValue) {
    final sets = <RadarDataSet>[];

    // Benchmark (bottom layer)
    if (widget.benchmarkScores != null &&
        widget.benchmarkScores!.length == 5) {
      sets.add(RadarDataSet(
        dataEntries: widget.benchmarkScores!
            .map((v) => RadarEntry(value: v * animValue))
            .toList(),
        fillColor: _benchmarkColor.withOpacity(0.08),
        borderColor: _benchmarkColor.withOpacity(0.6),
        borderWidth: 1.5,
      ));
    }

    // Company average
    if (widget.companyScores != null && widget.companyScores!.length == 5) {
      sets.add(RadarDataSet(
        dataEntries: widget.companyScores!
            .map((v) => RadarEntry(value: v * animValue))
            .toList(),
        fillColor: _companyColor.withOpacity(0.12),
        borderColor: _companyColor.withOpacity(0.8),
        borderWidth: 2,
      ));
    }

    // Personal (top layer)
    if (widget.personalScores.length == 5) {
      sets.add(RadarDataSet(
        dataEntries: widget.personalScores
            .map((v) => RadarEntry(value: v * animValue))
            .toList(),
        fillColor: _personalColor.withOpacity(0.18),
        borderColor: _personalColor,
        borderWidth: 2.5,
      ));
    }

    return sets;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dims = widget.dimensions ?? AppConstants.checkinDimensions;

    return Column(
      children: [
        // Chart
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return SizedBox(
              height: 280,
              child: RadarChart(
                RadarChartData(
                  dataSets: _buildDataSets(_animation.value),
                  radarShape: RadarShape.polygon,
                  tickCount: 4,
                  ticksTextStyle: TextStyle(
                    fontSize: 9,
                    color: scheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  tickBorderData: BorderSide(
                    color: scheme.outlineVariant.withOpacity(0.4),
                    width: 1,
                  ),
                  gridBorderData: BorderSide(
                    color: scheme.outlineVariant.withOpacity(0.3),
                    width: 1,
                  ),
                  radarBorderData: BorderSide(
                    color: scheme.outlineVariant,
                    width: 1,
                  ),
                  getTitle: (index, angle) {
                    if (index >= dims.length) return RadarChartTitle(text: '');
                    final parts = dims[index].split(' ');
                    // Wrap long labels
                    final label = parts.length > 2
                        ? '${parts[0]}\n${parts.sublist(1).join(' ')}'
                        : dims[index];
                    return RadarChartTitle(
                      text: label,
                      angle: angle,
                    );
                  },
                  titleTextStyle: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  titlePadding: 18,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Legend
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            _LegendItem(color: _personalColor, label: 'Siz'),
            if (widget.companyScores != null)
              _LegendItem(color: _companyColor, label: 'Şirket Ort.'),
            if (widget.benchmarkScores != null)
              _LegendItem(color: _benchmarkColor, label: 'Sektör Ort.'),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
