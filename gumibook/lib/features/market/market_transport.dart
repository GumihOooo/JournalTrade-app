/// Transport abstraction for market data (P2-05, ARCHITECTURE.md §14).
///
/// MarketTransport = network I/O only (gateway executions + public
/// endpoints). MarketDataRepository = orchestration + state contract
/// on top. Faked separately in tests so one section's failure never
/// blocks another.
library;

import 'market_data.dart';

abstract interface class MarketTransport {
  /// Sugra quotes via gumibook-ai-gateway.
  Future<List<Quote>> fetchQuotes(List<String> symbols);

  /// Sugra market news via gumibook-ai-gateway. The payload carries the
  /// news items AND the GDELT tone chart, so no second round trip is
  /// needed for the sentiment badges.
  Future<NewsBundle> fetchNews({String query});

  /// LSE economic calendar via gumibook-ai-gateway.
  Future<List<EconomicEvent>> fetchCalendar();

  /// feargreedchart.com — public, no key, called directly from the app.
  Future<FearGreed?> fetchFearGreed();
}
