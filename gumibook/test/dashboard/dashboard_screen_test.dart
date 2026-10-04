import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/dashboard/dashboard_screen.dart';
import 'package:gumibook/features/settings/user_settings_provider.dart';
import 'package:gumibook/features/settings/user_settings_repository.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

import '../helpers/journal_stub.dart';

/// Dashboard base (P0-11.01..08): metric cards from journal state,
/// optional Balance, empty state CTA, no overflow at small widths.
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
          profitLoss: -50,
          openTime: DateTime(2026, 1, 2, 9),
          closeTime: DateTime(2026, 1, 2, 10),
          inputMethod: TradeInputMethod.manual,
        ),
        Trade(
          id: 'c',
          userId: 'u',
          instrument: 'BTCUSD',
          direction: TradeDirection.buy,
          entryPrice: 100,
          exitPrice: 110,
          lotSize: 1,
          profitLoss: 10,
          openTime: DateTime(2026, 1, 3, 9),
          closeTime: DateTime(2026, 1, 3, 10),
          inputMethod: TradeInputMethod.manual,
        ),
      ];

  Future<void> boot(
    WidgetTester tester, {
    List<Trade> data = const [],
    UserSettings settings = const UserSettings(),
    Size size = const Size(800, 600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...noNetworkOverrides(trades: data),
          userSettingsProvider.overrideWith((ref) async => settings),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('metric cards compute from journal state', (tester) async {
    await boot(tester, data: trades());

    // 100 - 50 + 10 = 60; win rate 2/3; avg RR 2.00; 3 trades.
    // P1-09: Total P/L card AND Equity Curve trailing both show it.
    expect(find.text('+60.00 USD'), findsWidgets);
    expect(find.text('66.7%'), findsOneWidget);
    expect(find.text('2.00'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // Latest-trade line sits below the fold — scroll it in.
    await tester.scrollUntilVisible(
      find.textContaining('XAUUSD BUY 100.00'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('XAUUSD BUY 100.00'), findsOneWidget);
  });

  testWidgets('Balance card hidden when starting balance unset',
      (tester) async {
    await boot(tester, data: trades());

    expect(find.text('BALANCE'), findsNothing);
  });

  testWidgets('Balance card shows starting balance + P/L when set',
      (tester) async {
    await boot(
      tester,
      data: trades(),
      settings: const UserSettings(
        startingBalance: 1000,
        balanceCurrency: 'USD',
      ),
    );

    // 1000 + 60 = 1060.00 USD.
    expect(find.text('BALANCE'), findsOneWidget);
    expect(find.text('1060.00'), findsOneWidget);
    expect(find.text('USD'), findsWidgets);
  });

  testWidgets('empty journal shows empty state with Add Trade CTA',
      (tester) async {
    await boot(tester);

    expect(
      find.text('Start your trading journal by adding your first trade.'),
      findsOneWidget,
    );
    expect(find.text('Add Trade'), findsOneWidget);
  });

  testWidgets('no overflow at 320px width (small phones)', (tester) async {
    await boot(
      tester,
      data: trades(),
      settings: const UserSettings(startingBalance: 1000),
      size: const Size(320, 640),
    );

    // Any RenderFlex overflow throws during layout and fails the test.
    expect(tester.takeException(), isNull);
    expect(find.text('+60.00 USD'), findsOneWidget);
    expect(find.text('1060.00'), findsOneWidget);
  });
}
