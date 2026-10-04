/// Data export (P2-02): JSON and CSV exporters for the signed-in
/// user's trades.
///
/// Pure functions — no widgets, no database. Ownership is enforced at
/// this boundary: every trade must belong to [userId], so foreign
/// records can never serialize. Screenshot/image paths are never part
/// of the trade document (see TradeMapper), so they never appear in
/// export output (P2-02.06).
library;

import '../domain/trade.dart';

/// CSV columns, stable order (P2-02.02). No screenshot column.
const kExportFields = [
  'id', 'instrument', 'direction', 'accountType', 'entryPrice',
  'exitPrice', 'stopLoss', 'takeProfit', 'lotSize', 'profitLoss',
  'riskReward', 'openTime', 'closeTime', 'strategy', 'session',
  'confluence', 'emotion', 'mistakeTags', 'lessonLearned', 'notes',
  'inputMethod',
];

/// Serializes trades to a JSON-ready map (P2-02.01).
/// Datetimes as UTC ISO 8601 (P2-02.04). Throws [ArgumentError] on
/// any trade not owned by [userId] (P2-02.05).
Map<String, dynamic> exportTradesAsJson(List<Trade> trades,
    {String? userId}) {
  _assertOwned(trades, userId);
  return {
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'trades': [for (final t in trades) _tradeToJson(t)],
  };
}

Map<String, dynamic> _tradeToJson(Trade t) => {
      'id': t.id,
      'instrument': t.instrument,
      'direction': t.direction.name,
      'accountType': t.accountType.name,
      'entryPrice': t.entryPrice,
      'exitPrice': t.exitPrice,
      'stopLoss': t.stopLoss,
      'takeProfit': t.takeProfit,
      'lotSize': t.lotSize,
      'profitLoss': t.profitLoss,
      'riskReward': t.riskReward,
      'openTime': _iso(t.openTime),
      'closeTime': _iso(t.closeTime),
      'strategy': t.strategy,
      'session': t.session,
      'confluence': t.confluence,
      'emotion': t.emotion,
      'mistakeTags': t.mistakeTags,
      'lessonLearned': t.lessonLearned,
      'notes': t.notes,
      'inputMethod': t.inputMethod.name,
    };

/// Serializes trades to CSV (P2-02.02), one header row + one row per
/// trade. Comma/quote/newline values escaped per RFC 4180 (P2-02.03).
/// Datetimes as UTC ISO 8601 (P2-02.04). Throws [ArgumentError] on any
/// trade not owned by [userId] (P2-02.05).
String exportTradesAsCsv(List<Trade> trades, {String? userId}) {
  _assertOwned(trades, userId);
  final rows = <String>[
    kExportFields.join(','),
    for (final t in trades) _tradeToRow(t),
  ];
  return rows.join('\n');
}

String _tradeToRow(Trade t) => [
      t.id,
      t.instrument,
      t.direction.name,
      t.accountType.name,
      _num(t.entryPrice),
      _num(t.exitPrice),
      _num(t.stopLoss),
      _num(t.takeProfit),
      _num(t.lotSize),
      _num(t.profitLoss),
      _num(t.riskReward),
      _iso(t.openTime),
      _iso(t.closeTime),
      t.strategy,
      t.session,
      t.confluence.join('|'),
      t.emotion,
      t.mistakeTags.join('|'),
      t.lessonLearned,
      t.notes,
      t.inputMethod.name,
    ].map(_csvCell).join(',');

String _num(double? v) => v?.toString() ?? '';

String _iso(DateTime v) => v.toUtc().toIso8601String();

/// RFC 4180: quote a cell containing comma, quote, CR, or LF; inner
/// quotes doubled. Empty/null stays empty (unquoted).
String _csvCell(String? value) {
  if (value == null) return '';
  final needsQuotes =
      value.contains(',') || value.contains('"') || value.contains('\n') ||
      value.contains('\r');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

void _assertOwned(List<Trade> trades, String? userId) {
  if (userId == null) return;
  for (final t in trades) {
    if (t.userId != userId) {
      throw ArgumentError.value(
        t.id, 'trades', 'Trade ${t.id} belongs to ${t.userId}, '
        'expected $userId');
    }
  }
}
