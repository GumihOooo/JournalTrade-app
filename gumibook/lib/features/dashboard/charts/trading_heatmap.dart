import 'package:flutter/material.dart';

import '../../../core/design/gumi.dart';
import '../analytics/analytics.dart';

/// Trading heatmap (P1-09.09, DESIGN.md §5.4): 7 rows (Mon..Sun) ×
/// 24 columns (close hour). Cell intensity = P/L sign + magnitude;
/// monochrome app — profit/loss semantic colors only (DESIGN.md §2.4).
/// Values not color-only: each cell tap speaks its weekday/hour/P-L
/// via Semantics (DESIGN.md §8); empty hours stay near-invisible.
class TradingHeatmap extends StatelessWidget {
  const TradingHeatmap({super.key, required this.cells});

  final List<HeatmapCell> cells;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final theme = Theme.of(context);
    final byCell = {
      for (final cell in cells) (cell.weekday, cell.hour): cell,
    };
    final maxAbs = cells
        .map((cell) => cell.totalProfitLoss.abs())
        .fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var wd = 1; wd <= 7; wd++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  // Scale-down instead of wrap: any locale/font keeps the
                  // weekday label single-line (test fonts render wider).
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _weekdays[wd - 1],
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: c.textMuted),
                    ),
                  ),
                ),
                for (var hour = 0; hour < 24; hour++)
                  _heatCell(context, byCell, wd, hour, maxAbs),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.schedule, size: 14, color: c.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Intensity = profit / loss by closing hour (local time).',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    theme.textTheme.labelSmall?.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heatCell(
    BuildContext context,
    Map<(int, int), HeatmapCell> byCell,
    int weekday,
    int hour,
    double maxAbs,
  ) {
    final c = context.gumiColors;
    final cell = byCell[(weekday, hour)];
    final empty = cell == null || cell.tradeCount == 0;
    final data = empty ? null : cell;

    final gain = (data?.totalProfitLoss ?? 0) >= 0;
    final magnitude = data == null
        ? 0.0
        : (data.totalProfitLoss.abs() / (maxAbs == 0 ? 1 : maxAbs))
            .clamp(0.15, 1.0);
    final color = data == null
        ? c.borderSubtle
        : (gain ? c.semanticProfit : c.semanticLoss)
            .withValues(alpha: 0.15 + 0.85 * magnitude);

    final label = data == null
        ? 'No trades'
        : '${data.tradeCount} trades, '
            '${data.totalProfitLoss >= 0 ? '+' : ''}'
            '${data.totalProfitLoss.toStringAsFixed(2)} '
            'closed ${_weekdays[weekday - 1]} $hour:00';

    return Semantics(
      label: label,
      button: false,
      child: Container(
        // Fixed 12px cell: 30px label + 24×12 ≈ 318px total — fits any
        // phone (DESIGN.md §9), no horizontal scroll; rows are 16px.
        width: 12,
        height: 12,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(2)),
        ),
      ),
    );
  }
}
