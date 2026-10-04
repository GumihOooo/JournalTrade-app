/// MT5 History row parser (P1-04, ARCHITECTURE.md §12).
///
/// Input: OCR text blocks (one cropped trade row, possibly split
/// across blocks). Output: `Mt5Extraction` — only explicitly visible
/// values; everything else stays null. No guessing, no profit-based
/// direction inference, no SL/TP calculation.
library;

import '../../trades/domain/trade.dart';
import 'mt5_extraction.dart';

typedef _Lex =
    ({List<String> bare, List<({String label, String value})> labeled});

/// Parses the visible text of one MT5 History trade row.
///
/// Recognized MT5 column values (order-independent tokens):
/// - symbol: `XAUUSD`-style uppercase word (6+ letters/digits)
/// - type: `buy` / `sell`
/// - volume: decimal like `0.10`
/// - times: `2026.09.05 14:32:11` or `2026-09-05 14:32`
/// - prices: plain decimals (entry/exit via price-pair heuristics)
/// - `s/l: x` / `t/p: x` prefixed values when OCR kept the labels
Mt5Extraction parseMt5TradeRow(List<String> blocks) {
  final text = blocks
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .join(' ');
  final tokens = _lex(text);

  return Mt5Extraction(
    instrument: _symbol(tokens),
    direction: _direction(tokens),
    lotSize: _volume(tokens),
    openTime: _time(tokens, first: true),
    closeTime: _time(tokens, first: false),
    entryPrice: _price(tokens, first: true),
    exitPrice: _price(tokens, first: false),
    stopLoss: _labeled(tokens, const {'s/l', 'sl'}),
    takeProfit: _labeled(tokens, const {'t/p', 'tp'}),
    profitLoss: _profit(tokens),
    commission: _labeled(tokens, const {'commission'}),
    swap: _labeled(tokens, const {'swap'}),
  );
}

// ---------------------------------------------------------------------------
// Lexer: labeled values keep their label attached (`sl` below);
// everything else becomes bare word/number/time tokens in order.
// ---------------------------------------------------------------------------

