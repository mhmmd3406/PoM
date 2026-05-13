import 'package:flutter/material.dart';
import '../../lib/theme/app_theme.dart';

class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    this.sectorValue,
  });

  final String emoji;
  final String label;
  final double value;      // 1–5
  final double? sectorValue;

  @override
  Widget build(BuildContext context) {
    final pct = ((value - 1) / 4).clamp(0.0, 1.0);
    final color = AppColors.ratingColors[((value - 1).clamp(0, 4)).round()];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              value.toStringAsFixed(1),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Background track
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Sector benchmark line
            if (sectorValue != null)
              FractionallySizedBox(
                widthFactor: ((sectorValue! - 1) / 4).clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            // Bank value fill
            FractionallySizedBox(
              widthFactor: pct,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
