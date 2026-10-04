import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gumibook/features/ocr/screenshot_crop.dart';
import 'package:gumibook/features/ocr/screenshot_source.dart';
import 'package:gumibook/features/trades/add_trade_method_screen.dart';

import '../helpers/journal_stub.dart';

/// P1-02: cropper seam + lifecycle. No real plugin calls.
void main() {
  group('ScreenshotCropper result types', () {
    test('variants are ScreenshotCrop', () {
      expect(const ScreenshotCropped('x'), isA<ScreenshotCrop>());
      expect(const CropCancelled(), isA<ScreenshotCrop>());
      expect(const CropUnavailable('y'), isA<ScreenshotCrop>());
    });
  });

  group('AddTradeMethodScreen crop wiring', () {
    Future<void> boot(
      WidgetTester tester, {
      required FakeScreenshotPicker picker,
      required FakeScreenshotCropper cropper,
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
            screenshotCropperProvider.overrideWithValue(cropper),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pickGallery(WidgetTester tester) async {
      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
    }

    testWidgets('source sheet shows the crop-one-row guidance',
        (tester) async {
      await boot(
        tester,
        picker: FakeScreenshotPicker(),
        cropper: FakeScreenshotCropper(),
      );

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();

      // P1-02.03: instruction visible before the flow starts.
      expect(
        find.textContaining('crop exactly 1 row of MT5 trade history'),
        findsOneWidget,
      );
    });

    testWidgets('successful crop routes to OCR review with the cropped path',
        (tester) async {
      final cropper = FakeScreenshotCropper(
        respond: (source) async =>
            const ScreenshotCropped('/cache/tmp_cropped.jpg'),
      );
      await boot(
        tester,
        picker: FakeScreenshotPicker(
          respond: (source) async =>
              ScreenshotPicked('/cache/tmp_screenshot.jpg'),
        ),
        cropper: cropper,
      );

      await pickGallery(tester);

      expect(cropper.cropped, ['/cache/tmp_screenshot.jpg']);
      expect(find.text('ocr-review-dest'), findsOneWidget);
    });

    testWidgets('cancel keeps the user on the method screen', (tester) async {
      final cropper = FakeScreenshotCropper(
        respond: (source) async => const CropCancelled(),
      );
      await boot(
        tester,
        picker: FakeScreenshotPicker(
          respond: (source) async =>
              ScreenshotPicked('/cache/tmp_screenshot.jpg'),
        ),
        cropper: cropper,
      );

      await pickGallery(tester);

      expect(find.text('Manual Entry'), findsOneWidget); // stayed put
      expect(find.text('ocr-review-dest'), findsNothing);
    });

    testWidgets('cropper error shows a snackbar, stays put', (tester) async {
      final cropper = FakeScreenshotCropper(
        respond: (source) async =>
            const CropUnavailable('Cropping is not available on this device.'),
      );
      await boot(
        tester,
        picker: FakeScreenshotPicker(
          respond: (source) async =>
              ScreenshotPicked('/cache/tmp_screenshot.jpg'),
        ),
        cropper: cropper,
      );

      await pickGallery(tester);

      expect(
        find.text('Cropping is not available on this device.'),
        findsOneWidget,
      );
      expect(find.text('Manual Entry'), findsOneWidget);
    });

    testWidgets('no overflow at 320px width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await boot(
        tester,
        picker: FakeScreenshotPicker(),
        cropper: FakeScreenshotCropper(),
      );

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('P1-02.06 temp cropped file lifecycle', () {
    /// Real temp file + passthrough flow: the cropped file must be
    /// gone once the review screen is popped (cancel path included).
    testWidgets('cropped file deleted when review screen closes',
        (tester) async {
      final dir = Directory.systemTemp;
      final sourceFile = File(
          '${dir.path}/gumi_crop_src_${DateTime.now().microsecondsSinceEpoch}.jpg');
      final croppedFile = File(
          '${dir.path}/gumi_crop_out_${DateTime.now().microsecondsSinceEpoch}.jpg');
      sourceFile.writeAsBytesSync([1]);
      croppedFile.writeAsBytesSync([1]);

      final router = GoRouter(
        initialLocation: '/add-trade',
        routes: [
          GoRoute(
            path: '/add-trade',
            builder: (context, state) => const AddTradeMethodScreen(),
          ),
          GoRoute(
            // Mirror the real route: the stub releases the cropped
            // temp file in dispose().
            path: '/add-trade/ocr-review',
            builder: (context, state) => OcrReviewReleaseProbe(
              tempPath: state.extra! as String,
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...noNetworkOverrides(),
            screenshotPickerProvider.overrideWithValue(FakeScreenshotPicker(
              respond: (source) async => ScreenshotPicked(sourceFile.path),
            )),
            screenshotCropperProvider.overrideWithValue(
              PassthroughCropper(croppedFile.path),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(find.text('review-probe'), findsOneWidget);
      expect(sourceFile.existsSync(), isFalse); // original released after crop
      expect(croppedFile.existsSync(), isTrue); // still owned by the flow

      // User backs out of the review screen mid-flow (cancel path).
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(croppedFile.existsSync(), isFalse); // P1-02.06: no leftover
    });

    /// Unexpected cropper crash must not leak the original screenshot.
    testWidgets('cropper throwing still releases the source file',
        (tester) async {
      final dir = Directory.systemTemp;
      final sourceFile = File(
          '${dir.path}/gumi_crop_throw_${DateTime.now().microsecondsSinceEpoch}.jpg');
      sourceFile.writeAsBytesSync([1]);

      final router = GoRouter(
        initialLocation: '/add-trade',
        routes: [
          GoRoute(
            path: '/add-trade',
            builder: (context, state) => const AddTradeMethodScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...noNetworkOverrides(),
            screenshotPickerProvider.overrideWithValue(FakeScreenshotPicker(
              respond: (source) async => ScreenshotPicked(sourceFile.path),
            )),
            screenshotCropperProvider.overrideWithValue(
              ThrowingCropper(),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import MT5 Screenshot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(sourceFile.existsSync(), isFalse); // released despite the throw
      expect(find.text('Manual Entry'), findsOneWidget); // graceful stay
    });
  });
}

/// Stand-in for the real OCR review stub: records the temp path and
/// releases it on dispose, exactly like OcrReviewStubScreen.
class OcrReviewReleaseProbe extends StatefulWidget {
  const OcrReviewReleaseProbe({super.key, required this.tempPath});

  final String tempPath;

  @override
  State<OcrReviewReleaseProbe> createState() => _OcrReviewReleaseProbeState();
}

class _OcrReviewReleaseProbeState extends State<OcrReviewReleaseProbe> {
  @override
  void dispose() {
    releaseTempScreenshot(widget.tempPath);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('review-probe')),
        body: const SizedBox.shrink(),
      );
}

/// Scripted cropper: never touches the plugin.
class FakeScreenshotCropper implements ScreenshotCropper {
  FakeScreenshotCropper({this.respond});

  final Future<ScreenshotCrop> Function(String sourcePath)? respond;
  final cropped = <String>[];

  @override
  Future<ScreenshotCrop> crop(String sourcePath) async {
    cropped.add(sourcePath);
    return respond?.call(sourcePath) ?? const CropCancelled();
  }
}

/// Minimal stand-in for the picker seam (P1-01 fake stays there; this
/// copy keeps the P1-02 test file independent of plugin imports).
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

/// Cropper fake returning a fixed path (P1-02 passthrough).
class PassthroughCropper implements ScreenshotCropper {
  PassthroughCropper(this.fixedPath);

  final String fixedPath;
  final cropped = <String>[];

  @override
  Future<ScreenshotCrop> crop(String sourcePath) async {
    cropped.add(sourcePath);
    return ScreenshotCropped(fixedPath);
  }
}

/// Cropper fake that crashes with an unexpected error type.
class ThrowingCropper implements ScreenshotCropper {
  @override
  Future<ScreenshotCrop> crop(String sourcePath) => Future.error(
        StateError('cropper exploded'),
      );
}
