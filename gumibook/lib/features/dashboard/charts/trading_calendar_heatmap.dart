import 'package:flutter/material.dart';

import '../../../core/design/gumi.dart';
import '../../trades/domain/trade.dart';
import '../analytics/analytics.dart';

/// Monthly trading calendar heatmap with daily net P/L intensity & trade summary dialog.
class TradingCalendarHeatmap extends StatefulWidget {
  const TradingCalendarHeatmap({
    super.key,
    required this.trades,
    this.currency = 'USD',
  });

  final List<Trade> trades;
  final String currency;

  @override
  State<TradingCalendarHeatmap> createState() => _TradingCalendarHeatmapState();
}

class _TradingCalendarHeatmapState extends State<TradingCalendarHeatmap> {
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _showDayDetails(BuildContext context, DaySummary summary) {
    final c = context.gumiColors;
    final theme = Theme.of(context);
    final dateStr =
        '${summary.date.year}-${summary.date.month.toString().padLeft(2, '0')}-${summary.date.day.toString().padLeft(2, '0')}';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      dateStr,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    ProfitLossText(
                      amount: summary.totalProfitLoss,
                      currency: widget.currency,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.trades.length} trade(s) • Win Rate ${summary.winRate.toStringAsFixed(1)}%',
                  style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: summary.trades.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = summary.trades[i];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (t.direction == TradeDirection.buy
                                      ? c.semanticProfit
                                      : c.semanticLoss)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.direction.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: t.direction == TradeDirection.buy
                                    ? c.semanticProfit
                                    : c.semanticLoss,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.instrument.toUpperCase(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ProfitLossText(
                            amount: t.profitLoss,
                            currency: widget.currency,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final theme = Theme.of(context);
    final daysMap = groupByDate(widget.trades);

    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // Weekday: Mon=1, Sun=7
    final firstWeekday = firstDayOfMonth.weekday;
    final leadingEmpty = firstWeekday - 1;

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthTitle = '${monthNames[month - 1]} $year';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              monthTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _prevMonth,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _nextMonth,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Weekday header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7078),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: leadingEmpty + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leadingEmpty) {
              return const SizedBox.shrink();
            }
            final day = index - leadingEmpty + 1;
            final date = DateTime(year, month, day);
            final summary = daysMap[date];

            BoxDecoration decoration;
            Widget? inner;

            if (summary != null) {
              final isProfit = summary.totalProfitLoss >= 0;
              final isZero = summary.totalProfitLoss == 0;

              if (isZero) {
                decoration = BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.borderSubtle),
                );
              } else if (isProfit) {
                decoration = BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.gradientProfitStart, c.gradientProfitEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: c.cardGlowProfit,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                );
              } else {
                decoration = BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c.gradientLossStart, c.gradientLossEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: c.cardGlowLoss,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                );
              }
              inner = Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isProfit ? Colors.black : Colors.white,
                  ),
                ),
              );
            } else {
              decoration = BoxDecoration(
                color: c.surfaceBase.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c.borderSubtle.withValues(alpha: 0.5)),
              );
              inner = Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 11,
                    color: c.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              );
            }

            return GestureDetector(
              onTap: summary != null ? () => _showDayDetails(context, summary) : null,
              child: Container(
                decoration: decoration,
                child: inner,
              ),
            );
          },
        ),
      ],
    );
  }
}
