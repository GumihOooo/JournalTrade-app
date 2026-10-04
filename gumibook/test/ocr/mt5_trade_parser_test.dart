import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/ocr/domain/mt5_trade_parser.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

/// P1-04: parser fixtures + no-guessing rules (PRD §10 extraction).
/// Anonymized MT5 History rows (one trade per row).
void main() {
  group('full MT5 History row', () {
    test('typical sell row with all columns', () {
      final e = parseMt5TradeRow([
        'XAUUSD sell 0.10 2026.09.05 14:32:11 2026.09.05 15:01:22',
        '3304.55 3306.10',
        'sl 3302.00 tp 3308.50',
        'commission -0.70 swap -5.20 25.00',
      ]);
      expect(e.instrument.value, 'XAUUSD');
      expect(e.direction.value, TradeDirection.sell);
      expect(e.lotSize.value, 0.10);
      expect(e.openTime.value, DateTime(2026, 9, 5, 14, 32, 11));
      expect(e.closeTime.value, DateTime(2026, 9, 5, 15, 1, 22));
      expect(e.entryPrice.value, 3304.55);
      expect(e.exitPrice.value, 3306.10);
      expect(e.stopLoss?.value, 3302.00);
      expect(e.takeProfit?.value, 3308.50);
      expect(e.profitLoss.value, 25.00);
      expect(e.commission?.value, -0.70);
      expect(e.swap?.value, -5.20);
      expect(e.hasAnyField, isTrue);
    });

    test('buy row, single OCR block, no SL/TP labels', () {
      final e = parseMt5TradeRow([
        'EURUSD buy 0.50 2026.08.12 09:15 2026.08.12 10:45 '
            '1.0912 1.0955 s/l 1.0890 t/p 1.1000 commission -2.50 swap 0.00 -43.00',
      ]);
      expect(e.instrument.value, 'EURUSD');
      expect(e.direction.value, TradeDirection.buy);
      expect(e.lotSize.value, 0.50);
      expect(e.entryPrice.value, 1.0912);
      expect(e.exitPrice.value, 1.0955);
      expect(e.stopLoss?.value, 1.0890);
      expect(e.takeProfit?.value, 1.1000);
      expect(e.profitLoss.value, -43.00);
      expect(e.commission?.value, -2.50);
      expect(e.swap?.value, 0.00);
    });
  });

  group('partial OCR (blurry crop)', () {
    test('only symbol and direction survive', () {
      final e = parseMt5TradeRow(['GBPJPY buy', '(rest unreadable)']);
      expect(e.instrument.value, 'GBPJPY');
      expect(e.direction.value, TradeDirection.buy);
      expect(e.lotSize.value, isNull); // P1-04.14: stays null
      expect(e.entryPrice.value, isNull);
      expect(e.openTime.value, isNull);
      expect(e.profitLoss.value, isNull);
      expect(e.hasAnyField, isTrue);
    });

    test('garbage text yields nothing detected', () {
      final e = parseMt5TradeRow(['hello world', 'foo bar']);
      expect(e.hasAnyField, isFalse);
    });

    test('empty blocks yield nothing detected', () {
      final e = parseMt5TradeRow(['', '  ']);
      expect(e.hasAnyField, isFalse);
    });
  });

  group('no-guessing rules (P1-04.15/16)', () {
    test('missing values stay null — never inferred', () {
      final e = parseMt5TradeRow(['XAUUSD buy 0.10']);
      expect(e.entryPrice.value, isNull);
      expect(e.exitPrice.value, isNull);
      expect(e.stopLoss, isNull); // no label, no value
      expect(e.takeProfit, isNull);
      expect(e.profitLoss.value, isNull);
      expect(e.openTime.value, isNull);
      expect(e.closeTime.value, isNull);
    });

    test('direction never inferred from profit sign', () {
      // Sell with positive profit: a profit-sign guess would say buy.
      final e = parseMt5TradeRow([
        'XAUUSD 0.10 2026.09.05 14:32 2026.09.05 15:01',
        '3306.10 3304.55',
        '25.00',
      ]);
      expect(e.profitLoss.value, 25.00);
      expect(e.direction.value, isNull); // no explicit type token
    });

    test('SL/TP never computed from entry/exit', () {
      final e = parseMt5TradeRow(['XAUUSD buy 0.10', '3304.55 3306.10']);
      expect(e.entryPrice.value, 3304.55);
      expect(e.exitPrice.value, 3306.10);
      expect(e.stopLoss, isNull);
      expect(e.takeProfit, isNull);
    });
  });

  group('format tolerance', () {
    test('commas as decimal separators (locale OCR)', () {
      final e = parseMt5TradeRow(['EURUSD buy 0,50', '1,0912 1,0955']);
      expect(e.lotSize.value, 0.50);
      expect(e.entryPrice.value, 1.0912);
      expect(e.exitPrice.value, 1.0955);
    });

    test('ISO-ish date with dashes is read', () {
      final e = parseMt5TradeRow(
          ['EURUSD buy 0.10 2026-09-05 09:15:00 2026-09-05 10:45:00 1.09 1.10']);
      expect(e.openTime.value, DateTime(2026, 9, 5, 9, 15));
      expect(e.closeTime.value, DateTime(2026, 9, 5, 10, 45));
    });

    test('raw text rides along for review UI', () {
      final e = parseMt5TradeRow(['XAUUSD buy']);
      expect(e.instrument.rawText, 'XAUUSD');
      expect(e.direction.rawText, 'buy');
    });
  });
}
