import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/gumi.dart';
import '../ocr/screenshot_crop.dart';
import '../ocr/screenshot_source.dart';

/// Add Trade method selector (P0-08.01, P1-01.04, DESIGN.md §5.6).
///
/// Manual entry, or MT5 screenshot import: opens the Camera/Gallery
/// source sheet with the privacy promise attached. The screenshot is
/// processed on-device and never stored.
class AddTradeMethodScreen extends ConsumerStatefulWidget {
  const AddTradeMethodScreen({super.key});

  @override
  ConsumerState<AddTradeMethodScreen> createState() =>
      _AddTradeMethodScreenState();
}

class _AddTradeMethodScreenState extends ConsumerState<AddTradeMethodScreen> {
  bool _picking = false;

  Future<void> _scanScreenshot() async {
    if (_picking) return;
    final source = await showScreenshotSourceSheet(context);
    if (source == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final pick = await ref
          .read(screenshotPickerProvider)
          .pick(source);
      if (!mounted) return;
      switch (pick) {
        case ScreenshotPicked(:final path):
          await _crop(path);
        case ScreenshotCancelled():
          break; // closed the picker — nothing to clean, no file created
        case ScreenshotUnavailable(:final reason):
          _snack(reason);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Crop step (P1-02.02..06): exactly one MT5 History row, then hand
  /// the temp cropped path to the OCR pipeline. Only one temp image
  /// exists at any point: the original is released in `finally` (even
  /// on unexpected cropper errors), the crop output is either handed
  /// to the OCR screen — which releases it on completion — or deleted
  /// right here on unmount.
  Future<void> _crop(String sourcePath) async {
    late final ScreenshotCrop crop;
    try {
      crop = await ref.read(screenshotCropperProvider).crop(sourcePath);
    } on Object {
      // Safety net for a throwing seam (P1-02.06): the flow must not
      // crash and the original file must not leak.
      unawaited(releaseTempScreenshot(sourcePath));
      if (mounted) _snack('Cropping is not available on this device.');
      return;
    }
    unawaited(releaseTempScreenshot(sourcePath));
    switch (crop) {
      case ScreenshotCropped(:final path):
        if (!mounted) {
          unawaited(releaseTempScreenshot(path));
          return;
        }
        // The temp file path travels in memory only — never stored.
        unawaited(context.push('/add-trade/ocr-review', extra: path));
      case CropCancelled():
        break; // temp files already released above
      case CropUnavailable(:final reason):
        _snack(reason);
    }
  }

  // ignore: use_build_context_synchronously
  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app/dashboard'),
        ),
        title: const Text('Add Trade'),
      ),
      backgroundColor: c.bgPrimary,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MethodCard(
            icon: Icons.edit_outlined,
            title: 'Manual Entry',
            subtitle: 'Type the trade details yourself.',
            onTap: () => context.push('/add-trade/manual'),
          ),
          const SizedBox(height: 12),
          _MethodCard(
            icon: Icons.document_scanner_outlined,
            title: 'Import MT5 Screenshot',
            subtitle:
                'Read trade data from an MT5 History screenshot. '
                'The image is processed on your device and never stored.',
            onTap: _scanScreenshot,
            loading: _picking,
          ),
        ],
      ),
    );
  }
}

/// Camera vs Gallery source sheet (P1-01.05/06) — glass bottom sheet
/// matching the journal sort/filter sheets. Returns null when dismissed.
Future<ScreenshotSource?> showScreenshotSourceSheet(BuildContext context) {
  final c = context.gumiColors;
  final theme = Theme.of(context);
  return showModalBottomSheet<ScreenshotSource>(
    context: context,
    backgroundColor: c.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(GumiRadius.glass)),
    ),
    builder: (sheetContext) => SafeArea(
      // Small screens: the two tiles + notices scroll instead of
      // overflowing (P1-01 QA: no RenderFlex overflow at 320px).
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Import MT5 Screenshot',
                    style: theme.textTheme.titleMedium),
              ),
              const _SourceTile(
                source: ScreenshotSource.gallery,
                icon: Icons.photo_library_outlined,
                title: 'Choose from Gallery',
                // P1-01.08: name the supported input.
                subtitle: 'MT5 History screenshot (one trade per import).',
              ),
              const _SourceTile(
                source: ScreenshotSource.camera,
                icon: Icons.photo_camera_outlined,
                title: 'Take Photo',
                subtitle: 'Capture the MT5 History window.',
              ),
              // P1-02.03: crop instruction up front — the cropper opens next.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.crop_rounded, size: 16, color: c.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You will crop exactly 1 row of MT5 trade history.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // P1-01.09: unsupported input stated up front.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: c.semanticWarning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chart screenshots are not supported — use the '
                        'History tab view.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // P1-01.07: the privacy promise rides with the action.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: c.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Processed on-device and deleted after extraction. '
                        'Never uploaded or stored.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.source,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ScreenshotSource source;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: c.surfaceGlass,
        borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.pop(context, source),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 28, color: c.accentSilver),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return GlassCard(
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: loading ? 0.5 : 1,
          child: Row(
            children: [
              Icon(icon, size: 32, color: c.accentSilver),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Icon(Icons.chevron_right, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
