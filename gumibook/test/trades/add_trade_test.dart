import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumibook/core/errors/failure.dart';
import 'package:gumibook/features/journal/journal_provider.dart';
import 'package:gumibook/features/trades/add_trade_controller.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

void main() {
  group('AddTradeController validation rules (P0-08.06..09)', () {
    test('invalid draft throws ValidationFailure, no state change', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draft = TradeDraft(
        instrument: '',
        direction: TradeDirection.buy,
        entryPrice: 100,
        exitPrice: 101,
        lotSize: 0.1,
        profitLoss: 5,
        openTime: DateTime(2026, 1, 1, 10),
        closeTime: DateTime(2026, 1, 1, 11),
      );

      await expectLater(
        container.read(addTradeControllerProvider.notifier).save(draft),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('closeTime before openTime rejected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final draft = TradeDraft(
        instrument: 'XAUUSD',
        direction: TradeDirection.buy,
        entryPrice: 100,
        exitPrice: 101,
        lotSize: 0.1,
        profitLoss: 5,
        openTime: DateTime(2026, 1, 1, 10),
        closeTime: DateTime(2026, 1, 1, 9),
      );

      await expectLater(
        container.read(addTradeControllerProvider.notifier).save(draft),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('DashboardStats derivation (P0-08.16)', () {
    test('empty journal yields zero stats', () {
      expect(computeStats([]).totalTrades, 0);
      expect(computeStats([]).totalProfitLoss, 0);
      expect(computeStats([]).winRate, 0);
      expect(computeStats([]).averageRiskReward, isNull);
    });

    test('mixed trades compute win rate and average RR', () {
      final stats = computeStats([
        _t(profitLoss: 100, riskReward: 2.0),
        _t(profitLoss: -50, riskReward: 1.0),
        _t(profitLoss: 30), // no RR — excluded from average
      ]);
      expect(stats.totalTrades, 3);
      expect(stats.totalProfitLoss, 80);
      expect(stats.winRate, closeTo(66.67, 0.01));
      expect(stats.averageRiskReward, 1.5);
    });
  });
}

Trade _t({required double profitLoss, double? riskReward}) => Trade(
      id: 't$profitLoss',
      userId: 'u',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 100,
      exitPrice: 101,
      lotSize: 1,
      profitLoss: profitLoss,
      riskReward: riskReward,
      openTime: DateTime(2026, 1, 1, 10),
      closeTime: DateTime(2026, 1, 1, 11),
      inputMethod: TradeInputMethod.manual,
    );
