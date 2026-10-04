import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/gumi.dart';
import 'domain/mt5_draft_adapter.dart';
import 'domain/mt5_extraction.dart';
import 'domain/mt5_trade_parser.dart';
import 'ocr_engine.dart';
import 'screenshot_source.dart';

/// OCR processing + error/review stage (P1-03.06, P1-07, replaces the
/// P1-05 stub): runs the on-device engine over the cropped temp file,
/// parses the MT5 row (P1-04), and maps every failure to its DESIGN.md
/// §5.12 error state with the documented recovery actions:
///
/// - no text / no trade data  → `Could not detect trade data.`;
/// - blurry crop              → `Image is too blurry. Please select a
///                              clearer screenshot.`;
/// - non-MT5/chart crop       → `This doesn't appear to be an MT5 Trade
///                              History screenshot.`;
/// - engine failure           → reason + Retry / Choose Another / Manual.
///
/// Primary recovery: Retry (same crop re-recognized — the temp file
/// is kept until this screen exits) and Choose Another Screenshot.
/// Secondary recovery: Manual Entry.
///
/// The temp image is released exactly once on dispose (PRD §11 —
/// every path out of this screen still deletes the file).
class OcrReviewScreen extends ConsumerStatefulWidget {
  const OcrReviewScreen({super.key, this.tempPath});

