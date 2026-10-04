import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gumibook/features/ocr/screenshot_crop.dart';
import 'package:gumibook/features/ocr/screenshot_source.dart';
import 'package:gumibook/features/trades/add_trade_method_screen.dart';

import '../helpers/journal_stub.dart';

/// P1-01: picker seam + method-screen wiring. No real plugin calls.
void main() {
  test('ScreenshotUnavailable is a ScreenshotPick variant', () {
    expect(const ScreenshotUnavailable('x'), isA<ScreenshotPick>());
  });

  group('releaseTempScreenshot', () {
    test('null/empty path is a no-op', () async {
      await releaseTempScreenshot(null);
      await releaseTempScreenshot('');
    });

    test('deletes an existing temp file', () async {
      final f = File(
          '${Directory.systemTemp.path}/gumi_ocr_test_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes([1, 2, 3]);
      await releaseTempScreenshot(f.path);
      expect(f.existsSync(), isFalse);
    });

    test('missing file does not throw', () async {
      await releaseTempScreenshot(
          '${Directory.systemTemp.path}/gumi_ocr_never_exists.png');
    });
  });

  group('AddTradeMethodScreen', () {
    Future<void> boot(
      WidgetTester tester, {
      required FakeScreenshotPicker picker,
      ScreenshotCropper? cropper,
    }) async {
      final router = GoRouter(
        initialLocation: '/add-trade',
        routes: [
          GoRoute(
            path: '/add-trade',
            builder: (context, state) => const AddTradeMethodScreen(),
          ),
          GoRoute(
            path: '/add-trade/ocr-review',
            builder: (context, state) => const Scaffold(
              body: Text('ocr-review-dest'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...noNetworkOverrides(),
            screenshotPickerProvider.overrideWithValue(picker),
            if (cropper != null)
              screenshotCropperProvider.overrideWithValue(cropper),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('source sheet shows camera, gallery, and privacy copy',
        (tester) async {
      await boot(tester, picker: FakeScreenshotPicker());

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();

      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      // P1-01.07/09: privacy promise + supported-format note.
      expect(find.textContaining('Never uploaded or stored'), findsOneWidget);
      expect(find.textContaining('Chart screenshots are not supported'),
          findsOneWidget);
    });

    testWidgets('gallery pick routes to OCR review with the temp path',
        (tester) async {
      final picker = FakeScreenshotPicker(
        respond: (source) async =>
            ScreenshotPicked('/cache/tmp_screenshot.jpg'),
      );
      // P1-02: a crop step now sits between pick and review — pass
      // the pick path through unchanged (happy-path passthrough fake).
      final cropper = PassthroughCropper();
      await boot(tester, picker: picker, cropper: cropper);

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(picker.requested, [ScreenshotSource.gallery]);
      expect(cropper.cropped, ['/cache/tmp_screenshot.jpg']);
      expect(find.text('ocr-review-dest'), findsOneWidget);
    });

    testWidgets('cancel keeps the user on the method screen',
        (tester) async {
      final picker = FakeScreenshotPicker(
        respond: (source) async => const ScreenshotCancelled(),
      );
      await boot(tester, picker: picker);

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(find.text('Manual Entry'), findsOneWidget); // stayed put
      expect(picker.requested, [ScreenshotSource.camera]);
    });

    testWidgets('denied permission shows a snackbar, stays put',
        (tester) async {
      final picker = FakeScreenshotPicker(
        respond: (source) async => ScreenshotUnavailable(
          'Camera is not available or permission was denied.',
        ),
      );
      await boot(tester, picker: picker);

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Camera is not available or permission was denied.'),
        findsOneWidget,
      );
      expect(find.text('Manual Entry'), findsOneWidget);
    });

    testWidgets('no overflow at 320px width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await boot(tester, picker: FakeScreenshotPicker());

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

/// Scripted picker: never touches the plugin.
class FakeScreenshotPicker implements ScreenshotPicker {
  FakeScreenshotPicker({this.respond});

  final Future<ScreenshotPick> Function(ScreenshotSource source)? respond;
  final requested = <ScreenshotSource>[];

  @override
  Future<ScreenshotPick> pick(ScreenshotSource source) async {
    requested.add(source);
    return respond?.call(source) ?? const ScreenshotCancelled();
  }
}

/// Cropper fake returning the same path it was given (P1-02 passthrough).
class PassthroughCropper implements ScreenshotCropper {
  final cropped = <String>[];

  @override
  Future<ScreenshotCrop> crop(String sourcePath) async {
    cropped.add(sourcePath);
    return ScreenshotCropped(sourcePath);
  }
}
