import 'dart:async';

import 'package:appwrite/enums.dart' show ExecutionMethod;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/appwrite_config.dart';
import '../../core/errors/failure.dart';
import '../../core/providers/appwrite_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../trades/trade_repository.dart';
import '../watchlist/watchlist_repository.dart';
import 'user_settings_repository.dart';

/// Delete Data / Delete Account flows (P2-03, DATABASE.md §14).
///
/// Pure orchestration over the two record stores + account removal +
/// local state, so the ordering contract is unit-testable without a
/// network. Default wiring lives in [deleteServiceProvider].
class DeleteService {
  DeleteService({
    required this.deleteAllTrades,
    required this.deleteAllWatchlist,
    required this.deleteSettings,
    required this.removeAccount,
    required this.clearLocalState,
  });

  final Future<void> Function() deleteAllTrades;
  final Future<void> Function() deleteAllWatchlist;
  final Future<void> Function() deleteSettings;
  final Future<void> Function() removeAccount;
  final Future<void> Function() clearLocalState;

  /// Delete All Data: trades + watchlist for the current user. The
  /// account, local session, and `user_settings` stay — P2-03.04
  /// final product decision: Delete All Data is a journal wipe, not a
  /// profile reset.
  Future<void> deleteAllData() async {
    await deleteAllTrades();
    await deleteAllWatchlist();
  }

  /// Delete Account: owned records first (so no orphan rows survive),
  /// then the Appwrite account, then local state. If a record delete
  /// throws, the account is never removed — an orphan-free account
  /// removal cannot proceed half-done.
  Future<void> deleteAccount() async {
    await deleteAllTrades();
    await deleteAllWatchlist();
    await deleteSettings();
    await removeAccount();
    await clearLocalState();
  }
}

final deleteServiceProvider = Provider<DeleteService>((ref) {
  return DeleteService(
    deleteAllTrades: () async {
      // Every owned trade, newest first, then deleted one by one —
      // only the signed-in user's documents are visible to this client.
      final trades = await ref.read(tradeRepositoryProvider).listAll();
      final repo = ref.read(tradeRepositoryProvider);
      for (final t in trades) {
        await repo.delete(t.id);
      }
    },
    deleteAllWatchlist: () async {
      final items = await ref.read(watchlistRepositoryProvider).list();
      final repo = ref.read(watchlistRepositoryProvider);
      for (final i in items) {
        await repo.removeInstrument(i.instrument);
      }
    },
    deleteSettings: () async {
      // P2-03.04 final decision: settings go with the account
      // (trades, watchlist, settings, then the account itself).
      await ref.read(userSettingsRepositoryProvider).deleteOwnDocument();
    },
    removeAccount: () async {
      // No client-side self-delete in Appwrite; the gateway executes
      // users.delete with the function's dynamic API key.
      await ref.read(deleteAccountExecutorProvider)();
    },
    clearLocalState: () async {
      // Sign out the persisted session; router redirect takes it home.
      await ref.read(authControllerProvider.notifier).logout();
    },
  );
});

/// Account-removal executor: overridden in tests; production wiring
/// calls the gateway's `deleteAccount` task. The gateway identifies
/// the caller from `x-appwrite-user-id` (SDK execution carries the
/// session) and runs `users.delete` with its dynamic API key.
final deleteAccountExecutorProvider =
    Provider<Future<void> Function()>((ref) {
  return () async {
    final res = await ref.read(appwriteFunctionsProvider).createExecution(
          functionId: AppwriteConfig.aiGatewayFunctionId,
          body: '{"task":"deleteAccount"}',
          method: ExecutionMethod.pOST,
        );
    // Synchronous execution: 200 + gateway `ok:true` means the
    // account is gone; anything else is retryable failure text.
    final okBody = res.responseBody.isNotEmpty &&
        (res.responseBody.contains('"ok":true'));
    if (res.responseStatusCode != 200 || !okBody) {
      throw const DatabaseFailure('Account deletion failed. Try again.');
    }
  };
});
