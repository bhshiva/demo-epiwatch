import 'package:flutter/material.dart';

/// Renders 7-day and 30-day surveillance trend indicators
/// Matches format: ↗ 4.2% 7d  |  ↘ 1.5% 30d
class TrendDeltaBadge extends StatelessWidget {
  final double deltaPercent;
  final String period; // e.g. '7d' or '30d'
  final bool higherIsWorse; // if true, positive delta is shown in red/amber; if false, in teal/green

  const TrendDeltaBadge({
    super.key,
    required this.deltaPercent,
    this.period = '7d',
    this.higherIsWorse = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = deltaPercent > 0;
    final isZero = deltaPercent == 0.0;
    final isNegative = deltaPercent < 0;

    final Color badgeColor;
    if (isZero) {
      badgeColor = const Color(0xFF0D9488); // neutral teal
    } else if (higherIsWorse) {
      if (isPositive) {
        badgeColor = deltaPercent >= 10.0
            ? const Color(0xFFDC2626) // critical red
            : const Color(0xFFEA580C); // warning amber/orange
      } else {
        badgeColor = const Color(0xFF0D9488); // improving teal
      }
    } else {
      if (isPositive) {
        badgeColor = const Color(0xFF0D9488); // positive good
      } else {
        badgeColor = const Color(0xFFEA580C); // negative decline
      }
    }

    final arrow = isPositive ? '↗' : (isNegative ? '↘' : '↘');
    final formattedValue = '${deltaPercent.abs().toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            arrow,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            formattedValue,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: badgeColor,
              height: 1.1,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            period,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper to render both 7-day and 30-day trend pair
class DualTrendRow extends StatelessWidget {
  final double delta7d;
  final double delta30d;
  final bool higherIsWorse;

  const DualTrendRow({
    super.key,
    required this.delta7d,
    required this.delta30d,
    this.higherIsWorse = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TrendDeltaBadge(deltaPercent: delta7d, period: '7d', higherIsWorse: higherIsWorse),
        TrendDeltaBadge(deltaPercent: delta30d, period: '30d', higherIsWorse: higherIsWorse),
      ],
    );
  }
}
