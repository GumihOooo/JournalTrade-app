import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/market/market_data.dart';
import 'package:gumibook/features/market/market_parsers.dart';
import 'package:gumibook/features/watchlist/default_watchlist.dart';

void main() {
  group('parseQuotes', () {
    test('tolerant quote parsing from gateway format', () {
      final json = {
        'quotes': [
          {
            'symbol': 'EURUSD=X',
            'price': 1.0850,
            'change': 0.0025,
            'changePercent': 0.23,
          },
          // Error row preserved as quote with null price (unavailable).
          {'symbol': 'XYZ=X', 'error': 'HTTP 404'},
        ]
      };
      final quotes = parseQuotes(json);
      expect(quotes, hasLength(2));
      expect(quotes[0].symbol, 'EURUSD=X');
      expect(quotes[0].price, 1.0850);
      expect(quotes[0].changePercent, 0.23);
      expect(quotes[1].symbol, 'XYZ=X');
      expect(quotes[1].price, isNull);
    });

    test('malformed/empty input returns empty list, never throws', () {
      expect(parseQuotes(null), isEmpty);
      expect(parseQuotes({}), isEmpty);
      expect(parseQuotes({'quotes': 'not-a-list'}), isEmpty);
    });
  });

  group('parseNewsBundle', () {
    test('tolerant news parsing', () {
      final json = {
        'news': [
          {
            'title': 'ECB Holds Rates Steady',
            'snippet': 'Inflation continues to ease...',
            'source': 'Reuters',
            'publishedAt': '2026-09-12T10:00:00Z',
            'link': 'https://example.com/story',
          },
          {'title': 'Dollar Rallies'}, // minimal fields
        ]
      };
      final bundle = parseNewsBundle(json);
      expect(bundle.news, hasLength(2));
      expect(bundle.news[0].title, 'ECB Holds Rates Steady');
      expect(bundle.news[0].source, 'Reuters');
      expect(bundle.news[0].snippet, startsWith('Inflation'));
      expect(bundle.news[0].publishedAt, isNotNull);
      expect(bundle.news[1].title, 'Dollar Rallies');
      expect(bundle.news[1].source, isNull);
    });

    test('malformed input returns empty list', () {
      expect(parseNewsBundle(null).news, isEmpty);
      expect(parseNewsBundle({}).news, isEmpty);
    });
  });

  group('parseCalendar + filterTodayEvents', () {
    test('parses events and filters for today (local timezone)', () {
      final events = [
        {
          'event': 'US CPI MoM',
          'datetime': '2026-09-12T12:30:00Z',
          'country': 'USD',
          'impact': 'HIGH',
          'actual': '0.2%',
          'forecast': '0.2%',
          'previous': '0.1%',
        },
        {
          'event': 'ECB Rate Decision',
          'datetime': '2026-09-11T12:15:00Z', // yesterday
          'country': 'EUR',
          'impact': 'HIGH',
        },
        {
          'event': 'Tomorrow Event',
          'datetime': '2026-09-13T09:00:00Z', // tomorrow
          'country': 'GBP',
        },
        {'event': 'Invalid Date Event', 'datetime': 'bad-date'},
      ];

      final parsed = parseCalendar({'events': events});
      expect(parsed, hasLength(4));

      // User's local "today" = 2026-09-12; local filtering (P2-05 revisi).
      final today = DateTime(2026, 9, 12, 15, 0);
      final filtered = filterTodayEvents(parsed, today);
      expect(filtered, hasLength(1));
      expect(filtered.single.name, 'US CPI MoM');
      expect(filtered.single.country, 'USD');
      expect(filtered.single.impact, 'HIGH');
    });

    test('parses bare list as well as wrapped', () {
      final bare = [
        {'event': 'A', 'date': '2026-09-12T10:00:00Z'}
      ];
      expect(parseCalendar(bare), hasLength(1));
    });

    // LSE `datetime` is UTC-naive (live: US 08:30 ET -> 12:30). Parsing
    // it as local time would shift the event day for non-UTC users.
    test('naive LSE datetime parses as UTC, not local', () {
      final parsed = parseCalendar({
        'events': [
          {'event': 'JP Tertiary', 'datetime': '2026-09-15 04:30:00'},
          {'event': 'Already UTC', 'datetime': '2026-09-15T04:30:00Z'},
        ],
      });
      expect(parsed[0].datetime, DateTime.utc(2026, 9, 15, 4, 30));
      expect(parsed[1].datetime, DateTime.utc(2026, 9, 15, 4, 30));
    });

    // "Today" is INJECTED — two different injected days over the same
    // event set must yield different results. Datetimes are anchored to
    // local noon (converted to UTC) so the test holds in any host zone.
    test('filterTodayEvents follows the injected date', () {
      final noon = DateTime.now();
      final base = DateTime(noon.year, noon.month, noon.day, 12, 0);
      final events = [
        EconomicEvent(name: 'yesterday', datetime: base.subtract(const Duration(days: 1)).toUtc()),
        EconomicEvent(name: 'today', datetime: base.toUtc()),
        EconomicEvent(name: 'tomorrow', datetime: base.add(const Duration(days: 1)).toUtc()),
      ];

      final todayOnly = filterTodayEvents(events, base);
      expect(todayOnly.map((e) => e.name), ['today']);

      final yesterdayOnly = filterTodayEvents(events, base.subtract(const Duration(days: 1)));
      expect(yesterdayOnly.map((e) => e.name), ['yesterday']);

      final tomorrowOnly = filterTodayEvents(events, base.add(const Duration(days: 1)));
      expect(tomorrowOnly.map((e) => e.name), ['tomorrow']);
    });

    // Regression guard for the reported hardcode: a fixed event set
    // filtered by a date weeks away must return nothing, not the
    // original "today" batch.
    test('a far-away injected date matches nothing', () {
      final now = DateTime.now();
      final events = [
        EconomicEvent(
          name: 'old event',
          datetime: DateTime(now.year, now.month, now.day, 12).toUtc(),
        ),
      ];
      final far = DateTime(now.year, now.month, now.day).add(const Duration(days: 400));
      expect(filterTodayEvents(events, far), isEmpty);
    });
  });

  group('parseFearGreed + fearGreedRating', () {
    test('parses score and rating correctly', () {
      final json = {
        'score': {
          'score': 57,
          'components': [
            {'name': 'VOLATILITY', 'val': 46},
          ],
        },
        'ts': 1789273427000,
      };
      final fg = parseFearGreed(json);
      expect(fg, isNotNull);
      expect(fg!.value, 57);
      expect(fg.rating, 'greed');
      expect(fg.updatedAt.millisecondsSinceEpoch, 1789273427000);
    });

    test('missing score returns null', () {
      expect(parseFearGreed({}), isNull);
      expect(parseFearGreed(null), isNull);
    });

    test('rating tiers match CNN standard thresholds', () {
      expect(fearGreedRating(0), 'extreme fear');
      expect(fearGreedRating(24), 'extreme fear');
      expect(fearGreedRating(25), 'fear');
      expect(fearGreedRating(44), 'fear');
      expect(fearGreedRating(45), 'neutral');
      expect(fearGreedRating(54), 'neutral');
      expect(fearGreedRating(55), 'greed');
      expect(fearGreedRating(74), 'greed');
      expect(fearGreedRating(75), 'extreme greed');
      expect(fearGreedRating(100), 'extreme greed');
      expect(fearGreedRating(-5), 'unknown');
      expect(fearGreedRating(105), 'unknown');
    });
  });

  group('parseGdeltTone', () {
    test('busiest tone bucket wins', () {
      final json = {
        'tonechart': [
          {'bin': -5.0, 'count': 2},
          {'bin': 5.0, 'count': 9},
          {'bin': 0.0, 'count': 4},
        ]
      };
      final res = parseGdeltTone(json);
      expect(res, isNotNull);
      expect(res!.label, SentimentLabel.positive);
      expect(res.confidence, 9);
    });

    test('negative tone bucket yields negative label', () {
      final json = {
        'tonechart': [
          {'bin': -6.0, 'count': 11},
          {'bin': 4.0, 'count': 3},
        ]
      };
      expect(parseGdeltTone(json)!.label, SentimentLabel.negative);
    });

    test('absent / throttled tone chart returns null', () {
      expect(parseGdeltTone({'detail': {'error': 'upstream_rate_limited'}}),
          isNull);
      expect(parseGdeltTone(null), isNull);
      expect(parseGdeltTone({'tonechart': []}), isNull);
    });
  });

  group('symbol mappings', () {
    test('instrumentToTradingViewSymbol — verified 2026-09-13', () {
      // Verified via TradingView symbol search (raw probe): every symbol
      // below returned 200; CBOT:YM1!/TVC:USOIL were 404 and replaced.
      expect(instrumentToTradingViewSymbol('NAS100'), 'CME_MINI:NQ1!');
      expect(instrumentToTradingViewSymbol('NQ'), 'CME_MINI:NQ1!');
      expect(instrumentToTradingViewSymbol('SP500'), 'CME_MINI:ES1!');
      expect(instrumentToTradingViewSymbol('ES'), 'CME_MINI:ES1!');
      expect(instrumentToTradingViewSymbol('DJ30'), 'CBOT_MINI:YM1!');
      expect(instrumentToTradingViewSymbol('YM'), 'CBOT_MINI:YM1!');
      expect(instrumentToTradingViewSymbol('XAUUSD'), 'SAXO:XAUUSD');
      expect(instrumentToTradingViewSymbol('EURUSD'), 'SAXO:EURUSD');
      expect(instrumentToTradingViewSymbol('GBPUSD'), 'SAXO:GBPUSD');
      expect(instrumentToTradingViewSymbol('USDJPY'), 'SAXO:USDJPY');
      expect(instrumentToTradingViewSymbol('BTCUSD'), 'COINBASE:BTCUSD');
      expect(instrumentToTradingViewSymbol('DXY'), 'TVC:DXY');
      expect(instrumentToTradingViewSymbol('US10Y'), 'TVC:US10Y');
      expect(instrumentToTradingViewSymbol('USOIL'), 'NYMEX:CL1!');
      expect(instrumentToTradingViewSymbol('UNKNOWN'), isNull);
    });

    test('default watchlist covers all mapped TV instruments', () {
      for (final instrument in defaultWatchlistInstruments) {
        expect(instrumentToTradingViewSymbol(instrument), isNotNull,
            reason: 'missing TV symbol for $instrument');
      }
    });
  });
}
