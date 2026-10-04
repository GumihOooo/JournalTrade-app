import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/settings/delete_service.dart';

/// P2-03: pure ordering/contract of the deletion flows. Network and
/// Appwrite are faked; what matters here is the sequence — owned
/// records (incl. user_settings per P2-03.04 final decision) first,
/// account last, then local state cleared.
void main() {
  test('deleteAllData wipes trades before watchlist, never account or settings',
      () async {
    final calls = <String>[];
    final svc = DeleteService(
      deleteAllTrades: () async => calls.add('trades'),
      deleteAllWatchlist: () async => calls.add('watchlist'),
      deleteSettings: () async => calls.add('settings'),
      removeAccount: () async => calls.add('account'),
      clearLocalState: () async => calls.add('local'),
    );

    await svc.deleteAllData();

    // P2-03.04 final: Delete All Data is a journal wipe — account AND
    // user_settings stay (DATABASE.md §14).
    expect(calls, ['trades', 'watchlist']);
  });

  test('deleteAccount removes trades, watchlist, settings before the account',
      () async {
    final calls = <String>[];
    final svc = DeleteService(
      deleteAllTrades: () async => calls.add('trades'),
      deleteAllWatchlist: () async => calls.add('watchlist'),
      deleteSettings: () async => calls.add('settings'),
      removeAccount: () async => calls.add('account'),
      clearLocalState: () async => calls.add('local'),
    );

    await svc.deleteAccount();

    // Order matters: an orphan-free account removal needs every owned
    // record (trades, watchlist, user_settings) gone first (DATABASE.md
    // §14); local state cleared last.
    expect(calls, ['trades', 'watchlist', 'settings', 'account', 'local']);
  });

  test('deleteAccount stops before account removal if a record delete fails',
      () async {
    final calls = <String>[];
    final svc = DeleteService(
      deleteAllTrades: () async {
        calls.add('trades');
        throw StateError('network');
      },
      deleteAllWatchlist: () async => calls.add('watchlist'),
      deleteSettings: () async => calls.add('settings'),
      removeAccount: () async => calls.add('account'),
      clearLocalState: () async => calls.add('local'),
    );

    await expectLater(svc.deleteAccount(), throwsA(isA<StateError>()));
    // Account delete must never run with records still present.
    expect(calls, ['trades']);
  });
}
