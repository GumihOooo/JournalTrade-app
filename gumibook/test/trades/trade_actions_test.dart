import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gumibook/features/trades/domain/trade.dart';
import 'package:gumibook/features/trades/trade_detail_controller.dart';
import 'package:gumibook/features/trades/trade_detail_screen.dart';
import 'package:gumibook/features/trades/trade_repository.dart';

import '../helpers/journal_stub.dart';

/// Fake repository: no network, records calls (P0-10.06, P0-10.10).
class FakeTradeRepository extends TradeRepository {
  FakeTradeRepository(super.ref);

  Trade? updated;
  List<String> deleted = [];

  @override
  Future<Trade> update(Trade trade) async {
    updated = trade;
    return trade;
  }

  @override
  Future<void> delete(String tradeId) async {
    deleted.add(tradeId);
  }

  @override
  Future<Trade?> getById(String tradeId) async => null;

  @override
  Future<List<Trade>> list(
          {TradeSort sort = TradeSort.newest, int limit = 100}) async =>
      const [];

  @override
  Future<TradePage> listPaged(
          {TradeSort sort = TradeSort.newest,
          int limit = 25,
          String? cursor}) async =>
      const TradePage(trades: [], hasMore: false);
}

Trade trade() => Trade(
      id: 't1',
      userId: 'u1',
      instrument: 'XAUUSD',
      direction: TradeDirection.sell,
      accountType: TradeAccountType.funded,
      entryPrice: 2400,
      exitPrice: 2390,
      lotSize: 0.5,
      profitLoss: -500,
      openTime: DateTime(2026, 1, 1, 9),
      closeTime: DateTime(2026, 1, 1, 10),
      inputMethod: TradeInputMethod.manual,
    );

void main() {
  testWidgets(
      'delete flow: confirm dialog, repository delete, back to journal',
      (tester) async {
    FakeTradeRepository? repo;

    final router = GoRouter(
      initialLocation: '/trade/t1',
      routes: [
        GoRoute(
          path: '/trade/:id',
          builder: (context, state) =>
              TradeDetailScreen(tradeId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/app/journal',
          builder: (context, state) =>
              const Scaffold(body: Text('journal-placeholder')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...noNetworkOverrides(trades: [trade()]),
          tradeRepositoryProvider.overrideWith((ref) {
            final r = FakeTradeRepository(ref);
            repo = r;
            return r;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // P0-10.09: dialog first, nothing deleted yet (repo stays unbuilt —
    // the provider is lazy, so no delete could have happened).
    await tester.tap(find.byTooltip('Delete trade'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Trade'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    // Controller delete + journal refresh resolve across microtasks —
    // let them land before asserting.
    await tester.pump(const Duration(milliseconds: 300));

    // P0-10.10/11: deleted via repository, snackbar, journal shown.
    expect(repo!.deleted, ['t1']);
    expect(find.text('Trade deleted.'), findsOneWidget);
    expect(find.text('journal-placeholder'), findsOneWidget);
  });

  test('update flows through the controller and refreshes journal', () async {
    FakeTradeRepository? repo;
    final container = ProviderContainer(overrides: [
      tradeRepositoryProvider.overrideWith((ref) {
        final r = FakeTradeRepository(ref);
        repo = r;
        return r;
      }),
    ]);
    addTearDown(container.dispose);

    final edited = trade().copyWith(profitLoss: -420);
    final updated = await container
        .read(tradeDetailControllerProvider.notifier)
        .updateTrade(edited);

    expect(repo!.updated, isNotNull);
    expect(updated.profitLoss, -420);
    // Identity fields preserved through the update path.
    expect(updated.userId, 'u1');
    expect(updated.id, 't1');
    expect(updated.inputMethod, TradeInputMethod.manual);
  });
}
