import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/design/gumi.dart';
import 'package:gumibook/features/market/widgets/price_flash_text.dart';

/// P2-05 UI polish: price flash animation and shimmer placeholders.
void main() {
  group('PriceFlashText', () {
    testWidgets('null value renders N/A, never a fabricated number',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PriceFlashText(value: null)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('N/A'), findsOneWidget);
    });

    testWidgets('price renders and settles after flash', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PriceFlashText(value: 2043.52)),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));

      expect(find.text('2043.52'), findsOneWidget);
      // No exception even after animation completes.
      await tester.pumpAndSettle();
    });

    testWidgets('rebuilding with a new price restarts the flash',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PriceFlashText(value: 100.0)),
      ));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PriceFlashText(value: 101.0)),
      ));
      await tester.pump();
      expect(find.text('101.00'), findsOneWidget);
    });
  });

  group('GumiShimmer', () {
    testWidgets('shimmer renders skeleton rows without crashing',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ShimmerRow(widthFraction: 0.5),
              ShimmerCard(height: 80),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 700));

      // Shimmer repeats forever — never pumpAndSettle here.
      expect(find.byType(GumiShimmer), findsNWidgets(2));
    });
  });
}
