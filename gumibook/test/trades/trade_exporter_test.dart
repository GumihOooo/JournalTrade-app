import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gumibook/features/trades/domain/trade.dart';
import 'package:gumibook/features/trades/export/trade_exporter.dart';

import 'csv_parser_helper.dart';

Trade _t({
  String id = 't1',
  String userId = 'u1',
  String instrument = 'XAUUSD',
  String? strategy = 'Breakout',
  List<String> mistakeTags = const ['revenge'],
  String? notes = 'clean entry',
  DateTime? openTime,
}) =>
    Trade(
      id: id,
      userId: userId,
      instrument: instrument,
      direction: TradeDirection.sell,
      entryPrice: 2345.67,
      exitPrice: 2330.0,
      stopLoss: 2350.0,
      takeProfit: 2300.0,
      lotSize: 0.1,
      profitLoss: 156.7,
      riskReward: 2.9,
      openTime: openTime ?? DateTime.utc(2026, 9, 10, 8, 30),
      closeTime: DateTime.utc(2026, 9, 10, 12, 5, 3),
      strategy: strategy,
      session: 'london',
      confluence: const ['S/R', 'FVG'],
      emotion: 'calm',
      mistakeTags: mistakeTags,
      lessonLearned: 'follow plan',
      notes: notes,
      inputMethod: TradeInputMethod.ocr,
    );

void main() {
  // P2-02.01: JSON exporter
  test('P2-02.01 exportJson produces keyed map with all Trade fields',
      () {
    final json = exportTradesAsJson([_t()]);
    expect(json, isA<Map<String, dynamic>>());
    final trades = json['trades'] as List;
    expect(trades, hasLength(1));
    final t = trades.first as Map<String, dynamic>;
    expect(t['id'], 't1');
    expect(t['instrument'], 'XAUUSD');
    expect(t['direction'], 'sell');
    expect(t['entryPrice'], 2345.67);
    expect(t['confluence'], ['S/R', 'FVG']);
    expect(t['mistakeTags'], ['revenge']);
    expect(t['inputMethod'], 'ocr');
  });

  test('P2-02.01 exportJson empty list yields empty trades array', () {
    expect((exportTradesAsJson([])['trades'] as List), isEmpty);
  });

  // P2-02.04: ISO 8601 datetimes, Z suffix, full second precision
  test('P2-02.04 exportJson datetimes are UTC ISO 8601', () {
    final t = (exportTradesAsJson([_t()])['trades'] as List)
        .first as Map<String, dynamic>;
    expect(t['openTime'], '2026-09-10T08:30:00.000Z');
    expect(t['closeTime'], '2026-09-10T12:05:03.000Z');
    expect(DateTime.parse(t['openTime'] as String).isUtc, true);
  });

  test('P2-02.04 exportJson local DateTime converted to UTC', () {
    final local = DateTime(2026, 9, 10, 8, 30); // local zone
    final t = (exportTradesAsJson([_t(openTime: local)])['trades'] as List)
        .first as Map<String, dynamic>;
    expect(t['openTime'], local.toUtc().toIso8601String());
  });

  test('P2-02.04 exportJson null optional fields serialize as null', () {
    final t = (exportTradesAsJson([_t(strategy: null, notes: null)])
            ['trades'] as List)
        .first as Map<String, dynamic>;
    expect(t['strategy'], isNull);
    expect(t['notes'], isNull);
    expect(t.containsKey('strategy'), true);
  });

  // P2-02.02: CSV exporter
  test('P2-02.02 exportTradesAsCsv header row matches field list', () {
    final csv = exportTradesAsCsv([_t()]);
    final lines = const LineSplitter().convert(csv);
    expect(lines.first,
        'id,instrument,direction,accountType,entryPrice,exitPrice,'
        'stopLoss,takeProfit,lotSize,profitLoss,riskReward,openTime,'
        'closeTime,strategy,session,confluence,emotion,mistakeTags,'
        'lessonLearned,notes,inputMethod');
    expect(lines, hasLength(2));
  });

  test('P2-02.02 exportTradesAsCsv empty list yields header only', () {
    final csv = exportTradesAsCsv([]);
    expect(const LineSplitter().convert(csv), hasLength(1));
  });

  test('P2-02.02 CSV row carries values in header order', () {
    final row = const LineSplitter()
        .convert(exportTradesAsCsv([_t()]))[1]
        .split(',');
    expect(row[0], 't1');
    expect(row[1], 'XAUUSD');
    expect(row[2], 'sell');
    expect(row[11], '2026-09-10T08:30:00.000Z');
    expect(row[15], 'S/R|FVG');
    expect(row[20], 'ocr');
  });

  // P2-02.03: CSV escaping
  test('P2-02.03 value with comma gets quoted', () {
    final csv = exportTradesAsCsv(
        [_t(strategy: 'Breakout, continuation')]);
    expect(csv, contains('"Breakout, continuation"'));
  });

  test('P2-02.03 value with double quote doubles it and quotes field',
      () {
    final csv = exportTradesAsCsv([_t(notes: 'said "hold" today')]);
    expect(csv, contains('"said ""hold"" today"'));
  });

  test('P2-02.03 value with newline gets quoted and stays one logical row',
      () {
    final csv = exportTradesAsCsv(
        [_t(notes: 'line one\nline two')]);
    final parsed = CsvParser().parse(csv);
    expect(parsed, hasLength(2));
    expect(parsed[1][19], 'line one\nline two');
  });

  test('P2-02.03 plain values need no quotes', () {
    final csv = exportTradesAsCsv([_t()]);
    expect(csv, isNot(contains('"')));
  });

  // P2-02.05: user scoping at the exporter boundary
  test('P2-02.05 exportTradesAsCsv rejects trades from other users',
      () {
    expect(
      () => exportTradesAsCsv([_t(userId: 'someone-else')], userId: 'u1'),
      throwsArgumentError,
    );
  });

  test('P2-02.05 exportTradesAsJson rejects trades from other users', () {
    expect(
      () => exportTradesAsJson([_t(userId: 'someone-else')], userId: 'u1'),
      throwsArgumentError,
    );
  });

  test('P2-02.05 mixed list rejected on first foreign trade', () {
    expect(
      () => exportTradesAsCsv([_t(), _t(id: 't2', userId: 'other')],
          userId: 'u1'),
      throwsArgumentError,
    );
  });

  // P2-02.06: no screenshot field anywhere in output
  test('P2-02.06 exported payload contains no screenshot key', () {
    final json = exportTradesAsJson([_t()]).toString();
    final csv = exportTradesAsCsv([_t()]);
    expect(json.toLowerCase(), isNot(contains('screenshot')));
    expect(csv.toLowerCase(), isNot(contains('screenshot')));
  });
}
