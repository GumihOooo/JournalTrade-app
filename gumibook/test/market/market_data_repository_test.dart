import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/market/market_data.dart';
import 'package:gumibook/features/market/market_data_repository.dart';
import 'package:gumibook/features/market/market_transport.dart';

import '../helpers/journal_stub.dart';

/// P2-05.05: repository contract with faked transports — what matters
/// is state transitions (available/no data/unavailable/error) and that
/// one section's failure never blocks another.
void main() {
  late FakeMarketTransport transport;
  late ProviderContainer container;

  setUp(() {
    transport = FakeMarketTransport();
    container = ProviderContainer(overrides: [
      ...noNetworkOverrides(),
      marketTransportProvider.overrideWithValue(transport),
    ]);
  });

  tearDown(() => container.dispose());

  MarketDataRepository repo() =>
      container.read(marketDataRepositoryProvider);

  test('getWatchlistQuotes returns quotes (available)', () async {
    transport.quotesResult = () => [
          const Quote(symbol: 'EURUSD=X', price: 1.085),
        ];

    final quotes = await repo().getWatchlistQuotes(['EURUSD']);

    expect(quotes, hasLength(1));
    expect(quotes.single.isAvailable, isTrue);
  });

  test('empty quotes list is no data, not an error', () async {
    transport.quotesResult = () => [];

    final quotes = await repo().getWatchlistQuotes(['EURUSD']);

    expect(quotes, isEmpty);
  });

  test('quotes failure surfaces as exception (unavailable state)', () async {
    transport.quotesError = StateError('HTTP 502');

    await expectLater(
      repo().getWatchlistQuotes(['EURUSD']),
      throwsA(isA<StateError>()),
    );
  });

  test('getTodayCalendar filters strictly to today', () async {
    transport.calendarResult = () => [
          EconomicEvent(
              name: 'Today Event', datetime: DateTime.utc(2026, 9, 12, 10)),
          EconomicEvent(
              name: 'Yesterday', datetime: DateTime.utc(2026, 9, 11, 10)),
        ];

    final events = await repo()
        .getTodayCalendar(DateTime.utc(2026, 9, 12, 15, 0));

    expect(events, hasLength(1));
    expect(events.single.name, 'Today Event');
  });

  test('news and fear-greed are independent transports', () async {
    transport.newsError = StateError('HTTP 429');
    transport.fearGreedResult = () =>
        FearGreed(value: 57, rating: 'greed', updatedAt: DateTime.utc(2026));

    // News fails but F&G must still return (independent sections).
    await expectLater(
        repo().getNews(query: 'USD'), throwsA(isA<StateError>()));
    final fg = await repo().getFearGreed();
    expect(fg?.value, 57);
  });

  test('getNews returns the news bundle with shared sentiment', () async {
    transport.newsResult = () => const NewsBundle(
          sentiment: Sentiment(
              label: SentimentLabel.negative, confidence: 12),
          news: [MarketNews(title: 'Dollar slides')],
        );

    final bundle = await repo().getNews(query: 'USD');

    expect(bundle.news.single.title, 'Dollar slides');
    expect(bundle.sentiment?.label, SentimentLabel.negative);
  });

  test('news sentiment null stays a no-data badge, not an error', () async {
    transport.newsResult = () =>
        const NewsBundle(news: [MarketNews(title: 'Headline only')]);

    final bundle = await repo().getNews(query: 'USD');

    expect(bundle.sentiment, isNull);
    expect(bundle.news, hasLength(1));
  });
}

class FakeMarketTransport implements MarketTransport {
  List<Quote> Function()? quotesResult;
  Object? quotesError;
  NewsBundle Function()? newsResult;
  Object? newsError;
  List<EconomicEvent> Function()? calendarResult;
  Object? calendarError;
  FearGreed? Function()? fearGreedResult;

  @override
  Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    if (quotesError != null) throw quotesError!;
    return quotesResult?.call() ?? [];
  }

  @override
  Future<NewsBundle> fetchNews({String query = ''}) async {
    if (newsError != null) throw newsError!;
    return newsResult?.call() ?? const NewsBundle(news: []);
  }

  @override
  Future<List<EconomicEvent>> fetchCalendar() async {
    if (calendarError != null) throw calendarError!;
    return calendarResult?.call() ?? [];
  }

  @override
  Future<FearGreed?> fetchFearGreed() async {
    return fearGreedResult?.call();
  }
}
