import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

const _metricKeys = ['salary', 'benefits', 'work_model', 'culture', 'wlb'];
const _metricIcons = ['💰', '🎁', '🏠', '🤝', '⚖️'];
const _metricLabels = ['Salary', 'Benefits', 'Work Model', 'Culture', 'WLB'];

/// Spider/radar chart for 5 PoM metrics.
/// [bankValues] and [sectorValues] map metric keys → scores (0.0–5.0).
class RadarChart extends StatelessWidget {
  const RadarChart({
    super.key,
    required this.bankValues,
    this.sectorValues,
    this.size = 260.0,
  });

  final Map<String, double> bankValues;
  final Map<String, double>? sectorValues;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bank = _metricKeys.map((k) => (bankValues[k] ?? 0.0) / 5.0).toList();
    final sector = sectorValues != null
        ? _metricKeys.map((k) => (sectorValues![k] ?? 0.0) / 5.0).toList()
        : null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RadarPainter(bank: bank, sector: sector),
          ),
          ..._buildLabels(size),
        ],
      ),
    );
  }

  List<Widget> _buildLabels(double size) {
    final cx = size / 2;
    final cy = size / 2;
    final r = size / 2 - 20;
    return List.generate(5, (i) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 5;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      return Positioned(
        left: x - 18,
        top: y - 18,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_metricIcons[i], style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({required this.bank, this.sector});
  final List<double> bank;   // normalized 0.0–1.0 per metric
  final List<double>? sector;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = size.width / 2 - 32;

    _drawGrid(canvas, cx, cy, maxR);
    if (sector != null) _drawPolygon(canvas, cx, cy, maxR, sector!, isSector: true);
    _drawPolygon(canvas, cx, cy, maxR, bank, isSector: false);
  }

  void _drawGrid(Canvas canvas, double cx, double cy, double maxR) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;

    for (int level = 1; level <= 5; level++) {
      final r = maxR * level / 5;
      canvas.drawPath(_pentagon(cx, cy, r), gridPaint);
    }
    for (int i = 0; i < 5; i++) {
      final a = _angle(i);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + maxR * math.cos(a), cy + maxR * math.sin(a)),
        axisPaint,
      );
    }
  }

  void _drawPolygon(Canvas canvas, double cx, double cy, double maxR,
      List<double> values, {required bool isSector}) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a = _angle(i);
      final r = maxR * values[i];
      final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    if (isSector) {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.warning.withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accent.withOpacity(0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.accent.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
      // Vertex dots
      for (int i = 0; i < 5; i++) {
        final a = _angle(i);
        final r = maxR * values[i];
        canvas.drawCircle(
          Offset(cx + r * math.cos(a), cy + r * math.sin(a)),
          4,
          Paint()..color = AppColors.accent,
        );
      }
    }
  }

  Path _pentagon(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final a = _angle(i);
      final p = Offset(cx + r * math.cos(a), cy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  double _angle(int i) => -math.pi / 2 + i * 2 * math.pi / 5;

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.bank != bank || old.sector != sector;
}
