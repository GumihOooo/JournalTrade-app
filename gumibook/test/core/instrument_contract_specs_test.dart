import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/constants/instrument_contract_specs.dart';

void main() {
  group('contractSizeOf', () {
    test('known instruments return MT5 contract sizes', () {
      expect(contractSizeOf('XAUUSD'), 100);
      expect(contractSizeOf('EURUSD'), 100000);
      expect(contractSizeOf('GBPUSD'), 100000);
      expect(contractSizeOf('BTCUSD'), 1);
      expect(contractSizeOf('NAS100'), 10);
      expect(contractSizeOf('SPX500'), 10);
      expect(contractSizeOf('US30'), 1);
    });

    test('case-insensitive and trims; unknown stays null', () {
      expect(contractSizeOf(' xauusd '), 100);
      expect(contractSizeOf('DOGEUSD'), isNull);
      expect(contractSizeOf(null), isNull);
    });
  });

  group('autoProfitLoss', () {
    test('buy XAUUSD 0.10 lots, +10 price move = +100 USD', () {
      final pl = autoProfitLoss(
        instrument: 'XAUUSD',
        isBuy: true,
        entry: 2400,
        exit: 2410,
        lotSize: 0.10,
      );
      expect(pl, 100);
    });

    test('sell same move flips sign', () {
      final pl = autoProfitLoss(
        instrument: 'XAUUSD',
        isBuy: false,
        entry: 2400,
        exit: 2410,
        lotSize: 0.10,
      );
      expect(pl, -100);
    });

    test('EURUSD 1 lot, 20 pip move = 200 USD', () {
      final pl = autoProfitLoss(
        instrument: 'EURUSD',
        isBuy: true,
        entry: 1.0800,
        exit: 1.0820,
        lotSize: 1,
      );
      expect(pl, closeTo(200, 0.001));
    });

    test('unknown instrument or missing input stays null', () {
      expect(
        autoProfitLoss(
          instrument: 'DOGEUSD',
          isBuy: true,
          entry: 1,
          exit: 2,
          lotSize: 1,
        ),
        isNull,
      );
      expect(
        autoProfitLoss(
          instrument: 'XAUUSD',
          isBuy: true,
          entry: null,
          exit: 2,
          lotSize: 1,
        ),
        isNull,
      );
    });
  });

  group('autoRiskReward', () {
    test('2R when reward is twice the risk', () {
      final rr = autoRiskReward(entry: 100, exit: 110, stopLoss: 95);
      expect(rr, 2);
    });

    test('short trade: risk above entry, reward below', () {
      final rr = autoRiskReward(entry: 100, exit: 90, stopLoss: 105);
      expect(rr, 2);
    });

    test('stop equal to entry stays null (no division by zero)', () {
      expect(autoRiskReward(entry: 100, exit: 110, stopLoss: 100), isNull);
    });

    test('missing stop stays null', () {
      expect(autoRiskReward(entry: 100, exit: 110, stopLoss: null), isNull);
    });
  });
}
