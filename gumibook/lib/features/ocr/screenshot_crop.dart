import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../core/design/gumi.dart';

/// One crop attempt over a picked MT5 screenshot. `path` is a
/// TEMPORARY cropped file in the app cache dir — same lifecycle
/// contract as the screenshot itself: never stored, released when
/// the OCR flow finishes or cancels (PRD §11, P1-02.06).
sealed class ScreenshotCrop {
  const ScreenshotCrop();
}

class ScreenshotCropped extends ScreenshotCrop {
  const ScreenshotCropped(this.path);
  final String path;
}

/// User backed out of the cropper (P1-02.05). `sourcePath` rides
/// along so the caller can release the original screenshot too.
class CropCancelled extends ScreenshotCrop {
  const CropCancelled();
}

/// Cropper failed to launch or crashed — recoverable, the UI can
/// offer a retry or manual entry.
class CropUnavailable extends ScreenshotCrop {
  const CropUnavailable(this.reason);
  final String reason;
}

/// Pluggable cropper seam (P1-02.02): mirrors `ScreenshotPicker` so
/// widgets and tests never touch the plugin. The dark cropper theme
/// reuses GumiBook tokens (DESIGN.md §3.1).
class ScreenshotCropper {
  ScreenshotCropper(this._cropper);

  final ImageCropper _cropper;

  Future<ScreenshotCrop> crop(String sourcePath) async {
    const c = GumiColorsDark();
    try {
      final file = await _cropper.cropImage(
        sourcePath: sourcePath,
        compressQuality: 90, // OCR reads text, not pixels — jpg is fine.
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop one trade row',
            toolbarColor: c.bgPrimary,
            backgroundColor: c.bgPrimary,
            activeControlsWidgetColor: c.accentSilver,
            dimmedLayerColor: c.bgPrimary,
            cropFrameColor: c.accentSilver,
            cropGridColor: c.borderFocus,
            toolbarWidgetColor: c.textPrimary,
            statusBarLight: false,
            // MT5 History rows are wide: freeform + wide presets keep the
            // one-trade-row guidance usable (P1-02.03/04).
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.ratio3x2,
            ],
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop one trade row',
            cancelButtonTitle: 'Cancel',
            doneButtonTitle: 'Done',
          ),
        ],
      );
      if (file == null) return const CropCancelled();
      return ScreenshotCropped(file.path);
    } catch (_) {
      // Plugin failure or unexpected error — never crash the flow
      // (P1-02.06 lifecycle contract: caller's cleanup must run).
      return const CropUnavailable(
        'Cropping is not available on this device.',
      );
    }
  }
}

final screenshotCropperProvider = Provider<ScreenshotCropper>(
  (ref) => ScreenshotCropper(ImageCropper()),
);
