import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/market/market_data.dart';
import 'package:gumibook/features/market/market_session_clock.dart';

void main() {
  group('ICT kill zones (ET windows, DST-aware via tz database)', () {
    test('DST active (Sep): NY AM 08:30-11:00 EDT = 12:30-15:00 UTC', () {
      // 2026-09-15 is inside EDT (UTC-4). 14:00 UTC = 10:00 ET → NY AM.
      final s = killZoneState(DateTime.utc(2026, 9, 15, 14, 0));
      expect(s.active, [IctKillZone.nyAm]);
      expect(s.isOverlap, isFalse);
    });

    test('DST inactive (Jan): NY AM = 13:30-16:00 UTC — shift detected',
        () {
      // 2026-01-15 is EST (UTC-5). 14:00 UTC = 09:00 ET → NY AM still,
      // but the UTC boundary itself moved by one hour vs September.
      final s = killZoneState(DateTime.utc(2026, 1, 15, 14, 0));
      expect(s.active, [IctKillZone.nyAm]);

      // 17:00 UTC = 12:00 EST → no zone (NY AM ends 11:00 EST).
      final gap = killZoneState(DateTime.utc(2026, 1, 15, 17, 0));
      expect(gap.hasAnyActive, isFalse);

      // Same UTC instant in September (EDT) = 13:00 ET → still nothing
      // until 13:30 ET; proving windows track ET, not UTC.
      final sep = killZoneState(DateTime.utc(2026, 9, 15, 17, 0));
      expect(sep.hasAnyActive, isFalse);
    });

    test('London KZ 02:00-05:00 ET across DST', () {
      // EDT: 02:00 ET = 06:00 UTC.
      expect(killZoneState(DateTime.utc(2026, 9, 15, 6, 30)).active,
          [IctKillZone.london]);
      // EST: 02:00 ET = 07:00 UTC — 06:30 UTC (01:30 EST) must be empty.
      expect(killZoneState(DateTime.utc(2026, 1, 15, 6, 30)).hasAnyActive,
          isFalse);
      expect(killZoneState(DateTime.utc(2026, 1, 15, 7, 30)).active,
          [IctKillZone.london]);
    });

    test('Asia KZ 20:00-00:00 ET', () {
      // EDT: 20:00 ET = 00:00 UTC next day → check 21:00 ET = 01:00 UTC+1d.
      expect(killZoneState(DateTime.utc(2026, 9, 16, 1, 0)).active,
          [IctKillZone.asia]);
      // 00:00 ET (04:00 UTC EDT) = outside Asia (ends 00:00), before London.
      expect(killZoneState(DateTime.utc(2026, 9, 15, 4, 0)).hasAnyActive,
          isFalse);
    });

    test('NY PM KZ 13:30-16:00 ET', () {
      // EDT: 14:30 ET = 18:30 UTC.
      expect(killZoneState(DateTime.utc(2026, 9, 15, 18, 30)).active,
          [IctKillZone.nyPm]);
      // 16:00 ET = 20:00 UTC → closed.
      expect(killZoneState(DateTime.utc(2026, 9, 15, 20, 0)).hasAnyActive,
          isFalse);
    });

    test('weekend in New York: all zones closed', () {
      // Saturday 2026-09-19 14:00 UTC.
      expect(killZoneState(DateTime.utc(2026, 9, 19, 14, 0)).hasAnyActive,
          isFalse);
      // Friday late NY PM end (16:00 ET Fri = 20:00 UTC) → closed.
      expect(killZoneState(DateTime.utc(2026, 9, 18, 20, 30)).hasAnyActive,
          isFalse);
    });

    test('kill zone windows documented', () {
      expect(killZoneWindowsET[IctKillZone.asia], (1200, 1440));
      expect(killZoneWindowsET[IctKillZone.london], (120, 300));
      expect(killZoneWindowsET[IctKillZone.nyAm], (510, 660));
      expect(killZoneWindowsET[IctKillZone.nyPm], (810, 960));
    });
  });
}
