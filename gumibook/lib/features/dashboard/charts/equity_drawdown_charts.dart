import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/design/gumi.dart';
import '../../trades/domain/trade.dart';
import '../analytics/analytics.dart';

/// Equity Curve chart: smooth curve with teal/cyan gradient fill and tap tooltip.
class EquityCurveChart extends StatelessWidget {
  const EquityCurveChart({super.key, required this.trades, this.startingBalance});

  final List<Trade> trades;
  final double? startingBalance;

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final curve = equityCurve(trades, startingBalance: startingBalance);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (curve.equity.length - 1).toDouble().clamp(1, double.infinity),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => c.surfaceElevated.withValues(alpha: 0.92),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                String dateStr = '';
                if (index >= 0 && index < trades.length) {
                  final d = trades[index].closeTime.toLocal();
                  dateStr = '${d.day}/${d.month} ';
                }
                return LineTooltipItem(
                  '$dateStr${spot.y >= 0 ? '+' : ''}${spot.y.toStringAsFixed(2)}',
                  TextStyle(
                    color: spot.y >= 0 ? c.semanticProfit : c.semanticLoss,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < curve.equity.length; i++)
                FlSpot(i.toDouble(), curve.equity[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 2.5,
            color: c.semanticProfit,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.gradientProfitStart.withValues(alpha: 0.28),
                  c.gradientProfitEnd.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}

/// Drawdown chart: smooth curve with coral red gradient fill and tap tooltip.
class DrawdownChart extends StatelessWidget {
  const DrawdownChart({super.key, required this.trades, this.startingBalance});

  final List<Trade> trades;
  final double? startingBalance;

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final curve = equityCurve(trades, startingBalance: startingBalance);

    var peak = startingBalance ?? 0.0;
    final declines = <double>[];
    for (final e in curve.equity) {
      if (e > peak) peak = e;
      declines.add(e - peak);
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (declines.length - 1).toDouble().clamp(1, double.infinity),
        maxY: 0,
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => c.surfaceElevated.withValues(alpha: 0.92),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                String dateStr = '';
                if (index >= 0 && index < trades.length) {
                  final d = trades[index].closeTime.toLocal();
                  dateStr = '${d.day}/${d.month} ';
                }
                return LineTooltipItem(
                  '$dateStr${spot.y.toStringAsFixed(2)}',
                  TextStyle(
                    color: c.semanticLoss,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < declines.length; i++)
                FlSpot(i.toDouble(), declines[i]),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            barWidth: 2.5,
            color: c.semanticLoss,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  c.gradientLossEnd.withValues(alpha: 0.25),
                  c.gradientLossStart.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}
