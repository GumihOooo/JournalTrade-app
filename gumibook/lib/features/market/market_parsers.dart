/// Market payload parsers (P2-05). Pure functions — no network, no
/// widgets. Every parser tolerates malformed/empty input by returning
/// an empty result or null, never throwing: provider drift must not
/// crash a section.
library;

import 'market_data.dart';

List<Map<String, dynamic>> _asMaps(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
}

double? _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// Gateway `{ quotes: [...] }` → [Quote] list. An error row (missing
/// price) becomes a Quote with null price so the UI shows unavailable.
List<Quote> parseQuotes(dynamic json) {
  if (json is! Map) return const [];
  final rows = _asMaps((json.cast<String, dynamic>())['quotes']);
  return [
    for (final r in rows)
      if (r['symbol'] is String)
        Quote(
          symbol: r['symbol'] as String,
          price: _asDouble(r['price']),
          change: _asDouble(r['change']),
          changePercent: _asDouble(r['changePercent']),
          previousClose: _asDouble(r['previousClose']),
        ),
  ];
}

/// Sugra market-news payload (`{ news, sentiment }`) → [NewsBundle].
/// Sugra items already carry title/description/link/published/source;
/// the GDELT tone chart is parsed once and shared by every item.
NewsBundle parseNewsBundle(dynamic json) {
  if (json is! Map) return const NewsBundle(news: []);
  final map = json.cast<String, dynamic>();
  final sentiment = parseGdeltTone(map['sentiment']);
  final rows = _asMaps(map['news']);
  return NewsBundle(
    sentiment: sentiment,
    news: [
      for (final r in rows)
        if (r['title'] is String)
          MarketNews(
            title: r['title'] as String,
            snippet: r['snippet'] as String?,
            source: r['source'] as String?,
            publishedAt: DateTime.tryParse(r['publishedAt'] as String? ?? ''),
            link: r['link'] as String?,
            sentiment: sentiment,
          ),
    ],
  );
}

/// Gateway calendar payload → [EconomicEvent] list. Accepts a bare list
/// or `{ events: [...] }`. Unparseable rows keep a null datetime.
///
/// LSE `datetime` is a NAIVE UTC string (verified live: US Empire State
/// 08:30 ET arrives as `12:30 PM`, DE ZEW 10:00 CET as `09:00 AM`).
/// A bare `2026-09-15 04:30:00` would parse as LOCAL time and shift the
/// event day for every non-UTC user — append `Z` first so it is UTC,
/// then [filterTodayEvents] converts to the user's local day.
DateTime? _parseUtcDateTime(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final withZone = s.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(s)
      ? s
      : '${s}Z';
  return DateTime.tryParse(withZone)?.toUtc();
}

List<EconomicEvent> parseCalendar(dynamic json) {
  final rows = json is Map
      ? _asMaps((json.cast<String, dynamic>())['events'])
      : _asMaps(json);
  return [
    for (final r in rows)
      EconomicEvent(
        name: (r['event'] ?? r['name'] ?? r['title'] ?? '') as String,
        datetime: _parseUtcDateTime(
            (r['datetime'] ?? r['date'] ?? '') as String? ?? ''),
        country: (r['country'] ?? r['currency']) as String?,
        impact: r['impact'] as String?,
        actual: r['actual'] as String?,
        forecast: r['forecast'] as String?,
        previous: r['previous'] as String?,
      ),
  ];
}

/// Keep only events whose LOCAL calendar day equals [today]'s local day
/// (P2-05 revisi: "today" in the user's timezone, not UTC). Events
/// without a datetime are dropped (can't be today-verified).
List<EconomicEvent> filterTodayEvents(
    List<EconomicEvent> events, DateTime today) {
  final d = today.toLocal();
  return events.where((e) {
    final dt = e.datetime;
    if (dt == null) return false;
    final l = dt.toLocal();
    return l.year == d.year && l.month == d.month && l.day == d.day;
  }).toList();
}

/// feargreedchart.com `?action=all` → [FearGreed] or null when absent.
FearGreed? parseFearGreed(dynamic json) {
  if (json is! Map) return null;
  final map = json.cast<String, dynamic>();
  final score = map['score'];
  if (score is! Map) return null;
  final value = (score['score'] as num?)?.toInt();
  if (value == null) return null;
  final ts = map['ts'];
  final updatedAt = ts is num
      ? DateTime.fromMillisecondsSinceEpoch(ts.toInt(), isUtc: true)
      : DateTime.now().toUtc();
  return FearGreed(
    value: value,
    rating: fearGreedRating(value),
    updatedAt: updatedAt,
  );
}

/// CNN-standard Fear & Greed tiers. Out-of-range values are unknown.
String fearGreedRating(int value) {
  if (value < 0 || value > 100) return 'unknown';
  if (value <= 24) return 'extreme fear';
  if (value <= 44) return 'fear';
  if (value <= 54) return 'neutral';
  if (value <= 74) return 'greed';
  return 'extreme greed';
}

/// GDELT tone chart (Sugra `/gdelt/sentiment` → `tonechart`) →
/// [Sentiment], or null when absent/throttled. Each bucket carries a
/// tone `bin` and an article `count`; the busiest bucket wins.
Sentiment? parseGdeltTone(dynamic json) {
  if (json is! Map) return null;
  final map = json.cast<String, dynamic>();
  final tone = map['tonechart'];
  if (tone is! List) return null;
  final rows = _asMaps(tone);
  if (rows.isEmpty) return null;
  double bestCount = -1;
  double? bestBin;
  for (final r in rows) {
    final count = _asDouble(r['count']) ?? 0;
    final bin = _asDouble(r['bin']);
    if (bin == null) continue;
    if (count > bestCount) {
      bestCount = count;
      bestBin = bin;
    }
  }
  if (bestBin == null) return null;
  final label = bestBin > 2.5
      ? SentimentLabel.positive
      : (bestBin < 2.5 ? SentimentLabel.negative : SentimentLabel.neutral);
  return Sentiment(label: label, confidence: bestCount);
}

/// Watchlist instrument → official TradingView embed symbol (the chart
/// is a TradingView Widget, not a manual render). Every symbol below
/// verified against TradingView symbol search on 2026-09-13 (raw probe:
/// CBOT:YM1! and TVC:USOIL are INVALID; CBOT_MINI:YM1! and NYMEX:CL1!
/// are the valid ones). Broker-style aliases (NAS100/DJ30/SP500/US30)
/// stay mapped for watchlists seeded before the key rename.
String? instrumentToTradingViewSymbol(String instrument) {
  final i = instrument.trim().toUpperCase();
  const map = {
    'NAS100': 'CME_MINI:NQ1!',
    'NQ': 'CME_MINI:NQ1!',
    'SP500': 'CME_MINI:ES1!',
    'SPX500': 'SP:SPX',
    'ES': 'CME_MINI:ES1!',
    'DJ30': 'CBOT_MINI:YM1!',
    'US30': 'CBOT_MINI:YM1!',
    'YM': 'CBOT_MINI:YM1!',
    'XAUUSD': 'SAXO:XAUUSD',
    'XAGUSD': 'SAXO:XAGUSD',
    'EURUSD': 'SAXO:EURUSD',
    'GBPUSD': 'SAXO:GBPUSD',
    'USDJPY': 'SAXO:USDJPY',
    'BTCUSD': 'COINBASE:BTCUSD',
    'DXY': 'TVC:DXY',
    'US10Y': 'TVC:US10Y',
    'USOIL': 'NYMEX:CL1!',
  };
  return map[i];
}
