import 'package:appwrite/models.dart' as models;
import 'package:flutter_test/flutter_test.dart';
import 'package:gumibook/features/trades/domain/trade.dart';
import 'package:gumibook/features/trades/trade_mapper.dart';
import 'package:gumibook/features/trades/trade_repository.dart';
import 'package:gumibook/features/trades/trade_validation.dart';

models.Document _doc(Map<String, dynamic> data,
        {String id = 'doc1', String userId = 'userA'}) =>
    models.Document(
      $id: id,
      $collectionId: 'c',
      $databaseId: 'db',
      $sequence: '1',
      $createdAt: '2026-09-01T10:00:00.000+00:00',
      $updatedAt: '2026-09-01T10:00:00.000+00:00',
      $permissions: [],
      data: {'userId': userId, ...data},
    );

void main() {
  group('validateTradeDraft (DATABASE.md §4.2)', () {
    test('valid draft passes', () {
      expect(validateTradeDraft(_draft()), isNull);
    });

    test('empty instrument rejected', () {
      expect(validateTradeDraft(_draft(instrument: ' ')),
          'Instrument is required.');
    });

    test('entry == exit rejected', () {
      expect(validateTradeDraft(_draft(entryPrice: 100, exitPrice: 100)),
          'Entry and exit prices must differ.');
    });

    test('lotSize <= 0 rejected', () {
      expect(validateTradeDraft(_draft(lotSize: 0)), 'Lot size must be greater than 0.');
    });

    test('closeTime before openTime rejected', () {
      expect(
        validateTradeDraft(_draft(closeTime: DateTime(2026, 1, 1, 9))),
        'Close time must not be before open time.',
      );
    });

    test('closeTime == openTime is allowed', () {
      final t = DateTime(2026, 1, 1, 10);
      expect(validateTradeDraft(_draft(openTime: t, closeTime: t)), isNull);
    });
  });

  group('TradeMapper round-trip', () {
    test('toDocument/fromDocument preserves fields', () {
      final trade = _trade();
      final doc = _doc(TradeMapper.toDocument(trade));

      final back = TradeMapper.fromDocument(doc);
      expect(back.instrument, 'XAUUSD');
      expect(back.direction, TradeDirection.buy);
      expect(back.entryPrice, 2401.25);
      expect(back.stopLoss, 2395.00);
      expect(back.lotSize, 0.10);
      expect(back.profitLoss, 115.50);
      expect(back.confluence, ['HTF bias', 'liquidity sweep']);
      expect(back.inputMethod, TradeInputMethod.manual);
      expect(back.openTime, trade.openTime);
      expect(back.closeTime, trade.closeTime);
    });

    test('null optional fields stay null, never inferred', () {
      final doc = _doc({
        'instrument': 'EURUSD',
        'direction': 'sell',
        'entryPrice': 1.1,
        'exitPrice': 1.2,
        'lotSize': 0.5,
        'profitLoss': -10,
        'openTime': '2026-01-01T10:00:00.000',
        'closeTime': '2026-01-01T11:00:00.000',
        'inputMethod': 'ocr',
        // stopLoss/takeProfit/strategy missing entirely.
      });
      final t = TradeMapper.fromDocument(doc);
      expect(t.stopLoss, isNull);
      expect(t.takeProfit, isNull);
      expect(t.strategy, isNull);
      expect(t.inputMethod, TradeInputMethod.ocr);
    });

    test('accountType round-trips and falls back to real', () {
      final real = TradeMapper.fromDocument(_doc(TradeMapper.toDocument(
        _trade(),
      )));
      expect(real.accountType, TradeAccountType.real);

      final funded = _doc({
        'instrument': 'XAUUSD',
        'direction': 'buy',
        'accountType': 'funded',
        'entryPrice': 1,
        'exitPrice': 2,
        'lotSize': 1,
        'profitLoss': 5,
        'openTime': '2026-01-01T10:00:00.000',
        'closeTime': '2026-01-01T11:00:00.000',
        'inputMethod': 'manual',
      });
      expect(TradeMapper.fromDocument(funded).accountType,
          TradeAccountType.funded);

      // Unknown string degrades to real, never throws.
      final bad = _doc({
        'instrument': 'XAUUSD',
        'direction': 'buy',
        'accountType': 'demo',
        'entryPrice': 1,
        'exitPrice': 2,
        'lotSize': 1,
        'profitLoss': 5,
        'openTime': '2026-01-01T10:00:00.000',
        'closeTime': '2026-01-01T11:00:00.000',
        'inputMethod': 'manual',
      });
      expect(TradeMapper.fromDocument(bad).accountType,
          TradeAccountType.real);
    });

    test('unknown enum strings degrade, do not throw', () {
      final doc = _doc({
        'instrument': 'XAUUSD',
        'direction': 'long',
        'entryPrice': 1,
        'exitPrice': 2,
        'lotSize': 1,
        'profitLoss': 5,
        'openTime': '2026-01-01T10:00:00.000',
        'closeTime': '2026-01-01T11:00:00.000',
        'inputMethod': 'voice',
      });
      final t = TradeMapper.fromDocument(doc);
      expect(t.direction, TradeDirection.buy); // fallback
      expect(t.inputMethod, TradeInputMethod.manual); // fallback
    });
  });

  group('ownerPermissions (DATABASE.md §5)', () {
    test('grants read/update/delete only to the owner', () {
      final perms = ownerPermissions('userA');
      expect(perms, [
        'read("user:userA")',
        'update("user:userA")',
        'delete("user:userA")',
      ]);
      expect(perms, isNot(contains(contains('any'))));
      expect(perms, isNot(contains(contains('guests'))));
    });
  });

  group('TradeDraft → Trade preserves ownership', () {
    test('outcome derives from profitLoss sign', () {
      expect(_trade().outcome, TradeOutcome.win);
      expect(_trade(profitLoss: -5).outcome, TradeOutcome.loss);
      expect(_trade(profitLoss: 0).outcome, TradeOutcome.breakeven);
    });
  });
}

TradeDraft _draft({
  String instrument = 'XAUUSD',
  double entryPrice = 2401.25,
  double exitPrice = 2412.80,
  double lotSize = 0.10,
  DateTime? openTime,
  DateTime? closeTime,
}) =>
    TradeDraft(
      instrument: instrument,
      direction: TradeDirection.buy,
      entryPrice: entryPrice,
      exitPrice: exitPrice,
      stopLoss: 2395.00,
      takeProfit: 2415.00,
      lotSize: lotSize,
      profitLoss: 115.50,
      riskReward: 1.84,
      openTime: openTime ?? DateTime(2026, 8, 29, 9, 15),
      closeTime: closeTime ?? DateTime(2026, 8, 29, 10, 40),
      strategy: 'London Breakout',
      session: 'London',
      confluence: const ['HTF bias', 'liquidity sweep'],
      emotion: 'calm',
      inputMethod: TradeInputMethod.manual,
    );

Trade _trade({double profitLoss = 115.50}) => Trade(
      id: 'doc1',
      userId: 'userA',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 2401.25,
      exitPrice: 2412.80,
      stopLoss: 2395.00,
      takeProfit: 2415.00,
      lotSize: 0.10,
      profitLoss: profitLoss,
      riskReward: 1.84,
      openTime: DateTime(2026, 8, 29, 9, 15),
      closeTime: DateTime(2026, 8, 29, 10, 40),
      strategy: 'London Breakout',
      session: 'London',
      confluence: const ['HTF bias', 'liquidity sweep'],
      emotion: 'calm',
      inputMethod: TradeInputMethod.manual,
    );
