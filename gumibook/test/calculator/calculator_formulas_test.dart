import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/calculator/calculator_formulas.dart';

/// P2-01.13: pure calculator formulas, TDD (IMPLEMENTATION.md §21:
/// formulas live apart from widgets, unit-tested). Every function
/// returns null on missing/invalid input — never throws, never NaN.
void main() {
  group('lot size (P2-01.02)', () {
    test('risk amount / stop distance in price', () {
      // $10 risk / $0.01-per-lot stop distance.
      expect(
        lotSize(balance: 1000, riskPercent: 1, stopDistance: 0.01,
            pipValuePerLot: null),
        moreOrLessEquals(1000.0),
      );
    });
    test('risk amount / (stop pips × pip value per lot)', () {
      // $20 risk / ($50 stop × $10 pip value) = 0.04 lots.
      expect(
        lotSize(balance: 1000, riskPercent: 2, stopDistance: 50,
            pipValuePerLot: 10),
        moreOrLessEquals(0.04),
      );
    });
    test('zero stop distance or pip value → null (no divide-by-zero)', () {
      expect(lotSize(balance: 1000, riskPercent: 1, stopDistance: 0), isNull);
      expect(
          lotSize(balance: 1000, riskPercent: 1, stopDistance: 50,
              pipValuePerLot: 0),
          isNull);
    });
    test('missing input → null', () {
      expect(
          lotSize(balance: null, riskPercent: 1, stopDistance: 0.01), isNull);
      expect(lotSize(balance: 1000, riskPercent: null, stopDistance: 0.01),
          isNull);
      expect(
          lotSize(balance: 1000, riskPercent: 1, stopDistance: null), isNull);
    });
    test('negative balance or stop → null', () {
      expect(
          lotSize(balance: -100, riskPercent: 1, stopDistance: 0.01), isNull);
      expect(
          lotSize(balance: 1000, riskPercent: 1, stopDistance: -0.01), isNull);
    });
  });

  group('position size (P2-01.03)', () {
    test('lots × contract size', () {
      expect(positionSize(lots: 0.5, contractSize: 100000), 50000);
      expect(positionSize(lots: 2, contractSize: 100), 200);
    });
    test('missing/invalid → null', () {
      expect(positionSize(lots: null, contractSize: 100), isNull);
      expect(positionSize(lots: 0, contractSize: 100), isNull);
      expect(positionSize(lots: 1, contractSize: null), isNull);
      expect(positionSize(lots: 1, contractSize: 0), isNull);
    });
  });

  group('risk money (P2-01.04)', () {
    test('stop distance × lots × pip value per lot', () {
      expect(riskMoney(stopDistance: 50, lots: 0.5, pipValuePerLot: 10),
          moreOrLessEquals(250));
    });
    test('zero/missing inputs → null', () {
      expect(riskMoney(stopDistance: 0, lots: 1, pipValuePerLot: 10), isNull);
      expect(riskMoney(stopDistance: 50, lots: null, pipValuePerLot: 10),
          isNull);
      expect(riskMoney(stopDistance: 50, lots: 1, pipValuePerLot: null),
          isNull);
      expect(riskMoney(stopDistance: 50, lots: 1, pipValuePerLot: 0), isNull);
    });
  });

  group('risk percent (P2-01.05)', () {
    test('risk money / balance × 100', () {
      expect(riskPercent(riskMoney: 25, balance: 1000), moreOrLessEquals(2.5));
    });
    test('zero balance → null', () {
      expect(riskPercent(riskMoney: 25, balance: 0), isNull);
      expect(riskPercent(riskMoney: 25, balance: null), isNull);
    });
  });

  group('pip value (P2-01.06)', () {
    test('pip distance × contract size × lots', () {
      expect(pipValue(pipDistance: 0.0001, contractSize: 100000, lots: 1),
          moreOrLessEquals(10));
      expect(pipValue(pipDistance: 0.0001, contractSize: 100000, lots: 0.1),
          moreOrLessEquals(1));
    });
    test('missing/zero → null', () {
      expect(pipValue(pipDistance: null, contractSize: 100000, lots: 1),
          isNull);
      expect(pipValue(pipDistance: 0.0001, contractSize: null, lots: 1),
          isNull);
      expect(pipValue(pipDistance: 0.0001, contractSize: 100000, lots: 0),
          isNull);
    });
  });

  group('margin (P2-01.07)', () {
    test('price × lots × contract size / leverage', () {
      expect(
          margin(price: 2000, lots: 1, contractSize: 100, leverage: 100),
          moreOrLessEquals(2000));
      expect(
          margin(price: 1.1, lots: 1, contractSize: 100000, leverage: 500),
          moreOrLessEquals(220));
    });
    test('zero leverage → null', () {
      expect(margin(price: 2000, lots: 1, contractSize: 100, leverage: 0),
          isNull);
      expect(margin(price: 2000, lots: 1, contractSize: 100, leverage: null),
          isNull);
    });
  });

  group('profit (P2-01.08)', () {
    test('price distance × contract size × lots, direction-aware', () {
      expect(
          profit(entry: 1.1, exit: 1.105, contractSize: 100000, lots: 1,
              isBuy: true),
          moreOrLessEquals(500));
      expect(
          profit(entry: 1.1, exit: 1.105, contractSize: 100000, lots: 1,
              isBuy: false),
          moreOrLessEquals(-500));
      expect(
          profit(entry: 2000, exit: 1990, contractSize: 100, lots: 1,
              isBuy: true),
          moreOrLessEquals(-1000));
    });
    test('missing → null', () {
      expect(
          profit(entry: null, exit: 1.1, contractSize: 1, lots: 1, isBuy: true),
          isNull);
    });
    test('entry == exit → 0', () {
      expect(
          profit(entry: 1, exit: 1, contractSize: 1, lots: 1, isBuy: true),
          moreOrLessEquals(0));
    });
  });

  group('drawdown (P2-01.09)', () {
    test('decline from peak balance', () {
      expect(drawdown(peak: 1000, current: 800), moreOrLessEquals(200));
    });
    test('drawdown percent', () {
      expect(drawdownPercent(peak: 1000, current: 800),
          moreOrLessEquals(20.0));
    });
    test('new peak → zero, not negative', () {
      expect(drawdown(peak: 1000, current: 1200), 0);
      expect(drawdownPercent(peak: 1000, current: 1200), 0);
    });
    test('zero/missing peak → null', () {
      expect(drawdown(peak: 0, current: 100), isNull);
      expect(drawdown(peak: null, current: 100), isNull);
      expect(drawdownPercent(peak: 1000, current: null), isNull);
    });
  });

  group('compound (P2-01.10)', () {
    test('balance × (1 + r)^n', () {
      expect(compound(balance: 1000, gainPercent: 10, periods: 3),
          moreOrLessEquals(1331.0, epsilon: 0.0001));
      expect(compound(balance: 1000, gainPercent: -10, periods: 2),
          moreOrLessEquals(810.0, epsilon: 0.0001));
    });
    test('zero balance or periods → null', () {
      expect(compound(balance: 0, gainPercent: 10, periods: 3), isNull);
      expect(compound(balance: 1000, gainPercent: 10, periods: 0), isNull);
      expect(compound(balance: null, gainPercent: 10, periods: 3), isNull);
    });
  });

  group('risk/reward (P2-01.11)', () {
    test('reward distance / risk distance', () {
      expect(
          riskReward(entry: 100, stopLoss: 90, takeProfit: 130),
          moreOrLessEquals(3.0));
      expect(
          riskReward(entry: 100, stopLoss: 110, takeProfit: 70),
          moreOrLessEquals(3.0));
    });
    test('entry == stop → null (no divide-by-zero)', () {
      expect(riskReward(entry: 100, stopLoss: 100, takeProfit: 130), isNull);
    });
    test('missing → null', () {
      expect(riskReward(entry: null, stopLoss: 90, takeProfit: 130), isNull);
      expect(
          riskReward(entry: 100, stopLoss: null, takeProfit: 130), isNull);
      expect(
          riskReward(entry: 100, stopLoss: 90, takeProfit: null), isNull);
    });
  });
}
