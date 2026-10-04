import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/design/gumi.dart';
import 'package:gumibook/features/trades/add_trade_screen.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

import '../helpers/journal_stub.dart';

/// Edit flow (P0-10.05): AddTradeScreen reuses the same form with
/// `editing`, pre-populating every field from the existing trade.
void main() {
  Trade trade() => Trade(
        id: 't1',
        userId: 'u',
        instrument: 'XAUUSD',
        direction: TradeDirection.sell,
        accountType: TradeAccountType.funded,
        entryPrice: 2400,
        exitPrice: 2390,
        stopLoss: 2405,
        takeProfit: 2380,
        lotSize: 0.5,
        profitLoss: -500,
        riskReward: 1.5,
        openTime: DateTime(2026, 1, 1, 9),
        closeTime: DateTime(2026, 1, 1, 10),
        strategy: 'London Breakout',
        session: 'London',
        confluence: const ['HTF bias'],
        emotion: 'calm',
        mistakeTags: const ['late entry'],
        lessonLearned: 'Wait for confirmation.',
        notes: 'Clean setup.',
        inputMethod: TradeInputMethod.manual,
      );

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: noNetworkOverrides(),
        child: MaterialApp(home: AddTradeScreen(editing: trade())),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the vertical form until the labeled GumiTextField is
  /// built and visible, then returns its controller text.
  Future<String> scrollToField(WidgetTester tester, String label) async {
    final scrollable = find.byType(Scrollable).first;
    for (var i = 0; i < 20; i++) {
      final found = find.widgetWithText(GumiTextField, label);
      if (found.evaluate().isNotEmpty) {
        return tester
            .widget<GumiTextField>(found.first)
            .controller!
            .text;
      }
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    return '';
  }

  testWidgets('edit mode pre-populates every field and stays editable',
      (tester) async {
    await boot(tester);

    expect(find.text('Edit Trade'), findsOneWidget);

    // Execution card.
    expect(await scrollToField(tester, 'Instrument'), 'XAUUSD');
    expect(await scrollToField(tester, 'Entry Price'), '2400.0');
    expect(await scrollToField(tester, 'Exit Price'), '2390.0');
    expect(await scrollToField(tester, 'Stop Loss'), '2405.0');
    expect(await scrollToField(tester, 'Take Profit'), '2380.0');
    expect(await scrollToField(tester, 'Lot Size'), '0.5');
    expect(await scrollToField(tester, 'Profit/Loss'), '-500.0');
    expect(await scrollToField(tester, 'Risk/Reward'), '1.5');

    // SELL segment is selected (not the buy default).
    final segments =
        tester.widget<SegmentedButton<TradeDirection>>(find
                .byType(SegmentedButton<TradeDirection>)
                .first);
    expect(segments.selected, {TradeDirection.sell});

    // Context card fields.
    expect(await scrollToField(tester, 'Strategy'), 'London Breakout');
    expect(await scrollToField(tester, 'Confluence (comma separated)'), 'HTF bias');
    expect(await scrollToField(tester, 'Emotion'), 'calm');

    // Save button label confirms edit mode.
    final save = find.widgetWithText(FilledButton, 'Save Changes');
    await tester.scrollUntilVisible(save, 300,
        scrollable: find.byType(Scrollable).first);
    expect(save, findsOneWidget);
  });

  testWidgets('edit mode keeps user edits (auto-calc never clobbers)',
      (tester) async {
    await boot(tester);

    // Pre-filled P/L must not be recomputed away by typing elsewhere.
    final notes = find.widgetWithText(GumiTextField, 'Notes');
    await tester.scrollUntilVisible(notes, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(notes, 'edited note');
    await tester.pump();

    final pl = find.widgetWithText(GumiTextField, 'Profit/Loss');
    await tester.scrollUntilVisible(pl, -300,
        scrollable: find.byType(Scrollable).first);
    expect(
      tester.widget<GumiTextField>(pl.first).controller!.text,
      '-500.0',
    );
  });
}
