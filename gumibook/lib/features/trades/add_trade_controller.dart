import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../journal/journal_provider.dart';
import '../trades/domain/trade.dart';
import '../trades/trade_repository.dart';
import '../trades/trade_validation.dart';

/// Manual Add Trade save flow (P0-08.12..16).
///
/// Builds a TradeDraft, validates it (inline errors stay in the form
/// widget), persists via the repository with owner permissions, then
/// refreshes journal + dashboard so both screens show the new trade.
class AddTradeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the created trade, or throws [Failure].
  Future<Trade> save(TradeDraft draft) async {
    final error = validateTradeDraft(draft);
    if (error != null) throw ValidationFailure(error);

    state = const AsyncLoading();
    try {
      final trade = await ref.read(tradeRepositoryProvider).create(draft);
      // Journal refresh cascades to dashboard (same source).
      await ref.read(journalProvider.notifier).refresh();
      state = const AsyncData(null);
      return trade;
    } on Failure {
      state = AsyncError('Save failed', StackTrace.current);
      rethrow;
    }
  }
}

final addTradeControllerProvider =
    AsyncNotifierProvider<AddTradeController, void>(AddTradeController.new);
