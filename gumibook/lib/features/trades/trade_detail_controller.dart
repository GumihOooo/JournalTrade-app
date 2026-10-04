import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../journal/journal_provider.dart';
import '../trades/domain/trade.dart';
import '../trades/trade_repository.dart';
import '../trades/trade_validation.dart';

/// Trade detail actions (P0-10.06..11): update and delete, each
/// followed by a journal refresh so every reading screen (detail,
/// journal, dashboard — same provider) shows the new state.
class TradeDetailController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Updates the trade, refreshes the shared journal state.
  /// (Named updateTrade: `update` is reserved by AsyncNotifierBase.)
  Future<Trade> updateTrade(Trade trade) async {
    final error = validateTradeDraft(trade.toDraft());
    if (error != null) throw ValidationFailure(error);

    state = const AsyncLoading();
    try {
      final updated = await ref.read(tradeRepositoryProvider).update(trade);
      await ref.read(journalProvider.notifier).refresh();
      state = const AsyncData(null);
      return updated;
    } on Failure {
      state = AsyncError('Update failed', StackTrace.current);
      rethrow;
    }
  }

  /// Deletes the trade, refreshes the shared journal state.
  Future<void> delete(String tradeId) async {
    state = const AsyncLoading();
    try {
      await ref.read(tradeRepositoryProvider).delete(tradeId);
      await ref.read(journalProvider.notifier).refresh();
      state = const AsyncData(null);
    } on Failure {
      state = AsyncError('Delete failed', StackTrace.current);
      rethrow;
    }
  }
}

final tradeDetailControllerProvider =
    AsyncNotifierProvider<TradeDetailController, void>(
        TradeDetailController.new);
