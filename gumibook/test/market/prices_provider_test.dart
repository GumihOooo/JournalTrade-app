import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/market/market_data_repository.dart';
import 'package:gumibook/features/market/market_providers.dart';
import 'package:gumibook/features/market/market_transport.dart';
import 'package:gumibook/features/watchlist/watchlist_item.dart';
import 'package:gumibook/features/watchlist/watchlist_provider.dart';

import '../helpers/journal_stub.dart';

/// DXY must never become a price card: Sugra has no ICE US Dollar
/// Index, and ^USDOLLAR clashes with the TVC:DXY chart scale. The
/// watchlist keeps DXY so the TradingView chart stays the source.
void main() {
  ProviderContainer container(List<WatchlistItem> watchlist) {
    return ProviderContainer(overrides: [
      ...noNetworkOverrides(),
      watchlistProvider.overrideWith(() => _FixedWatchlist(watchlist)),
      marketTransportProvider.overrideWithValue(_FixedTransport()),
    ]);
  }

  test('DXY is skipped in the price cards, others are kept', () async {
    final c = container([
      WatchlistItem(id: 'w1', userId: 'u1', instrument: 'DXY'),
      WatchlistItem(id: 'w2', userId: 'u1', instrument: 'EURUSD'),
      WatchlistItem(id: 'w3', userId: 'u1', instrument: 'NQ'),
    ]);

    final rows = await c.read(pricesProvider.future);

    expect(rows.map((r) => r.instrument), ['EURUSD', 'NQ']);
    expect(rows.where((r) => r.instrument == 'DXY'), isEmpty);
    c.dispose();
  });

  test('DXY-only watchlist yields no price cards at all', () async {
    final c = container([
      WatchlistItem(id: 'w1', userId: 'u1', instrument: 'DXY'),
    ]);

    final rows = await c.read(pricesProvider.future);

    expect(rows, isEmpty);
    c.dispose();
  });
}

class _FixedWatchlist extends WatchlistController {
  _FixedWatchlist(this.fixed);
  final List<WatchlistItem> fixed;

  @override
  Future<List<WatchlistItem>> build() async => fixed;
}

class _FixedTransport implements MarketTransport {
  @override
  Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    return [for (final s in symbols) Quote(symbol: s, price: 1)];
  }

  @override
  Future<NewsBundle> fetchNews({String query = ''}) async =>
      const NewsBundle(news: []);

  @override
  Future<List<EconomicEvent>> fetchCalendar() async => [];

  @override
  Future<FearGreed?> fetchFearGreed() async => null;
}
