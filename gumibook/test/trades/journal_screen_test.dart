import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/journal/journal_screen.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

import '../helpers/journal_stub.dart';

/// Journal screen wiring (P0-09.01..08): list rendering, empty state,
/// local search over instrument/strategy/notes, instant clear.
///
/// Filter chips share labels with tiles — tile assertions scope to
/// TradeListTile so a chip never fakes a list result.
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
          strategy: 'London Breakout',
          notes: 'clean setup',
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

  /// Tile ids rendered, in order — filter chips share labels with
  /// tiles, so list assertions scope to TradeListTile.
  List<String> tileIds(WidgetTester tester) => tester
      .widgetList<TradeListTile>(find.byType(TradeListTile))
      .map((t) => t.trade.id)
      .toList();

  testWidgets('renders newest-first trades with badges and P/L colors',
      (tester) async {
    await boot(tester, data: trades());

    expect(tileIds(tester), ['a', 'b']);
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('SELL'), findsOneWidget);
    expect(find.text('+100.00 USD'), findsOneWidget);
    expect(find.text('-100.00 USD'), findsOneWidget);
    expect(find.text('RR 2.00'), findsOneWidget);
  });

  testWidgets('empty journal shows empty state with Add Trade action',
      (tester) async {
    await boot(tester);
    expect(find.text('No trades yet. Log your first trade.'), findsOneWidget);
    expect(find.text('Add Trade'), findsOneWidget);
  });

  testWidgets('search instrument filters the list', (tester) async {
    await boot(tester, data: trades());

    await tester.enterText(find.byType(TextField), 'xau');
    await tester.pump();

    expect(tileIds(tester), ['a']);
  });

  testWidgets('search strategy matches', (tester) async {
    await boot(tester, data: trades());

    await tester.enterText(find.byType(TextField), 'london');
    await tester.pump();

    expect(tileIds(tester), ['a']);
  });

  testWidgets('search notes matches', (tester) async {
    await boot(tester, data: trades());

    await tester.enterText(find.byType(TextField), 'clean setup');
    await tester.pump();

    expect(tileIds(tester), ['a']);
  });

  testWidgets('no match shows search-empty state, not journal-empty',
      (tester) async {
    await boot(tester, data: trades());

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();

    expect(
        find.text('No trades match your search or filters.'), findsOneWidget);
    expect(find.text('No trades yet. Log your first trade.'), findsNothing);
  });

  testWidgets('clear button resets the query instantly', (tester) async {
    await boot(tester, data: trades());

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(
        find.text('No trades match your search or filters.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(tileIds(tester), ['a', 'b']);
    expect(find.byTooltip('Clear search'), findsNothing);
  });
}