  final String? tempPath;

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  OcrResult? _result;
  Mt5Extraction? _extraction;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.tempPath != null) _run();
  }

  @override
  void dispose() {
    // P1-02.06/§11: the crop dies when THIS screen dies — retry keeps
    // it alive in between, success paths pop after saving elsewhere.
    final path = widget.tempPath;
    if (path != null) {
      // Sync delete: widget teardown, test FakeAsync zones (async IO
      // would leak past the test).
      releaseTempScreenshotSync(path);
    }
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final result =
        await ref.read(ocrEngineProvider).recognize(widget.tempPath!);
    if (!mounted) return;
    setState(() {
      _result = result;
      _extraction = switch (result) {
        OcrStructured(:final extraction) => extraction,
        OcrText() => parseMt5TradeRow(result.blocks),
        _ => null,
      };
      _running = false;
    });
  }

  /// Hands the extraction to the shared Add Trade form (P1-05.01/02):
  /// detected fields pre-fill, the rest stay empty for manual entry —
  /// the user reviews and confirms there, nothing saves here.
  void _reviewInForm() {
    final e = _extraction;
    if (e == null) return;
    // Success handoff: the crop's job is done (P1-06.03) — release
    // NOW, not at dispose; the form below may stay on the stack for
    // a while and must never keep the image alive.
    releaseTempScreenshotSync(widget.tempPath);
    context.push('/add-trade/manual', extra: mt5ExtractionToDraft(e));
  }

  /// True when the OCR text has trade-row structure at all (P1-07.04):
  /// used to tell "wrong screenshot type" from "bad crop of a right
  /// screenshot". Chart screenshots yield words/dates but never the
  /// symbol+buy/sell+lots signature of a History row.
  bool get _textLooksLikeTradeRow {
    final e = _extraction;
    return e != null && e.hasAnyField;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/add-trade'),
        ),
        title: const Text('Extract Trade'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_running) ...[
                const CircularProgressIndicator(strokeWidth: 2.5),
                const SizedBox(height: 16),
                Text(
                  'Reading trade data…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your screenshot is never uploaded.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: c.textMuted),
                ),
              ] else ...[
                Icon(
                  switch (_outcome) {
                    _OcrOutcome.full => Icons.check_circle_outline,
                    _OcrOutcome.partial => Icons.check_circle_outline,
                    _ => Icons.error_outline,
                  },
                  size: 48,
                  color: switch (_outcome) {
                    _OcrOutcome.full => c.semanticProfit,
                    _OcrOutcome.partial => c.semanticProfit,
                    _ => c.semanticWarning,
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                // P1-07.02 (partial): one line naming what was read —
                // per-field chips; the form flags the rest on review.
                if (_outcome == _OcrOutcome.partial) ...[
                  const SizedBox(height: 12),
                  Text(
                    _detectedFieldsSummary,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Missing fields stay empty and are marked in the form.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.semanticWarning),
                  ),
                ],
                const SizedBox(height: 24),
                ..._actions(context),
                const SizedBox(height: 12),
                Text(
                  'Your screenshot was not saved.',
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Classification (DESIGN.md §5.12, IMPLEMENTATION.md §18).
  _OcrOutcome get _outcome => switch (_result) {
        null => _OcrOutcome.idle,
        OcrStructured(:final extraction) when extraction.hasAnyField =>
          ocrDraftNeedsReview(extraction)
              ? _OcrOutcome.partial
              : _OcrOutcome.full,
        OcrStructured() => _OcrOutcome.noData,
        OcrText() when _textLooksLikeTradeRow => _extraction != null &&
                ocrDraftNeedsReview(_extraction!)
            ? _OcrOutcome.partial
            : _OcrOutcome.full,
        OcrText() => _OcrOutcome.nonMt5, // text but no row signature
        OcrNoText(:final looksBlurry) when looksBlurry =>
          _OcrOutcome.blurry,
        OcrNoText() => _OcrOutcome.noData,
        OcrFailed() => _OcrOutcome.engineFailure,
      };

  String get _headline => switch (_outcome) {
        _OcrOutcome.idle => '',
        _OcrOutcome.full => _extraction!.instrument.detected
            ? 'Trade row read: ${_extraction!.instrument.value}.'
            : 'Some trade data was read.',
        _OcrOutcome.partial => _extraction!.instrument.detected
            ? 'Trade row read: ${_extraction!.instrument.value}.'
            : 'Some trade data was read.',
        // P1-07.01: exact §5.12 copy.
        _OcrOutcome.noData => 'Could not detect trade data.',
        // P1-07.03: exact §5.12 copy.
        _OcrOutcome.blurry =>
          'Image is too blurry. Please select a clearer screenshot.',
        // P1-07.04: exact §5.12 copy. Text was found (symbols, axis
        // labels, dates) but nothing matches a History row signature
        // (IMPLEMENTATION.md §18: conservative — no aggressive chart
        // detection, this only fires when zero trade fields matched).
        _OcrOutcome.nonMt5 =>
          "This doesn't appear to be an MT5 Trade History screenshot.",
        _OcrOutcome.engineFailure => (_result as OcrFailed).reason,
      };

  /// P1-07.02: the fields OCR actually read, user-facing names.
  String get _detectedFieldsSummary {
    final e = _extraction!;
    final names = <String>[
      if (e.instrument.detected) 'Instrument',
      if (e.direction.detected) 'Direction',
      if (e.lotSize.detected) 'Lot Size',
      if (e.openTime.detected) 'Open Time',
      if (e.closeTime.detected) 'Close Time',
      if (e.entryPrice.detected) 'Entry',
      if (e.exitPrice.detected) 'Exit',
      if (e.stopLoss?.detected == true) 'Stop Loss',
      if (e.takeProfit?.detected == true) 'Take Profit',
      if (e.profitLoss.detected) 'P/L',
      if (e.commission?.detected == true) 'Commission',
      if (e.swap?.detected == true) 'Swap',
    ];
    if (names.isEmpty) return '';
    return 'Detected: ${names.join(', ')}.';
  }

  /// Recovery actions (§5.12): primary Retry + Choose Another, then
  /// secondary Manual Entry. Success states keep the review CTA.
  List<Widget> _actions(BuildContext context) {
    switch (_outcome) {
      case _OcrOutcome.full:
      case _OcrOutcome.partial:
        return [
          PrimaryButton(
            label: 'Review Extracted Data',
            onPressed: _reviewInForm,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Enter Manually Instead',
            onPressed: () => context.go('/add-trade/manual', extra: null),
          ),
        ];
      case _OcrOutcome.noData:
      case _OcrOutcome.blurry:
      case _OcrOutcome.nonMt5:
      case _OcrOutcome.engineFailure:
        return [
          // P1-07.05: re-run over the SAME crop (kept alive until
          // this screen pops). For blurry, a re-read rarely helps —
          // Choose Another is primary there per the copy.
          if (_outcome != _OcrOutcome.blurry)
            PrimaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _run,
            ),
          if (_outcome != _OcrOutcome.blurry) const SizedBox(height: 12),
          // P1-07.06: back to the import entry (method screen) for a
          // fresh Gallery/Camera pick.
          SecondaryButton(
            label: _outcome == _OcrOutcome.blurry
                ? 'Choose a Clearer Screenshot'
                : 'Choose Another Screenshot',
            icon: Icons.image_outlined,
            onPressed: () => context.go('/add-trade'),
          ),
          const SizedBox(height: 12),
          // P1-07.07: secondary recovery — always offered.
          SecondaryButton(
            label: 'Enter Manually Instead',
            icon: Icons.edit_outlined,
            onPressed: () => context.go('/add-trade/manual', extra: null),
          ),
        ];
      case _OcrOutcome.idle:
        return [];
    }
  }
}

/// §5.12 classification for the current OCR result.
enum _OcrOutcome {
  idle, // no temp path / not run yet
  full, // full trade row
  partial, // P1-07.02: some fields read, rest need review
  noData, // P1-07.01: no text / nothing matched
  blurry, // P1-07.03: low sharpness
  nonMt5, // P1-07.04: text present, no row signature
  engineFailure, // P1-03.08: engine error
}
