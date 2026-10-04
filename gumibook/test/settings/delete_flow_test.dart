import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/providers/auth_provider.dart';
import 'package:gumibook/features/journal/journal_provider.dart';
import 'package:gumibook/features/settings/delete_service.dart';
import 'package:gumibook/features/settings/settings_screen.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

import '../helpers/journal_stub.dart';

/// P2-03.01/05: confirmation dialogs before any destructive call, and
/// cancel never deletes. The real service is overridden by a spy.
void main() {
  testWidgets('Delete All Data asks first; cancel deletes nothing',
      (tester) async {
    final calls = <String>[];
    final spy = DeleteService(
      deleteAllTrades: () async => calls.add('trades'),
      deleteAllWatchlist: () async => calls.add('watchlist'),
      deleteSettings: () async => calls.add('settings'),
      removeAccount: () async => calls.add('account'),
      clearLocalState: () async => calls.add('local'),
    );

    await tester.pumpWidget(_app(spy));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete All Data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete All Data'));
    await tester.pumpAndSettle();

    // Dialog states the impact (DATABASE.md §14).
    expect(find.text('Delete All Data'), findsWidgets);
    expect(find.textContaining('every trade'), findsOneWidget);

    // Cancel: no service call.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('Delete All Data wipes trades and watchlist, keeps account',
      (tester) async {
    final calls = <String>[];
    final store = _MutableJournal([_fakeTrade()]);
    final spy = DeleteService(
      // Wipe the backing store, mirroring the real repository delete.
      deleteAllTrades: () async {
        calls.add('trades');
        store.clear();
      },
      deleteAllWatchlist: () async => calls.add('watchlist'),
      deleteSettings: () async => calls.add('settings'),
      removeAccount: () async => calls.add('account'),
      clearLocalState: () async => calls.add('local'),
    );

    final container = ProviderContainer(overrides: [
      authCheckProvider.overrideWith((ref) async => AuthStatus.authenticated),
      currentUserProvider.overrideWith((ref) async => null),
      journalProvider.overrideWith(() => store),
      deleteServiceProvider.overrideWithValue(spy),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Cache preloaded with real trades — proves the invalidation below
    // is what empties it, not an empty stub.
    final before = await container.read(journalProvider.future);
    expect(before, hasLength(1));

    await tester.scrollUntilVisible(
      find.text('Delete All Data'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete All Data').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete All Data').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    // P2-03.02/03: trades + watchlist gone, account + settings untouched.
    expect(calls, ['trades', 'watchlist']);
    expect(find.text('All journal data deleted.'), findsOneWidget);

    // Bug 2: cache refresh — the screen must invalidate journalProvider
    // so the wiped list shows immediately.
    await tester.pump(const Duration(milliseconds: 300));
    expect(await container.read(journalProvider.future), isEmpty);
  });

  testWidgets('Delete Account confirmed removes records then account',
      (tester) async {
    final calls = <String>[];
    final spy = DeleteService(
      deleteAllTrades: () async => calls.add('trades'),
      deleteAllWatchlist: () async => calls.add('watchlist'),
      deleteSettings: () async => calls.add('settings'),
      removeAccount: () async => calls.add('account'),
      clearLocalState: () async => calls.add('local'),
    );

    await tester.pumpWidget(_app(spy));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete Account'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    // P2-03.06..08 + P2-03.04 final: every owned record (incl.
    // user_settings) before the account, local state cleared last.
    expect(calls, ['trades', 'watchlist', 'settings', 'account', 'local']);
  });
}

Widget _app(DeleteService spy) => ProviderScope(
      overrides: [
        ...noNetworkOverrides(),
        deleteServiceProvider.overrideWithValue(spy),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );

/// Journal backed by a mutable list — delete flows empty it, then the
/// screen's invalidation is what makes the UI follow.
class _MutableJournal extends JournalController {
  _MutableJournal(this._items);

  final List<Trade> _items;

  void clear() => _items.clear();

  @override
  Future<List<Trade>> build() async => List.of(_items);
}

Trade _fakeTrade() => Trade(
      id: 't1',
      userId: 'u1',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 2000,
      exitPrice: 2010,
      lotSize: 0.1,
      profitLoss: 100,
      openTime: DateTime.utc(2026, 9, 1, 10),
      closeTime: DateTime.utc(2026, 9, 1, 12),
      inputMethod: TradeInputMethod.manual,
    );
