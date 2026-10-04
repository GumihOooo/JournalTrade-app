import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gumibook/core/providers/auth_provider.dart';
import 'package:gumibook/features/journal/journal_provider.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

/// Stubs the journal with fixed trades — no network, no pending timers.
Override journalStub({List<Trade> trades = const []}) =>
    journalProvider.overrideWith(() => _FixedJournal(trades));

/// Keeps the Appwrite boot probe out of any test tree that renders a
/// screen watching auth/settings (pending-timer failures otherwise).
List<Override> noNetworkOverrides({List<Trade> trades = const []}) => [
      journalStub(trades: trades),
      authCheckProvider.overrideWith((ref) async => AuthStatus.authenticated),
      currentUserProvider.overrideWith((ref) async => null),
    ];

class _FixedJournal extends JournalController {
  _FixedJournal(this.fixed);

  final List<Trade> fixed;

  @override
  Future<List<Trade>> build() async => fixed;
}
