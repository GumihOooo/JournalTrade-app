import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/trades/add_trade_screen.dart';

import '../helpers/journal_stub.dart';

/// Live P/L / RR auto-calc wiring (P0-08). Locks the fix where P/L
/// stayed empty while RR auto-filled: P/L needs instrument + direction
/// + entry + exit + lots; RR only entry + exit + SL.
void main() {
  Future<void> bootForm(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: noNetworkOverrides(),
        child: const MaterialApp(home: AddTradeScreen()),
      ),
    );
    await tester.pump();
  }

  Future<void> fill(WidgetTester tester, String label, String text) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.enterText(field, text);
    await tester.pump();
  }

  String fieldText(WidgetTester tester, String label) {
    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, label),
    );
    return field.controller!.text;
  }

  Future<void> tapDirection(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.ensureVisible(target);
    await tester.pump();
    await tester.tap(target, warnIfMissed: false);
    await tester.pump();
  }

  testWidgets('P/L and RR auto-calculate, P/L follows lot size changes',
      (tester) async {
    await bootForm(tester);

    await fill(tester, 'Instrument', 'XAUUSD');
    await fill(tester, 'Entry Price', '2400');
    await fill(tester, 'Exit Price', '2410');

    // Direction picked from the BUY/SELL toggle.
    await tapDirection(tester, 'BUY');
    await tester.pump();

    await fill(tester, 'Stop Loss', '2395');
    await fill(tester, 'Lot Size', '0.01');
    await tester.pump();

    // (2410 - 2400) x 100 x 0.01 = 10 USD. RR = 10 / 5 = 2.
    expect(fieldText(tester, 'Profit/Loss'), '10');
    expect(fieldText(tester, 'Risk/Reward'), '2');

    // Lot 0.01 -> 0.02: P/L must follow live (10 -> 20).
    await fill(tester, 'Lot Size', '0.02');
    await tester.pump();
    expect(fieldText(tester, 'Profit/Loss'), '20');
  });

  testWidgets('SELL flips the P/L sign live', (tester) async {
    await bootForm(tester);

    await fill(tester, 'Instrument', 'XAUUSD');
    await fill(tester, 'Entry Price', '2400');
    await fill(tester, 'Exit Price', '2410');
    await fill(tester, 'Lot Size', '0.01');

    await tapDirection(tester, 'SELL');
    await tester.pump();

    // Sell + price up = loss.
    expect(fieldText(tester, 'Profit/Loss'), '-10');
  });

  testWidgets('unknown instrument stays manual (no guess)', (tester) async {
    await bootForm(tester);

    await fill(tester, 'Instrument', 'DOGEUSD');
    await fill(tester, 'Entry Price', '1');
    await fill(tester, 'Exit Price', '2');
    await fill(tester, 'Lot Size', '1');
    await tapDirection(tester, 'BUY');
    await tester.pump();

    expect(fieldText(tester, 'Profit/Loss'), '');
    expect(fieldText(tester, 'Risk/Reward'), '');
  });

  testWidgets('manual edit of P/L survives until inputs change',
      (tester) async {
    await bootForm(tester);

    await fill(tester, 'Instrument', 'XAUUSD');
    await fill(tester, 'Entry Price', '2400');
    await fill(tester, 'Exit Price', '2410');
    await fill(tester, 'Lot Size', '0.01');
    await tapDirection(tester, 'BUY');
    await tester.pump();
    expect(fieldText(tester, 'Profit/Loss'), '10');

    // User overrides the auto value — must stick, later input changes
    // never clobber an explicit user edit.
    await fill(tester, 'Profit/Loss', '55.5');
    await tester.pump();
    expect(fieldText(tester, 'Profit/Loss'), '55.5');

    // Even a new input change respects the user's explicit value.
    await fill(tester, 'Exit Price', '2412');
    await tester.pump();
    expect(fieldText(tester, 'Profit/Loss'), '55.5');
  });
}
