/// ICT Kill Zones session clock (P2-05 revisi, DESIGN.md §5.14).
///
/// ICT Kill Zones in Eastern Time (America/New_York), DST-aware via
/// the `timezone` package (tz database) — never a hardcoded UTC offset:
///   Asia   20:00-00:00 ET
///   London 02:00-05:00 ET
///   NY AM  08:30-11:00 ET
///   NY PM  13:30-16:00 ET
/// Weekdays only (ET). Overlap = 2+ zones open at once (by definition
/// these windows never overlap; the flag stays for UI generality).
library;

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'market_data.dart';

bool _tzInitialized = false;

void _ensureTz() {
  if (_tzInitialized) return;
  tzdata.initializeTimeZones();
  _tzInitialized = true;
}

/// Open window (ET minutes-from-midnight) per kill zone.
const Map<IctKillZone, (int, int)> killZoneWindowsET = {
  IctKillZone.asia: (20 * 60, 24 * 60), // 20:00 → 00:00
  IctKillZone.london: (2 * 60, 5 * 60), // 02:00 → 05:00
  IctKillZone.nyAm: (8 * 60 + 30, 11 * 60), // 08:30 → 11:00
  IctKillZone.nyPm: (13 * 60 + 30, 16 * 60), // 13:30 → 16:00
};

bool _isOpen(IctKillZone zone, tz.TZDateTime et) {
  if (et.weekday > 5) return false; // Sat/Sun in New York
  final (start, end) = killZoneWindowsET[zone]!;
  final minutes = et.hour * 60 + et.minute;
  return minutes >= start && minutes < end;
}

/// Which ICT kill zones are open at [time] (any instant) and whether
/// two or more overlap. DST shifts (EST UTC-5 / EDT UTC-4) come from
/// the tz database automatically.
KillZoneState killZoneState(DateTime time) {
  _ensureTz();
  final et = tz.TZDateTime.from(time, tz.getLocation('America/New_York'));
  final active = IctKillZone.values.where((z) => _isOpen(z, et)).toList();
  return KillZoneState(active: active, isOverlap: active.length >= 2);
}
