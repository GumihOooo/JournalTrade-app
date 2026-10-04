import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/journal/journal_screen.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

import '../helpers/journal_stub.dart';

/// Journal filter bar + sort sheet (P0-09.09..21) widget wiring.
void main() {
  List<Trade> trades() => [
        Trade(
          id: 'a',
          userId: 'u',
          instrument: 'XAUUSD',
          direction: TradeDirection.buy,
          entryPrice: 2400,
          exitPrice: 2410,
          lotSize: 0.1,
          profitLoss: 100,
          riskReward: 2,
          openTime: DateTime(2026, 1, 1, 9),
          closeTime: DateTime(2026, 1, 1, 10),
          session: 'London',
          emotion: 'calm',
          mistakeTags: const ['revenge'],
          inputMethod: TradeInputMethod.manual,
        ),
        Trade(
          id: 'b',
          userId: 'u',
          instrument: 'EURUSD',
          direction: TradeDirection.sell,
          entryPrice: 1.08,
          exitPrice: 1.09,
          lotSize: 1,
          profitLoss: -100,
          openTime: DateTime(2026, 1, 2, 9),
          closeTime: DateTime(2026, 1, 2, 10),
          inputMethod: TradeInputMethod.manual,
        ),
      ];

  Future<void> boot(
    WidgetTester tester, {
    List<Trade> data = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: noNetworkOverrides(trades: data),
        child: const MaterialApp(home: JournalScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> tapChipOption(WidgetTester tester, String chip,
      String option) async {
    // Filter-bar chips build eagerly (cacheExtent) — no scroll needed.
    final chipFinder = find.text(chip);
    await tester.pump();
    await tester.tap(chipFinder, warnIfMissed: false);
    await tester.pumpAndSettle(); // sheet entrance

    // The sheet's ListTiles sit inside a modal route — scope the tap
    // so it can never hit a same-label tile behind the sheet.
    final optionFinder = find
        .descendant(of: find.byType(ListTile), matching: find.text(option))
        .last;
    await tester.tap(optionFinder, warnIfMissed: false);
    await tester.pumpAndSettle(); // sheet exit + filter apply
  }

  testWidgets('filter chips render from dataset (P0-09.09..16)',
      (tester) async {
    await boot(tester, data: trades());

    expect(find.text('XAUUSD'), findsWidgets); // tile + chip
    expect(find.text('EURUSD'), findsWidgets);
    expect(find.byTooltip('Sort trades'), findsOneWidget);
  });

  /// Tile ids rendered, in order — ignores chips (same labels as tiles).
  List<String> tileIds(WidgetTester tester) => tester
      .widgetList<TradeListTile>(find.byType(TradeListTile))
      .map((t) => t.trade.id)
      .toList();

  testWidgets('SELL direction chip filters list (P0-09.11)', (tester) async {
    await boot(tester, data: trades());

    await tapChipOption(tester, 'Direction', 'SELL');

    expect(find.text('SELL'), findsWidgets); // chip label flipped
    expect(tileIds(tester), ['b']);
  });

  testWidgets('Wins outcome chip filters list (P0-09.16)', (tester) async {
    await boot(tester, data: trades());

    await tapChipOption(tester, 'Win/Loss', 'Wins');

    expect(tileIds(tester), ['a']);
  });

  testWidgets('sort sheet applies P/L sort reaktif (P0-09.19)', (tester) async {
    await boot(tester, data: trades());

    await tester.ensureVisible(find.byTooltip('Sort trades'));
    await tester.pump();
    await tester.tap(find.byTooltip('Sort trades'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lowest P/L'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Newest-first renders a first; Lowest P/L puts b (-100) first.
    expect(tileIds(tester), ['b', 'a']);
  });
}
