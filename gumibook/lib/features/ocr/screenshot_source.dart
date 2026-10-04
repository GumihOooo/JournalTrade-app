import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where the user chose to get the MT5 screenshot from (P1-01.05/06).
enum ScreenshotSource { camera, gallery }

/// Result of one pick attempt. `path` is a TEMPORARY local file — it
/// must never be uploaded, stored in the database, or kept after the
/// OCR flow finishes/cancels (PRD §11, ARCHITECTURE.md §11).
sealed class ScreenshotPick {
  const ScreenshotPick();
}

class ScreenshotPicked extends ScreenshotPick {
  const ScreenshotPicked(this.path);
  final String path;
}

/// User closed the picker without choosing (P1-02.05 cancel path).
class ScreenshotCancelled extends ScreenshotPick {
  const ScreenshotCancelled();
}

/// Permission denied / camera unavailable — recoverable, the UI offers
/// the other source or manual entry.
class ScreenshotUnavailable extends ScreenshotPick {
  const ScreenshotUnavailable(this.reason);
  final String reason;
}

/// Pluggable picker seam (P1-01): wraps `image_picker` so widgets and
/// tests stay free of the plugin. One implementation calls the real
/// picker; tests override the provider.
class ScreenshotPicker {
  ScreenshotPicker(this._picker);

  final ImagePicker _picker;

  Future<ScreenshotPick> pick(ScreenshotSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source == ScreenshotSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 90, // OCR does not need camera-original bitmaps.
      );
      if (image == null) return const ScreenshotCancelled();
      return ScreenshotPicked(image.path);
    } on PlatformException {
      // plugin throws when the permission was denied or the source is
      // physically unavailable (no camera on the device).
      return ScreenshotUnavailable(
        source == ScreenshotSource.camera
            ? 'Camera is not available or permission was denied.'
            : 'Photo library is not available or permission was denied.',
      );
    }
  }
}

final screenshotPickerProvider = Provider<ScreenshotPicker>(
  (ref) => ScreenshotPicker(ImagePicker()),
);

/// Deletes a temporary screenshot reference. Safe to call twice or on
/// a path that never existed — releasing temp files must never crash
/// the flow (P1-06 lifecycle contract). Sync FS calls: cache-dir
/// cleanup is tiny, and sync completes instantly inside widget-test
/// FakeAsync zones (async IO there would hang the test).
Future<void> releaseTempScreenshot(String? path) async {
  releaseTempScreenshotSync(path);
}

/// Sync twin (P1-07.05: retry keeps the crop alive — release moves to
/// widget dispose, where async IO would outlive the element).
void releaseTempScreenshotSync(String? path) {
  if (path == null || path.isEmpty) return;
  try {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
  } catch (_) {
    // Cache dir cleanup; nothing actionable for the user.
  }
}
