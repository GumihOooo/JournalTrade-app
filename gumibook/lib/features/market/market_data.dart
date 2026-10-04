/// Market feature domain (P2-05, ARCHITECTURE.md §14, DESIGN.md §5.14).
///
/// Pure data classes only — parsing lives in market_parsers.dart,
/// network I/O in market_data_repository.dart.
library;

/// One symbol quote. `price == null` means unavailable (provider error
/// or no data for that symbol) — the UI renders the unavailable state.
class Quote {
  const Quote({
    required this.symbol,
    required this.price,
    this.change,
    this.changePercent,
    this.previousClose,
  });

  final String symbol;
  final double? price;
  final double? change;
  final double? changePercent;
  final double? previousClose;

  bool get isAvailable => price != null;
}

/// One business-news item (Sugra `/news/latest`). Sentiment comes from
/// the GDELT tone chart attached to the whole news payload, so every
/// item in a bundle shares the same label.
class MarketNews {
  const MarketNews({
    required this.title,
    this.snippet,
    this.source,
    this.publishedAt,
    this.link,
    this.sentiment,
  });

  final String title;
  final String? snippet;
  final String? source;
  final DateTime? publishedAt;
  final String? link;

  /// From the GDELT tone chart (P2-05.09); null when the upstream was
  /// throttled or returned no buckets.
  final Sentiment? sentiment;

  MarketNews withSentiment(Sentiment? s) => MarketNews(
        title: title,
        snippet: snippet,
        source: source,
        publishedAt: publishedAt,
        link: link,
        sentiment: s,
      );
}

/// News section payload: items + the shared GDELT sentiment (P2-05.09).
class NewsBundle {
  const NewsBundle({required this.news, this.sentiment});

  final List<MarketNews> news;
  final Sentiment? sentiment;
}

/// One economic-calendar event (LSE). Today-only after filtering.
class EconomicEvent {
  const EconomicEvent({
    required this.name,
    this.datetime,
    this.country,
    this.impact,
    this.actual,
    this.forecast,
    this.previous,
  });

  final String name;
  final DateTime? datetime;
  final String? country;
  final String? impact;
  final String? actual;
  final String? forecast;
  final String? previous;
}

/// Fear & Greed index snapshot (feargreedchart.com, no key).
class FearGreed {
  const FearGreed({
    required this.value,
    required this.rating,
    required this.updatedAt,
  });

  /// 0..100.
  final int value;
  final String rating;
  final DateTime updatedAt;
}

/// Sentiment label for the news section (GDELT tone chart via Sugra).
enum SentimentLabel { positive, negative, neutral }

class Sentiment {
  const Sentiment({required this.label, this.confidence, this.reason});

  final SentimentLabel label;
  final double? confidence;
  final String? reason;
}

/// ICT Kill Zone (P2-05 revisi) — Eastern Time windows, DST-aware.
enum IctKillZone { asia, london, nyAm, nyPm }

/// Result of the kill-zone clock: which zones are open right now and
/// whether (if ever) two overlap.
class KillZoneState {
  const KillZoneState({
    required this.active,
    required this.isOverlap,
  });

  final List<IctKillZone> active;
  final bool isOverlap;

  bool get hasAnyActive => active.isNotEmpty;
}

/// Section-level async state (DESIGN.md §5.14): loading, available,
/// no data, unavailable, error. Section failures never block others.
enum SectionStatus { loading, available, noData, unavailable, error }

class SectionState<T> {
  const SectionState._(this.status, this.data, this.message);

  const SectionState.loading() : this._(SectionStatus.loading, null, null);
  const SectionState.noData() : this._(SectionStatus.noData, null, null);
  const SectionState.unavailable([String? message])
      : this._(SectionStatus.unavailable, null, message);
  const SectionState.error([String? message])
      : this._(SectionStatus.error, null, message);
  const SectionState.available(T data)
      : this._(SectionStatus.available, data, null);

  final SectionStatus status;
  final T? data;
  final String? message;

  bool get isLoading => status == SectionStatus.loading;
  bool get hasData => status == SectionStatus.available && data != null;
}
