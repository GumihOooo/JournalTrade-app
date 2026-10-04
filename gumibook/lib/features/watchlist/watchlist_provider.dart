import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import 'default_watchlist.dart';
import 'watchlist_repository.dart';

/// Watchlist state (P2-04): the signed-in user's instruments.
class WatchlistController extends AsyncNotifier<List<WatchlistItem>> {
  @override
  Future<List<WatchlistItem>> build() async {
    if (ref.watch(authStateProvider) != AuthStatus.authenticated) {
      return const [];
    }
    return ref.read(watchlistRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
        () => ref.read(watchlistRepositoryProvider).list());
  }

  Future<void> add(String instrument) async {
    await ref.read(watchlistRepositoryProvider).addInstrument(instrument);
    await refresh();
  }

  Future<void> remove(String instrument) async {
    await ref.read(watchlistRepositoryProvider).removeInstrument(instrument);
    await refresh();
  }

  /// Seeds the priority-ordered default instruments (P2-05 revisi).
  /// Skips duplicates and per-add failures — partial seed is fine.
  Future<void> addDefaults() async {
    for (final instrument in defaultWatchlistInstruments) {
      try {
        await ref.read(watchlistRepositoryProvider).addInstrument(instrument);
      } on DuplicateInstrumentFailure {
        continue;
      }
    }
    await refresh();
  }
}

final watchlistProvider =
    AsyncNotifierProvider<WatchlistController, List<WatchlistItem>>(
        WatchlistController.new);
