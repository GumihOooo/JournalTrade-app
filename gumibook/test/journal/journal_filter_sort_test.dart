import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/journal/journal_provider.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

/// Pure filter + sort logic (P0-09.09..20) — no widgets.
void main() {
  Trade t({
    required String id,
    String instrument = 'XAUUSD',
    TradeDirection direction = TradeDirection.buy,
    double profitLoss = 0,
    double? riskReward,
    String? strategy,
    String? session,
    String? emotion,
    List<String> mistakeTags = const [],
    DateTime? closeTime,
  }) =>
      Trade(
        id: id,
        userId: 'u',
        instrument: instrument,
        direction: direction,
        entryPrice: 1,
        exitPrice: 2,
        lotSize: 1,
        profitLoss: profitLoss,
        riskReward: riskReward,
        openTime: closeTime ?? DateTime(2026, 1, 1, 9),
        closeTime: closeTime ?? DateTime(2026, 1, 1, 10),
        strategy: strategy,
        session: session,
        emotion: emotion,
        mistakeTags: mistakeTags,
        inputMethod: TradeInputMethod.manual,
      );

  final trades = [
    t(id: 'a', profitLoss: 100, riskReward: 2, strategy: 'London',
        session: 'London', emotion: 'calm', closeTime: DateTime(2026, 1, 1, 10)),
    t(id: 'b', instrument: 'EURUSD', direction: TradeDirection.sell,
        profitLoss: -50, riskReward: 1,
        strategy: 'NY Reversal', session: 'New York', emotion: 'fomo',
        mistakeTags: ['revenge'], closeTime: DateTime(2026, 2, 1, 10)),
    t(id: 'c', profitLoss: 0, closeTime: DateTime(2026, 3, 1, 10)),
  ];

  group('filterTrades (P0-09.09..16)', () {
    test('empty filter + empty query returns everything', () {
      expect(
        filterTrades(trades, const JournalFilter(), ''),
        trades,
      );
    });

    test('date range filters on close time (P0-09.09)', () {
      final f = JournalFilter(
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 31),
        ),
      );
      expect(filterTrades(trades, f, '').map((t) => t.id), ['a']);
    });

    test('instrument, direction, strategy, session, emotion, mistake, outcome',
        () {
      expect(filterTrades(trades, JournalFilter(instrument: 'eurusd'), '')
          .map((t) => t.id), ['b']);
      expect(filterTrades(trades, JournalFilter(direction: TradeDirection.sell), '')
          .map((t) => t.id), ['b']);
      expect(filterTrades(trades, JournalFilter(strategy: 'London'), '')
          .map((t) => t.id), ['a']);
      expect(filterTrades(trades, JournalFilter(session: 'New York'), '')
          .map((t) => t.id), ['b']);
      expect(filterTrades(trades, JournalFilter(emotion: 'fomo'), '')
          .map((t) => t.id), ['b']);
      expect(filterTrades(trades, JournalFilter(mistakeTag: 'revenge'), '')
          .map((t) => t.id), ['b']);
      expect(filterTrades(trades, JournalFilter(outcome: TradeOutcome.win), '')
          .map((t) => t.id), ['a']);
      expect(filterTrades(trades, JournalFilter(outcome: TradeOutcome.loss), '')
          .map((t) => t.id), ['b']);
    });

    test('filters compose', () {
      final f = JournalFilter(
        direction: TradeDirection.sell,
        outcome: TradeOutcome.loss,
      );
      expect(filterTrades(trades, f, '').map((t) => t.id), ['b']);
    });
  });

  group('sortTrades (P0-09.17..20)', () {
    test('newest keeps server order; oldest reverses', () {
      expect(sortTrades(trades, JournalSort.newest).map((t) => t.id),
          ['a', 'b', 'c']);
      expect(sortTrades(trades, JournalSort.oldest).map((t) => t.id),
          ['c', 'b', 'a']);
    });

    test('P/L highest and lowest (P0-09.19)', () {
      expect(sortTrades(trades, JournalSort.profitLossDesc).map((t) => t.id),
          ['a', 'c', 'b']);
      expect(sortTrades(trades, JournalSort.profitLossAsc).map((t) => t.id),
          ['b', 'c', 'a']);
    });

    test('RR highest, nulls last (P0-09.20)', () {
      expect(sortTrades(trades, JournalSort.riskRewardDesc).map((t) => t.id),
          ['a', 'b', 'c']);
    });
  });
}
