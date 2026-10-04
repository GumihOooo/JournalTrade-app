import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gumibook/core/design/gumi.dart';
import 'package:gumibook/features/calculator/calculator_detail_screen.dart';
import 'package:gumibook/features/calculator/calculator_hub_screen.dart';
import 'package:gumibook/features/calculator/calculator_specs.dart';

/// P2-01.01 UI + P2-01.12 copy action: hub lists all ten calculators,
/// detail computes live, copy writes to clipboard.
void main() {
  GoRouter testRouter() => GoRouter(
        initialLocation: '/settings/calculator',
        routes: [
          GoRoute(
            path: '/settings/calculator',
            builder: (context, state) => const CalculatorHubScreen(),
            routes: [
              for (final spec in calculatorSpecs)
                GoRoute(
                  path: spec.id,
                  builder: (context, state) =>
                      CalculatorDetailScreen(spec: spec),
                ),
            ],
          ),
        ],
      );

  Future<void> boot(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: testRouter(),
          theme: GumiTheme.dark(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String title) async {
    await boot(tester);
    await tester.scrollUntilVisible(find.text(title), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, Map<String, String> values) async {
    for (final e in values.entries) {
      await tester.enterText(
          find.widgetWithText(NumericField, e.key), e.value);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('hub lists all ten calculators', (tester) async {
    await boot(tester);
    for (final spec in calculatorSpecs) {
      await tester.scrollUntilVisible(find.text(spec.title), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(spec.title), findsOneWidget);
    }
  });

  testWidgets('hub navigates to calculator and computes live', (tester) async {
    await open(tester, 'Lot Size');

    await fill(tester, {
      'Account Balance': '1000',
      'Risk': '1',
      'Stop Loss Distance': '0.01',
    });

    expect(find.text('1000 lots'), findsOneWidget);
  });

  testWidgets('profit calculator flips sign on Sell', (tester) async {
    await open(tester, 'Profit');

    await fill(tester, {
      'Entry Price': '1.1',
      'Exit Price': '1.105',
      'Contract Size': '100000',
      'Lot Size': '1',
    });

    expect(find.text('\$500'), findsOneWidget);

    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();
    expect(find.text('-\$500'), findsOneWidget);
  });

  testWidgets('copy result action writes clipboard (P2-01.12)',
      (tester) async {
    // Clipboard.getData hangs in widget tests (no platform reply), so
    // intercept the setData call instead.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await open(tester, 'Compound');

    await fill(tester, {
      'Starting Balance': '1000',
      'Gain per Period': '10',
      'Periods': '3',
    });

    await tester.tap(find.byTooltip('Copy Final Balance'));
    await tester.pumpAndSettle();

    expect(find.text('Copied to clipboard.'), findsOneWidget);
    expect(copied, 'Final Balance: \$1331');
  });
}
