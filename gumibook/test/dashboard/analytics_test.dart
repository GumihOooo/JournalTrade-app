import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/dashboard/analytics/analytics.dart';

import 'trade_fixtures.dart';

/// P1-08: analytics engine — pure functions, TDD. No widgets, no
/// network, no providers. IMPLEMENTATION.md §19 + PRD §8 rules:
///
/// - Win Rate = wins / total × 100
/// - Average RR = mean over trades that carry RR only
/// - Equity = starting balance (nullable, else 0) + cumulative P/L
///   ordered by close time ascending
/// - Drawdown = decline from previous equity peak (money + %)
/// - Breakdowns = per-key totals with P/L, win rate, count
/// - Heatmap = trades bucketed by weekday × hour of close time
/// - zero trades → empty aggregates, never NaN, never throws
void main() {
  group('summary metrics (P1-08.01..04, .12, .13, .14)', () {
    test('zero trades: zeros and nulls, no NaN', () {
      final s = summarizeTrades(const []);
      expect(s.totalTrades, 0);
      expect(s.totalProfitLoss, 0);
      expect(s.winRate, 0);
      expect(s.averageRiskReward, isNull);
      expect(s.wins, 0);
      expect(s.losses, 0);
      expect(s.breakevens, 0);
    });

    test('totals, win rate, win/loss/breakeven counts', () {
      final s = summarizeTrades([
        t(pl: 100, rr: 2),
        t(pl: -40, rr: 0.5),
        t(pl: 100, rr: null), // breakeven-in-RR set? no: win, but RR null
        t(pl: 0), // breakeven
        t(pl: -10),
      ]);
      expect(s.totalTrades, 5);
      expect(s.totalProfitLoss, moreOrLessEquals(150));
      expect(s.wins, 2);
      expect(s.losses, 2);
      expect(s.breakevens, 1);
      expect(s.winRate, moreOrLessEquals(40.0));
    });

    test('average RR skips null RR trades (P1-08.14)', () {
      final s = summarizeTrades([
        t(pl: 50, rr: 2),
        t(pl: 50, rr: null),
        t(pl: 50, rr: 4),
      ]);
      expect(s.averageRiskReward, moreOrLessEquals(3));
    });

    test('average RR null when no trade has RR', () {
      expect(summarizeTrades([t(pl: 10)]).averageRiskReward, isNull);
    });
  });

  group('equity curve (P1-08.05, .05a)', () {
    test('orders by close time ascending regardless of input order', () {
      final curve = equityCurve([
        t(pl: 30, close: DateTime(2026, 1, 3)),
        t(pl: 10, close: DateTime(2026, 1, 1)),
        t(pl: -5, close: DateTime(2026, 1, 2)),
      ]);
      expect(curve.orderedTrades.map((x) => x.profitLoss), [10, -5, 30]);
      expect(curve.equity, [
        moreOrLessEquals(10),
        moreOrLessEquals(5),
        moreOrLessEquals(35),
      ]);
    });

    test('nullable starting balance: 0 origin when null (P1-08.05a)', () {
      final curve = equityCurve([t(pl: 25), t(pl: -5)]);
      expect(curve.equity.first, moreOrLessEquals(25));
    });

    test('starting balance used as origin when set', () {
      final curve = equityCurve([t(pl: 25), t(pl: -5)], startingBalance: 1000);
      expect(curve.equity, [
        moreOrLessEquals(1025),
        moreOrLessEquals(1020),
      ]);
    });

    test('zero trades: empty curve, no NaN', () {
      final curve = equityCurve(const []);
      expect(curve.orderedTrades, isEmpty);
      expect(curve.equity, isEmpty);
    });

    test('same close time: stable input order kept', () {
      final same = DateTime(2026, 1, 1);
      final curve = equityCurve([
        t(pl: 1, close: same),
        t(pl: 2, close: same),
      ]);
      expect(curve.equity, [moreOrLessEquals(1), moreOrLessEquals(3)]);
    });
  });

  group('drawdown (P1-08.06)', () {
    test('new peak resets drawdown', () {
      // equity: 100, 90, 120 → dd only from 100→90
      final d = drawdown(equityCurve([
        t(pl: 100),
        t(pl: -10),
        t(pl: 30),
      ]));
      expect(d.maxDrawdownMoney, moreOrLessEquals(-10));
      expect(d.maxDrawdownPercent, moreOrLessEquals(10.0));
    });

    test('deepest decline wins, not the latest', () {
      // equity: 50, 10, 15, 200 → deepest is 50→10 (40), not 15 dip
      final d = drawdown(equityCurve([
        t(pl: 50),
        t(pl: -40),
        t(pl: 5),
        t(pl: 185),
      ]));
      expect(d.maxDrawdownMoney, moreOrLessEquals(-40));
      expect(d.maxDrawdownPercent, moreOrLessEquals(80.0));
    });

    test('starting balance anchors peak (decline below origin counts)', () {
      // equity: 1000, 990 → 1% dd below the starting balance itself
      final d = drawdown(
        equityCurve([t(pl: -10)], startingBalance: 1000),
        startingBalance: 1000,
      );
      expect(d.maxDrawdownMoney, moreOrLessEquals(-10));
      expect(d.maxDrawdownPercent, moreOrLessEquals(1.0));
    });

    test('monotonic rise: zero drawdown', () {
      final d = drawdown(equityCurve([t(pl: 10), t(pl: 10)]));
      expect(d.maxDrawdownMoney, 0);
      expect(d.maxDrawdownPercent, 0);
    });

    test('zero trades: zero drawdown, no NaN', () {
      final d = drawdown(equityCurve(const []));
      expect(d.maxDrawdownMoney, 0);
      expect(d.maxDrawdownPercent, 0);
    });
  });

  group('breakdowns (P1-08.07..10)', () {
    test('instrument breakdown aggregates per instrument', () {
      final rows = breakdownByInstrument([
        t(instr: 'XAUUSD', pl: 100),
        t(instr: 'XAUUSD', pl: -40),
        t(instr: 'EURUSD', pl: 30),
      ]);
      expect(rows.length, 2);
      final gold = rows.firstWhere((r) => r.key == 'XAUUSD');
      expect(gold.tradeCount, 2);
      expect(gold.totalProfitLoss, moreOrLessEquals(60));
      expect(gold.winRate, moreOrLessEquals(50.0));
      final euro = rows.firstWhere((r) => r.key == 'EURUSD');
      expect(euro.totalProfitLoss, moreOrLessEquals(30));
      expect(euro.winRate, moreOrLessEquals(100.0));
    });

    test('strategy breakdown: null strategy excluded, sorted by P/L desc', () {
      final rows = breakdownByStrategy([
        t(strategy: 'sniper', pl: 10),
        t(strategy: null, pl: 999), // unclassified — never a fake bucket
        t(strategy: 'scalp', pl: 50),
      ]);
      expect(rows.map((r) => r.key), ['scalp', 'sniper']);
      expect(rows.first.totalProfitLoss, moreOrLessEquals(50));
    });

    test('session breakdown groups by session string', () {
      final rows = breakdownBySession([
        t(session: 'london', pl: 10),
        t(session: 'london', pl: 20),
        t(session: 'tokyo', pl: -5),
      ]);
      expect(rows.length, 2);
      expect(rows.first.key, 'london'); // P/L sort: 30 > -5
      expect(rows.first.tradeCount, 2);
    });

    test('emotion breakdown groups by emotion', () {
      final rows = breakdownByEmotion([
        t(emotion: 'calm', pl: 100),
        t(emotion: 'fomo', pl: -80),
        t(emotion: 'fomo', pl: 20),
      ]);
      expect(rows.length, 2);
      final fomo = rows.firstWhere((r) => r.key == 'fomo');
      expect(fomo.totalProfitLoss, moreOrLessEquals(-60));
      expect(fomo.winRate, moreOrLessEquals(50.0));
    });

    test('empty trades: empty breakdown, no NaN', () {
      expect(breakdownByInstrument(const []), isEmpty);
      expect(breakdownByStrategy(const []), isEmpty);
      expect(breakdownBySession(const []), isEmpty);
      expect(breakdownByEmotion(const []), isEmpty);
    });

    test('average RR rides along per row (P1-08.14 at row level)', () {
      final rows = breakdownByInstrument([
        t(instr: 'XAUUSD', pl: 10, rr: 1),
        t(instr: 'XAUUSD', pl: 10, rr: 3),
      ]);
      expect(rows.single.averageRiskReward, moreOrLessEquals(2));
    });
  });

  group('heatmap (P1-08.11)', () {
    test('buckets by weekday and close hour', () {
      // 2026-01-05 is a Monday, 14:30 close → weekday 1, hour 14.
      // 2026-01-04 is a Sunday, 22:00 close → weekday 7, hour 22.
      final cells = tradingHeatmap([
        t(pl: 100, close: DateTime(2026, 1, 5, 14, 30)),
        t(pl: -50, close: DateTime(2026, 1, 4, 22)),
      ]);
      expect(cells.length, 2);
      final mon = cells.singleWhere((cell) => cell.weekday == 1 && cell.hour == 14);
      expect(mon.tradeCount, 1);
      expect(mon.totalProfitLoss, moreOrLessEquals(100));
      final sun = cells.singleWhere((cell) => cell.weekday == 7 && cell.hour == 22);
      expect(sun.totalProfitLoss, moreOrLessEquals(-50));
    });

    test('multiple trades in the same bucket merge', () {
      final cells = tradingHeatmap([
        t(pl: 10, close: DateTime(2026, 1, 5, 14)),
        t(pl: 20, close: DateTime(2026, 1, 5, 14, 59)),
        t(pl: -5, close: DateTime(2026, 1, 5, 15)),
      ]);
      expect(cells.length, 2);
      final bucket = cells.singleWhere((cell) => cell.hour == 14);
      expect(bucket.tradeCount, 2);
      expect(bucket.totalProfitLoss, moreOrLessEquals(30));
    });

    test('empty trades: no cells, no NaN', () {
      expect(tradingHeatmap(const []), isEmpty);
    });

    test('weekday mapping: ISO weekday 1..7 (Mon..Sun)', () {
      final cells = tradingHeatmap([
        t(pl: 1, close: DateTime(2026, 1, 5)), // Monday
        t(pl: 1, close: DateTime(2026, 1, 6)), // Tuesday
        t(pl: 1, close: DateTime(2026, 1, 11)), // Sunday
      ]);
      expect(cells.map((c) => c.weekday), everyElement(greaterThan(0)));
      expect(cells.map((c) => c.weekday), everyElement(lessThan(8)));
      expect(cells.map((c) => c.weekday), containsAll([1, 2, 7]));
    });
  });
}
