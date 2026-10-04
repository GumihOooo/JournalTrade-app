import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'market_data.dart';
import 'market_data_repository.dart';
import 'market_session_clock.dart';
import '../watchlist/watchlist_provider.dart';

/// Market section state (P2-05, DESIGN.md §5.14).
///
/// Five independent section states: price, calendar, news, sentiment,
/// fear & greed. Chart is a TradingView Widget embed (no provider).
/// A failed section NEVER blocks another — each provider catches its
/// own errors and degrades to unavailable/no-data.

export 'market_data.dart';

/// Watchlist instrument rows (instrument + latest quote, quote may be
/// null = unavailable for that symbol).
class WatchlistQuote {
  const WatchlistQuote({required this.instrument, this.quote});

  final String instrument;
  final Quote? quote;

  bool get isAvailable => quote?.isAvailable ?? false;
}

/// Price section: watchlist + quotes joined by instrument. The gateway
/// echoes the instrument key back as the quote symbol.
///
/// DXY is EXCLUDED from the price cards: Sugra has no ICE US Dollar
/// Index (DX-Y.NYB unverified; ^USDOLLAR is the Dow Jones FXCM variant
/// and its ~12k scale clashes with the TVC:DXY chart). The watchlist
/// keeps DXY so the TradingView chart stays the only DXY representation.
final _noPriceCardInstruments = <String>{'DXY'};

final pricesProvider =
    FutureProvider.autoDispose<List<WatchlistQuote>>((ref) async {
  final instruments = await ref.watch(watchlistProvider.future);
  final symbols = instruments
      .map((i) => i.instrument)
      .where((s) => !_noPriceCardInstruments.contains(s.toUpperCase()))
      .toList();
  if (symbols.isEmpty) return const [];

  final quotes = await ref
      .read(marketDataRepositoryProvider)
      .getWatchlistQuotes(symbols);
  final bySymbol = {for (final q in quotes) q.symbol: q};

  return [
    for (final instrument in instruments)
      if (!_noPriceCardInstruments.contains(instrument.instrument.toUpperCase()))
        WatchlistQuote(
          instrument: instrument.instrument,
          quote: bySymbol[instrument.instrument],
        ),
  ];
});

/// Economic calendar, strictly today (P2-05.07).
final calendarTodayProvider = FutureProvider.autoDispose<List<EconomicEvent>>(
    (ref) async {
  return ref.read(marketDataRepositoryProvider).getTodayCalendar(
        DateTime.now(),
      );
});

/// Business news (P2-05.08). The bundle also carries the shared GDELT
/// sentiment (P2-05.09) — one round trip, no per-item AI call.
final currencyNewsProvider =
    FutureProvider.autoDispose<NewsBundle>((ref) {
  return ref.read(marketDataRepositoryProvider).getNews(query: 'USD');
});

/// Fear & Greed index (public endpoint, P2-05.10).
final fearGreedProvider =
    FutureProvider.autoDispose<FearGreed?>((ref) {
  return ref.read(marketDataRepositoryProvider).getFearGreed();
});

/// Refresh every market section at once (pull-to-refresh).
Future<void> refreshAll(WidgetRef ref) async {
  ref.invalidate(pricesProvider);
  ref.invalidate(calendarTodayProvider);
  ref.invalidate(currencyNewsProvider);
  ref.invalidate(fearGreedProvider);
}

/// ICT kill-zone ticker — rebuilds every 30s so the clock stays live.
final sessionClockProvider = StreamProvider.autoDispose<KillZoneState>((ref) {
  final ctrl = StreamController<KillZoneState>();
  void emit() => ctrl.add(killZoneState(DateTime.now()));
  emit();
  final timer = Timer.periodic(
      const Duration(seconds: 30), (_) => emit());
  ref.onDispose(() {
    timer.cancel();
    ctrl.close();
  });
  return ctrl.stream;
});
