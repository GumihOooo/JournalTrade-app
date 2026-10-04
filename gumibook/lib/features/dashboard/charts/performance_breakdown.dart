import 'package:flutter/material.dart';

import '../../../core/design/gumi.dart';
import '../analytics/analytics.dart';

/// Performance breakdown (P1-09.04..08): horizontal bars, one row per
/// key (instrument/strategy/session/emotion), P/L-colored bar length
/// relative to the largest absolute value. Profit/loss never color-only:
/// the signed amount prints beside every bar (DESIGN.md §8).
class PerformanceBreakdown extends StatelessWidget {
  const PerformanceBreakdown({super.key, required this.rows, this.maxRows = 6});

  final List<BreakdownRow> rows;

  /// Mobile height budget: top N by P/L (rows already sorted desc).
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final theme = Theme.of(context);
    final shown = rows.take(maxRows).toList();
    var maxAbs = shown
        .map((r) => r.totalProfitLoss.abs())
        .fold(0.0, (a, b) => a > b ? a : b);
    if (maxAbs == 0) maxAbs = 1; // zero-sum rows still render a hairline

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _BreakdownRowView(
              row: row,
              maxAbs: maxAbs,
              profitGradient: LinearGradient(
                colors: [c.gradientProfitStart, c.gradientProfitEnd],
              ),
              lossGradient: LinearGradient(
                colors: [c.gradientLossStart, c.gradientLossEnd],
              ),
              labelStyle: theme.textTheme.bodyMedium!,
              valueStyle: theme.textTheme.bodySmall!,
            ),
          ),
      ],
    );
  }
}

class _BreakdownRowView extends StatelessWidget {
  const _BreakdownRowView({
    required this.row,
    required this.maxAbs,
    required this.profitGradient,
    required this.lossGradient,
    required this.labelStyle,
    required this.valueStyle,
  });

  final BreakdownRow row;
  final double maxAbs;
  final Gradient profitGradient;
  final Gradient lossGradient;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final gain = row.totalProfitLoss >= 0;
    final gradient = gain ? profitGradient : lossGradient;
    final textColor = gain ? c.semanticProfit : c.semanticLoss;
    final fraction = (row.totalProfitLoss.abs() / maxAbs).clamp(0.02, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                row.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            // Signed text = non-color meaning carrier (a11y).
            Text(
              '${row.totalProfitLoss >= 0 ? '+' : ''}'
              '${row.totalProfitLoss.toStringAsFixed(2)}',
              style: valueStyle.copyWith(color: textColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 5),
        // Gradient bar with subtle glow
        LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 6,
            width: constraints.maxWidth * fraction,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
              boxShadow: [
                BoxShadow(
                  color: (gain ? c.cardGlowProfit : c.cardGlowLoss).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
