import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/trades/domain/trade.dart';
import 'package:gumibook/features/trades/trade_detail_screen.dart';

import '../helpers/journal_stub.dart';

/// Trade detail (P0-10.01..03, P0-10.12): sections, no screenshot UI,
/// edit/delete actions present.
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
        confluence: const ['HTF bias', 'liquidity sweep'],
        emotion: 'calm',
        mistakeTags: const ['late entry'],
        lessonLearned: 'Wait for confirmation.',
        notes: 'Clean setup.',
        inputMethod: TradeInputMethod.manual,
      );

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: noNetworkOverrides(trades: [trade()]),
        child: const MaterialApp(home: TradeDetailScreen(tradeId: 't1')),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders all three sections with values', (tester) async {
    await boot(tester);

    expect(find.text('Execution'), findsOneWidget);
    expect(find.text('Psychology'), findsOneWidget);

    // Execution values. (SELL appears twice: badge + direction row.)
    expect(find.text('SELL'), findsWidgets);
    expect(find.text('FUNDED'), findsOneWidget);
    expect(find.text('2400'), findsOneWidget);
    expect(find.text('2390'), findsOneWidget);
    expect(find.text('2405'), findsOneWidget);
    expect(find.text('2380'), findsOneWidget);
    expect(find.text('0.50 lots'), findsOneWidget);
    expect(find.text('1.50'), findsOneWidget);
    expect(find.text('-500.00 USD'), findsOneWidget);

    // Reflection card sits below the fold — scroll it in.
    await tester.scrollUntilVisible(
      find.text('Reflection'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Reflection'), findsOneWidget);
    expect(find.text('late entry'), findsOneWidget);
    expect(find.text('Wait for confirmation.'), findsOneWidget);
    expect(find.text('Clean setup.'), findsOneWidget);
  });

  testWidgets('edit and delete actions present in the app bar',
      (tester) async {
    await boot(tester);

    expect(find.byTooltip('Edit trade'), findsOneWidget);
    expect(find.byTooltip('Delete trade'), findsOneWidget);
  });

  testWidgets('no screenshot/image section exists (P0-10.12)', (tester) async {
    await boot(tester);

    expect(find.text('Screenshot'), findsNothing);
    expect(find.byType(Image), findsNothing);
    // Execution + Psychology visible; scroll for Reflection, then all
    // three section headers exist and no fourth section follows.
    await tester.scrollUntilVisible(
      find.text('Reflection'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.byWidgetPredicate((w) =>
          w is Text &&
          (w.data == 'Execution' ||
           w.data == 'Psychology' ||
           w.data == 'Reflection')),
      findsNWidgets(3),
    );
  });

  testWidgets('unknown trade id shows the unavailable state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: noNetworkOverrides(trades: [trade()]),
        child:
            const MaterialApp(home: TradeDetailScreen(tradeId: 'missing')),
      ),
    );
    await tester.pump();

    expect(
        find.text('This trade is no longer available.'), findsOneWidget);
  });
}
