import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/market/market_providers.dart';
import 'package:gumibook/features/market/market_screen.dart';
import 'package:gumibook/features/watchlist/watchlist_item.dart';
import 'package:gumibook/features/watchlist/watchlist_provider.dart';

import '../helpers/journal_stub.dart';

/// P2-05.11 + P2-04.06: every section renders its own state, and a
/// failing section never blocks another (DESIGN.md §5.14).
void main() {
  testWidgets('sections render with data; quotes show real prices',
      (tester) async {
    await tester.pumpWidget(_app(
      prices: () async => [
        const WatchlistQuote(
          instrument: 'EURUSD',
          quote: Quote(
              symbol: 'EURUSD=X', price: 1.0850, changePercent: 0.23),
        ),
      ],
      news: () async => const NewsBundle(
        news: [MarketNews(title: 'ECB Holds Rates', source: 'Reuters')],
      ),
      fearGreed: () async => FearGreed(
          value: 57, rating: 'greed', updatedAt: DateTime.utc(2026)),
    ));
    await tester.pumpAndSettle();

    // Quotes show real price, not placeholder N/A (P2-05.06 live).
    expect(find.text('EURUSD'), findsOneWidget);
    expect(find.text('1.0850'), findsOneWidget);
    expect(find.text('N/A'), findsNothing);

    // ICT kill-zone chips always render (pure math, no API).
    expect(find.text('Asia'), findsOneWidget);
    expect(find.text('London'), findsOneWidget);
    expect(find.text('NY AM'), findsOneWidget);
    expect(find.text('NY PM'), findsOneWidget);

    // Lower sections are below the fold (chart is 320px tall) — scroll.
    await tester.scrollUntilVisible(
      find.text('ECB Holds Rates'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Reuters'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Fear & Greed'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('57'), findsOneWidget);
    expect(find.text('General market mood: greed'), findsOneWidget);
    expect(find.text('US stock market sentiment — not specific to any pair.'),
        findsOneWidget);
  });

  testWidgets('failed sections degrade independently (P2-05.11)',
      (tester) async {
    await tester.pumpWidget(_app(
      prices: () async => throw const NetworkFailureStub('Prices unavailable.'),
      news: () async => const NewsBundle(
        news: [MarketNews(title: 'Dollar Rallies', source: 'AP')],
      ),
      fearGreed: () async => null,
    ));
    await tester.pumpAndSettle();

    // Price section failed → friendly error, section still titled.
    expect(find.text('Prices unavailable.'), findsOneWidget);

    // News section still renders (section independence).
    await tester.scrollUntilVisible(
      find.text('Dollar Rallies'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('AP'), findsOneWidget);

    // F&G null → no-data friendly state.
    expect(find.text('Fear & Greed index not available'), findsOneWidget);
  });

  testWidgets('price flash: null price shows N/A, not fabricated data',
      (tester) async {
    await tester.pumpWidget(_app(
      prices: () async => [
        const WatchlistQuote(instrument: 'XAUUSD'), // no quote
      ],
      news: () async => const NewsBundle(news: []),
      fearGreed: () async => null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('Market data unavailable'), findsOneWidget);
  });

  testWidgets('XAUUSD row labels the GC futures proxy', (tester) async {
    await tester.pumpWidget(_app(
      prices: () async => [
        const WatchlistQuote(
          instrument: 'XAUUSD',
          quote: Quote(symbol: 'XAUUSD', price: 4332.2, changePercent: 0.4),
        ),
      ],
      news: () async => const NewsBundle(news: []),
      fearGreed: () async => null,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gold futures proxy — not spot'), findsOneWidget);
  });
}

class NetworkFailureStub implements Exception {
  const NetworkFailureStub(this.message);
  final String message;

  @override
  String toString() => message;
}

Widget _app({
  required Future<List<WatchlistQuote>> Function() prices,
  required Future<NewsBundle> Function() news,
  required Future<FearGreed?> Function() fearGreed,
  List<WatchlistItem> watchlist = const [
    WatchlistItem(id: 'w1', userId: 'u1', instrument: 'EURUSD')
  ],
}) {
  return ProviderScope(
    overrides: [
      ...noNetworkOverrides(),
      watchlistProvider.overrideWith(() => _FixedWatchlist(watchlist)),
      pricesProvider.overrideWith((ref) => prices()),
      currencyNewsProvider.overrideWith((ref) => news()),
      fearGreedProvider.overrideWith((ref) => fearGreed()),
      calendarTodayProvider.overrideWith((ref) async => []),
    ],
    child: const MaterialApp(home: MarketScreen()),
  );
}

class _FixedWatchlist extends WatchlistController {
  _FixedWatchlist(this.fixed);

  final List<WatchlistItem> fixed;

  @override
  Future<List<WatchlistItem>> build() async => fixed;
}
