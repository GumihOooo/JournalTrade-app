/// MarketDataRepository (P2-05.05, ARCHITECTURE.md §14).
///
/// Orchestration over [MarketTransport]: today-only calendar filtering
/// and state contract (available / no data / unavailable / error).
/// Chart data is NOT here — the chart is a TradingView Widget embed
/// (see market_screen.dart), never a repository render.
library;

import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart'
    show AppwriteException, Functions;
import 'package:appwrite/enums.dart' show ExecutionMethod, ExecutionStatus;
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/appwrite_config.dart';
import '../../core/errors/failure.dart';
import '../../core/providers/appwrite_provider.dart';
import 'market_data.dart';
import 'market_parsers.dart';
import 'market_transport.dart';

abstract interface class MarketDataRepository {
  /// Quotes for the given watchlist instruments. Unmapped instruments
  /// are skipped; unavailable prices stay null (no-data per symbol).
  Future<List<Quote>> getWatchlistQuotes(List<String> instruments);

  /// Business news for the query topic; the payload also carries the
  /// GDELT tone sentiment. Empty list = no-data state.
  Future<NewsBundle> getNews({String query});

  /// Economic calendar filtered STRICTLY to today (user's local day,
  /// normalized to UTC date). P2-05 spec: only today's events.
  Future<List<EconomicEvent>> getTodayCalendar(DateTime today);

  /// Fear & Greed index snapshot; null = no data.
  Future<FearGreed?> getFearGreed();
}

/// Production transport: gateway executions + public fetch.
/// Registered via [marketTransportProvider]; tests override it.
final marketTransportProvider = Provider<MarketTransport>((ref) {
  return GatewayMarketTransport(
    functions: ref.watch(appwriteFunctionsProvider),
  );
});

class GatewayMarketTransport implements MarketTransport {
  GatewayMarketTransport({
    required this.functions,
    this.fetchFearGreedImpl,
  });

  final Functions functions;

  /// Injectable for tests (default: real HTTP via dart:io).
  final Future<FearGreed?> Function()? fetchFearGreedImpl;

  /// P2-05 revisi: ONE gateway for everything (function-slot economy).
  static final _gatewayId = AppwriteConfig.aiGatewayFunctionId;

  /// Executes a gateway task and returns its `data` payload. Gateway
  /// errors map to typed failures; 429/provider-down are retryable
  /// state, missing key is "not configured yet" (unavailable).
  Future<dynamic> _execute(
      String functionId, String task, Map<String, dynamic> payload) async {
    models.Execution execution;
    try {
      execution = await functions.createExecution(
        functionId: functionId,
        body: jsonEncode({'task': task, 'payload': payload}),
        method: ExecutionMethod.pOST,
      );
    } on AppwriteException catch (e) {
      throw NetworkFailure('Market gateway unavailable: ${e.message}');
    } catch (_) {
      throw const NetworkFailure(
          'Market gateway unreachable. Check your connection.');
    }

    if (execution.status == ExecutionStatus.failed || execution.responseBody.isEmpty) {
      throw const NetworkFailure('Market gateway execution failed.');
    }
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(execution.responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw const NetworkFailure('Received invalid market data.');
    }
    if (decoded['ok'] != true) {
      final error = (decoded['error'] as String?) ?? 'Market data error.';
      throw NetworkFailure(error);
    }
    return decoded['data'];
  }

  @override
  Future<List<Quote>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return [];
    final data = await _execute(_gatewayId, 'marketPrice', {
      'symbols': symbols,
    });
    return parseQuotes(data);
  }

  @override
  Future<NewsBundle> fetchNews({String query = ''}) async {
    final data = await _execute(_gatewayId, 'marketNews', {
      'category': 'business',
      'limit': 20,
      'query': query,
    });
    return parseNewsBundle(data);
  }

  @override
  Future<List<EconomicEvent>> fetchCalendar() async {
    final data = await _execute(_gatewayId, 'marketCalendar', {});
    return parseCalendar(data);
  }

  @override
  Future<FearGreed?> fetchFearGreed() {
    if (fetchFearGreedImpl != null) return fetchFearGreedImpl!();
    return _fetchFearGreedDirect();
  }

  /// Public no-auth endpoint — direct from the app is fine (no secret).
  Future<FearGreed?> _fetchFearGreedDirect() async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final uri = Uri.parse('https://www.feargreedchart.com/api?action=all');
        final req = await client.getUrl(uri);
        final res = await req.close().timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) {
          throw const NetworkFailure(
              'Fear & Greed unavailable. Try again shortly.');
        }
        final body = await res.transform(utf8.decoder).join();
        return parseFearGreed(jsonDecode(body));
      } finally {
        client.close();
      }
    } on Failure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure(
          'Fear & Greed unavailable. Check your connection.');
    }
  }
}

/// Repository implementation (ARCHITECTURE.md §14). Pure orchestration
/// over [MarketTransport]; one failed section must never block others,
/// so every method throws only for its OWN section.
class RepositoryMarketDataRepository implements MarketDataRepository {
  RepositoryMarketDataRepository(this._transport);

  final MarketTransport _transport;

  @override
  Future<List<Quote>> getWatchlistQuotes(List<String> instruments) =>
      _transport.fetchQuotes(instruments);

  @override
  Future<NewsBundle> getNews({String query = ''}) =>
      _transport.fetchNews(query: query);

  @override
  Future<List<EconomicEvent>> getTodayCalendar(DateTime today) async {
    final all = await _transport.fetchCalendar();
    return filterTodayEvents(all, today);
  }

  @override
  Future<FearGreed?> getFearGreed() => _transport.fetchFearGreed();
}

final marketDataRepositoryProvider = Provider<MarketDataRepository>((ref) {
  return RepositoryMarketDataRepository(ref.watch(marketTransportProvider));
});