_Lex _lex(String text) {
  var raw = text
      .replaceAll(RegExp(r'[\n\r]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  // OCR splits `2026.09.05 14:32:11` across tokens — merge a date
  // with its clock so `_time` sees one datetime, not date + noise.
  final merged = <String>[];
  for (var i = 0; i < raw.length; i++) {
    if (_dateOnlyRe.hasMatch(raw[i]) &&
        i + 1 < raw.length &&
        _clockRe.hasMatch(raw[i + 1])) {
      merged.add('${raw[i]} ${raw[i + 1]}');
      i++;
    } else {
      merged.add(raw[i]);
    }
  }
  raw = merged;
  final bare = <String>[];
  final labeled = <({String label, String value})>[];
  for (var i = 0; i < raw.length; i++) {
    final t = raw[i].toLowerCase();
    if (_labels.contains(t) && i + 1 < raw.length) {
      labeled.add((label: t, value: raw[i + 1]));
      i++; // consume the value
    } else {
      bare.add(raw[i]);
    }
  }
  return (bare: bare, labeled: labeled);
}

final _dateOnlyRe = RegExp(r'^\d{4}[.\-/]\d{2}[.\-/]\d{2}$');
final _clockRe = RegExp(r'^\d{2}:\d{2}(?::\d{2})?$');

const _labels = {'s/l', 'sl', 't/p', 'tp', 'commission', 'swap'};

// ---------------------------------------------------------------------------
// Field matchers
// ---------------------------------------------------------------------------

final _symbolRe = RegExp(r'^[A-Z][A-Z0-9]{2,11}$');
final _decimalRe = RegExp(r'^-?\d+(?:[.,]\d+)?$');
final _timeRe =
    RegExp(r'^(\d{4})[.\-/](\d{2})[.\-/](\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$');

ExtractedField<String> _symbol(_Lex lex) {
  for (final t in lex.bare) {
    if (_symbolRe.hasMatch(t) && !_words.containsKey(t.toLowerCase())) {
      return ExtractedField(t, t);
    }
  }
  return const ExtractedField(null, null);
}

const _words = {
  'buy': 1,
  'sell': 1,
  'balance': 1,
  'deposit': 1,
  'withdrawal': 1,
  'credit': 1,
};

ExtractedField<TradeDirection> _direction(_Lex lex) {
  for (final t in lex.bare) {
    switch (t.toLowerCase()) {
      case 'buy':
        return ExtractedField(TradeDirection.buy, t);
      case 'sell':
        return ExtractedField(TradeDirection.sell, t);
    }
  }
  return const ExtractedField(null, null);
}

/// Volume: the first small decimal (<= 1000) with at most 2 decimal
/// places — MT5 lots. Prices carry more digits; profits are not
/// guaranteed to, so order + decimals carry the distinction.
ExtractedField<double> _volume(_Lex lex) {
  for (final t in lex.bare) {
    final v = _num(t);
    if (v != null && v > 0 && v < 1000) {
      final digits = _decimals(t);
      if (digits <= 2) return ExtractedField(v, t); // 0.10-style lot
    }
  }
  return const ExtractedField(null, null);
}

/// Prices: bare decimals that are not times, excluding the volume
/// token. First candidate = open price, second = close price (MT5
/// column order).
ExtractedField<double> _price(_Lex lex, {required bool first}) {
  final volume = _volume(lex).rawText;
  final candidates = <(double, String)>[];
  for (final t in lex.bare) {
    if (_timeRe.hasMatch(t) || t == volume) continue;
    final v = _num(t);
    if (v == null) continue;
    candidates.add((v, t));
  }
  if (candidates.length < 2) return const ExtractedField(null, null);
  final (v, t) = first ? candidates.first : candidates[1];
  return ExtractedField(v, t);
}

ExtractedField<double> _profit(_Lex lex) {
  // MT5 shows profit as the LAST signed money value in the row
  // (after commission/swap labels were stripped by the lexer and
  // volume/prices/times are excluded).
  final volume = _volume(lex).rawText;
  final bare = lex.bare
      .where((t) => !_timeRe.hasMatch(t) && t != volume && _num(t) != null)
      .toList();
  for (final t in bare.reversed) {
    final v = _num(t)!;
    if (v < 0) return ExtractedField(v, t); // explicit loss: unambiguous
  }
  // No negative value: fall back to the last bare money number, but
  // only when its decimals look like money (2 places) — never guess
  // a sign.
  for (final t in bare.reversed) {
    if (_decimals(t) == 2) return ExtractedField(_num(t)!, t);
  }
  return const ExtractedField(null, null);
}

ExtractedField<double>? _labeled(_Lex lex, Set<String> labels) {
  for (final e in lex.labeled) {
    if (labels.contains(e.label)) {
      final v = _num(e.value);
      if (v != null) return ExtractedField(v, e.value);
    }
  }
  return null;
}

ExtractedField<DateTime> _time(_Lex lex, {required bool first}) {
  final found = <(DateTime, String)>[];
  for (final t in lex.bare) {
    final m = _timeRe.firstMatch(t);
    if (m == null) continue;
    final dt = DateTime(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
      m[4] != null ? int.parse(m[4]!) : 0,
      m[5] != null ? int.parse(m[5]!) : 0,
      m[6] != null ? int.parse(m[6]!) : 0,
    );
    found.add((dt, t));
  }
  if (found.length < 2) return const ExtractedField(null, null);
  final (dt, t) = first ? found.first : found[1];
  return ExtractedField(dt, t);
}

double? _num(String token) {
  if (!_decimalRe.hasMatch(token)) return null;
  return double.tryParse(token.replaceAll(',', '.'));
}

int _decimals(String token) {
  final i = token.indexOf(RegExp(r'[.,]'));
  return i < 0 ? 0 : token.length - i - 1;
}
