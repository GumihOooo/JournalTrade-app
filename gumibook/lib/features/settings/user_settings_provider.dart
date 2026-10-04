import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/providers/auth_provider.dart';
import 'user_settings_repository.dart';

/// Settings state (P0-11.02, P0-12): empty fields = defaults. Errors
/// never break the dashboard — fields just stay empty.
final userSettingsProvider = FutureProvider<UserSettings>((ref) async {
  if (ref.watch(authStateProvider) != AuthStatus.authenticated) {
    return const UserSettings();
  }
  try {
    return await ref.read(userSettingsRepositoryProvider).read();
  } catch (_) {
    return const UserSettings();
  }
});

/// Active display currency (S-5): the user's `balanceCurrency`, USD
/// when unset. One source for dashboard, journal, detail, and form.
final balanceCurrencyProvider = Provider<String>((ref) {
  final s = ref.watch(userSettingsProvider).valueOrNull;
  return s?.balanceCurrency ?? 'USD';
});

/// Settings mutations (P0-12.04..06c): write then refresh the shared
/// state so the Dashboard Balance card follows immediately.
class SettingsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateProfile({
    String? displayName,
    String? bio,
    DateTime? tradingSince,
    bool clearTradingSince = false,
    double? startingBalance,
    bool clearStartingBalance = false,
    String? balanceCurrency,
    bool isBalanceEdit = false,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(userSettingsRepositoryProvider).updateProfile(
            displayName: displayName,
            bio: bio,
            tradingSince: tradingSince,
            clearTradingSince: clearTradingSince,
            startingBalance: startingBalance,
            clearStartingBalance: clearStartingBalance,
            balanceCurrency: balanceCurrency,
            isBalanceEdit: isBalanceEdit,
          );
      ref.invalidate(userSettingsProvider);
      state = const AsyncData(null);
    } on Failure catch (e) {
      state = AsyncError(e.message, StackTrace.current);
      rethrow;
    }
  }

  Future<void> clearStartingBalance() async {
    state = const AsyncLoading();
    try {
      await ref.read(userSettingsRepositoryProvider).clearStartingBalance();
      ref.invalidate(userSettingsProvider);
      state = const AsyncData(null);
    } on Failure catch (e) {
      state = AsyncError(e.message, StackTrace.current);
      rethrow;
    }
  }

  Future<void> clearTradingSince() =>
      updateProfile(clearTradingSince: true);

  Future<void> changePassword(String newPassword) async {
    state = const AsyncLoading();
    try {
      await ref.read(userSettingsRepositoryProvider).changePassword(newPassword);
      state = const AsyncData(null);
    } on Failure catch (e) {
      state = AsyncError(e.message, StackTrace.current);
      rethrow;
    }
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, void>(SettingsController.new);
