import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/trades/domain/trade.dart';
import 'package:gumibook/features/trades/export/trade_exporter.dart';

import 'csv_parser_helper.dart';

void main() {
  test('CSV hostile values round-trip as one cell each', () {
    final t = Trade(
      id: 'tr1',
      userId: 'u1',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 2000,
      exitPrice: 2010,
      lotSize: 0.1,
      profitLoss: 100,
      openTime: DateTime.utc(2026, 9, 1, 10),
      closeTime: DateTime.utc(2026, 9, 1, 12),
      strategy: 'Scalp, London',
      emotion: 'FOMO "greedy" mode',
      lessonLearned: 'line one\nline two',
      notes: 'plain',
      inputMethod: TradeInputMethod.manual,
      mistakeTags: const ['late entry', 'no, stop'],
      confluence: const ['S+R', 'flag"pattern'],
    );
    final csv = exportTradesAsCsv([t], userId: 'u1');

    final rows = CsvParser().parse(csv);
    // header + exactly one data row despite embedded newline
    expect(rows.length, 2, reason: 'embedded newline must not split rows');
    expect(rows[0].length, kExportFields.length);
    expect(rows[1].length, kExportFields.length,
        reason: 'embedded commas must not shift columns');

    final idx = {for (var i = 0; i < kExportFields.length; i++) kExportFields[i]: i};
    expect(rows[1][idx['strategy']!], 'Scalp, London');
    expect(rows[1][idx['emotion']!], 'FOMO "greedy" mode');
    expect(rows[1][idx['lessonLearned']!], 'line one\nline two');
    expect(rows[1][idx['mistakeTags']!], 'late entry|no, stop');
  });

  test('export datetimes are ISO 8601 UTC', () {
    final t = Trade(
      id: 'tr1',
      userId: 'u1',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 2000,
      exitPrice: 2010,
      lotSize: 0.1,
      profitLoss: 100,
      openTime: DateTime.utc(2026, 9, 1, 10),
      closeTime: DateTime.utc(2026, 9, 1, 12),
      inputMethod: TradeInputMethod.manual,
    );
    final j = exportTradesAsJson([t], userId: 'u1');
    final open = j['trades'][0]['openTime'] as String;
    final close = j['trades'][0]['closeTime'] as String;
    expect(open, '2026-09-01T10:00:00.000Z');
    expect(close, '2026-09-01T12:00:00.000Z');
    expect(j['exportedAt'], endsWith('Z'));
  });

  test('foreign trade rejected (P2-02.05)', () {
    final t = Trade(
      id: 'trX',
      userId: 'attacker',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 1,
      exitPrice: 1,
      lotSize: 1,
      profitLoss: 0,
      openTime: DateTime.utc(2026),
      closeTime: DateTime.utc(2026),
      inputMethod: TradeInputMethod.manual,
    );
    expect(() => exportTradesAsCsv([t], userId: 'u1'),
        throwsA(isA<ArgumentError>()));
  });

  test('no screenshot/image path columns or values in export', () {
    final t = Trade(
      id: 'tr1',
      userId: 'u1',
      instrument: 'XAUUSD',
      direction: TradeDirection.buy,
      entryPrice: 2000,
      exitPrice: 2010,
      lotSize: 0.1,
      profitLoss: 100,
      openTime: DateTime.utc(2026, 9, 1, 10),
      closeTime: DateTime.utc(2026, 9, 1, 12),
      inputMethod: TradeInputMethod.manual,
    );
    final csv = exportTradesAsCsv([t], userId: 'u1').toLowerCase();
    final json = exportTradesAsJson([t], userId: 'u1').toString().toLowerCase();
    for (final needle in ['screenshot', '.png', '.jpg', '.jpeg', 'imagepath', 'screenshotpath']) {
      expect(csv.contains(needle), isFalse, reason: 'csv leaked $needle');
      expect(json.contains(needle), isFalse, reason: 'json leaked $needle');
    }
    // no OCR image path column in header
    expect(kExportFields.any((f) => f.toLowerCase().contains('image')), isFalse);
  });
}
