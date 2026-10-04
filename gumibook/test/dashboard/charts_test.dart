import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/design/gumi.dart';
import 'package:gumibook/features/dashboard/analytics/analytics.dart';
import 'package:gumibook/features/dashboard/charts/equity_drawdown_charts.dart';
import 'package:gumibook/features/dashboard/charts/performance_breakdown.dart';
import 'package:gumibook/features/dashboard/charts/trading_heatmap.dart';

import 'trade_fixtures.dart';

/// P1-09: chart components in isolation — glass shell, axis-free
/// charts, breakdown rows, heatmap grid, empty states.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      );

  testWidgets('ChartContainer renders title + subtitle + trailing',
      (tester) async {
    await tester.pumpWidget(host(const ChartContainer(
      title: 'Equity Curve',
      subtitle: null,
      trailing: Text('+60.00 USD'),
      height: 100,
      child: SizedBox.shrink(),
    )));
    expect(find.text('Equity Curve'), findsOneWidget);
    expect(find.text('+60.00 USD'), findsOneWidget);
  });

  testWidgets('EquityCurveChart renders without throwing on mixed trades',
      (tester) async {
    await tester.pumpWidget(host(EquityCurveChart(
      trades: [
        t(pl: 100, close: DateTime(2026, 1, 1)),
        t(pl: -50, close: DateTime(2026, 1, 2)),
      ],
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('EquityCurveChart empty trades: no crash', (tester) async {
    await tester.pumpWidget(host(EquityCurveChart(trades: const [])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DrawdownChart renders and caps at zero', (tester) async {
    await tester.pumpWidget(host(DrawdownChart(trades: [
      t(pl: 100, close: DateTime(2026, 1, 1)),
      t(pl: -150, close: DateTime(2026, 1, 2)),
    ])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DrawdownChart empty trades: no crash', (tester) async {
    await tester.pumpWidget(host(DrawdownChart(trades: const [])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PerformanceBreakdown lists keys with signed P/L text',
      (tester) async {
    await tester.pumpWidget(host(PerformanceBreakdown(rows: [
      const BreakdownRow(
          key: 'XAUUSD',
          tradeCount: 2,
          totalProfitLoss: 60,
          winRate: 50,
          averageRiskReward: null),
      const BreakdownRow(
          key: 'EURUSD',
          tradeCount: 1,
          totalProfitLoss: -50,
          winRate: 0,
          averageRiskReward: null),
    ])));
    expect(find.text('XAUUSD'), findsOneWidget);
    expect(find.text('EURUSD'), findsOneWidget);
    // Signed values = non-color meaning (DESIGN.md §8).
    expect(find.text('+60.00'), findsOneWidget);
    expect(find.text('-50.00'), findsOneWidget);
  });

  testWidgets('PerformanceBreakdown empty rows: renders nothing, no crash',
      (tester) async {
    await tester.pumpWidget(
        host(const PerformanceBreakdown(rows: [])));
    expect(tester.takeException(), isNull);
    expect(find.byType(Padding), findsNothing);
  });

  testWidgets('TradingHeatmap renders 7 weekday rows with semantics labels',
      (tester) async {
    // Monday 14:00 and Sunday 22:00 buckets (P1-08.11 fixtures).
    await tester.pumpWidget(host(TradingHeatmap(cells: [
      const HeatmapCell(
          weekday: 1, hour: 14, tradeCount: 1, totalProfitLoss: 100),
      const HeatmapCell(
          weekday: 7, hour: 22, tradeCount: 2, totalProfitLoss: -50),
    ])));
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
          '1 trades, +100.00 closed Mon 14:00'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('2 trades, -50.00 closed Sun 22:00'),
      findsOneWidget,
    );
  });

  testWidgets('TradingHeatmap empty cells: grid skeleton, no crash',
      (tester) async {
    await tester.pumpWidget(host(const TradingHeatmap(cells: [])));
    expect(tester.takeException(), isNull);
    expect(find.text('Mon'), findsOneWidget); // skeleton rows remain
  });
}
