import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/providers/appwrite_provider.dart';
import 'ai_gateway_service.dart';
import '../trades/domain/trade.dart';
import 'domain/mt5_extraction.dart';

/// One on-device OCR attempt over the cropped MT5 row (P1-03.02).
/// The engine sees ONLY the local file path — the image never leaves
/// the device (PRD §11, P1-03.09).
sealed class OcrResult {
  const OcrResult();
}

/// Visible text blocks read from the crop (P1-03.05).
class OcrText extends OcrResult {
  const OcrText(this.blocks);
  final List<String> blocks;
}

/// No readable text anywhere in the crop (P1-03.07) — bad crop, chart,
/// or a blurred image. The screen tells the difference by [looksBlurry]:
/// blur detection runs on the crop pixels right before recognition.
class OcrNoText extends OcrResult {
  const OcrNoText({this.looksBlurry = false});

  /// Low-luminance-contrast / low-sharpness heuristic (P1-07.03).
  final bool looksBlurry;
}

/// Engine failed to initialize or process (P1-03.08) — recoverable
/// via retry or manual entry.
class OcrFailed extends OcrResult {
  const OcrFailed(this.reason);
  final String reason;
}

/// `OcrEngine` seam (ARCHITECTURE.md §12): input = image, output =
/// visible text blocks. Swappable without touching parser/UX.
abstract class OcrEngine {
  Future<OcrResult> recognize(String imagePath);
}

/// Runs Google ML Kit Text Recognition on-device (P1-03.03/04). The
/// latin script model ships inside the APK — zero network OCR.
class MlKitOcrEngine implements OcrEngine {
  @override
  Future<OcrResult> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final text =
          await recognizer.processImage(InputImage.fromFilePath(imagePath));
      final blocks = text.blocks
          .map((b) => b.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (blocks.isEmpty) {
        // Blurry-image heuristic (P1-07.03): sharp screenshots carry
        // strong luminance edges; blur smears them away. Cheap pixel
        // pass beats shipping a dedicated sharpness model.
        return OcrNoText(looksBlurry: await _looksBlurry(imagePath));
      }
      return OcrText(blocks);
    } on Object {
      // Missing model, corrupt file, engine crash — flow stays alive
      // and the temp image cleanup still runs in the caller.
      return const OcrFailed('Text recognition is not available.');
    } finally {
      await recognizer.close();
    }
  }

  /// Downscaled gradient-energy sharpness check (P1-07.03): decode
  /// the crop small (fast), sum luminance gradients. A sharp MT5
  /// row is edge-dense; blur flattens gradients toward zero. Only
  /// very low energy is flagged — plain "no data" crops stay on the
  /// generic copy (IMPLEMENTATION.md §18: never block valid inputs).
  static Future<bool> _looksBlurry(String imagePath) async {
    try {
      final data = await ui.ImmutableBuffer.fromFilePath(imagePath);
      final descriptor = ui.ImageDescriptor.raw(
        data,
        width: 0,
        height: 0,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      // ~192px tall keeps aspect: one trade row is wide and short.
      const h = 192.0;
      final w = (descriptor.width * h / descriptor.height).round();
      final codec = await descriptor.instantiateCodec(
        targetWidth: w,
        targetHeight: h.toInt(),
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
      image.dispose();
      descriptor.dispose();
      final lum = List<double>.filled(w * h.toInt(), 0);
      for (var p = 0, i = 0; p < bytes.length; p += 4, i++) {
        lum[i] = 0.299 * bytes[p] + 0.587 * bytes[p + 1] + 0.114 * bytes[p + 2];
      }
      var energy = 0.0;
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          final i = y * w + x;
          energy +=
              (lum[i] - lum[i - 1]).abs() + (lum[i] - lum[i - w]).abs();
        }
      }
      frame.image.dispose();
      descriptor.dispose();
      final perPixel = energy / ((w - 2) * (h - 2));
      // ponytail: single threshold, no hysteresis; tune on device QA
      // (QA-01.09) if false positives appear.
      return perPixel < 2.0;
    } on Object {
      return false; // decode failed → not blur, plain "no data"
    }
  }
}

/// Gateway-first engine, ML Kit fallback (P1-03 revision).
final ocrEngineProvider = Provider<OcrEngine>((ref) {
  final gateway = AiGatewayService(ref.watch(appwriteFunctionsProvider));
  return GatewayOcrEngine(gateway);
});

/// Gateway-first OCR (P1-03 revision): the cropped image goes to the
/// `gumibook-ai-gateway` Function, which forwards it to Gemini for
/// structured extraction. On ANY gateway failure (timeout, Function
/// down, provider error) it falls back to on-device ML Kit text
/// recognition so the flow never hard-blocks.
class GatewayOcrEngine implements OcrEngine {
  GatewayOcrEngine(this._gateway);

  final AiGatewayService _gateway;

  final MlKitOcrEngine _fallback = MlKitOcrEngine();

  String? _lastPath;

  @override
  Future<OcrResult> recognize(String imagePath) async {
    _lastPath = imagePath;
    try {
      final data = await _gateway.extractTradeFromImage(imagePath: imagePath);
      return await _toExtractionResult(data);
    } on Object {
      // ML Kit fallback keeps the manual/review flow alive offline.
      return _fallback.recognize(imagePath);
    }
  }

  /// Maps Gemini's structured JSON onto [OcrStructured] — the parser
  /// pipeline downstream consumes it like any other extraction.
  Future<OcrResult> _toExtractionResult(Map<String, dynamic> data) async {
    double? parseNum(String k) {
      final v = data[k];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    DateTime? date(String k) {
      final v = data[k];
      if (v is! String || v.isEmpty) return null;
      return DateTime.tryParse(v.replaceAll('.', '-'))?.toUtc();
    }

    // Structured path only "succeeds" if Gemini actually saw a trade
    // row — an all-null read must fall back to ML Kit so blur/no-data
    // copy and manual entry still work.
    final directionRaw = (data['direction'] as String?)?.toLowerCase();
    final instrument = (data['instrument'] as String?)?.trim();
    final hasAny = instrument != null && instrument.isNotEmpty ||
        directionRaw != null ||
        parseNum('profitLoss') != null ||
        parseNum('entryPrice') != null;
    if (!hasAny) {
      return await _fallback.recognize(_lastPath!);
    }

    final extraction = Mt5Extraction(
      instrument: ExtractedField(
        (data['instrument'] as String?)?.toUpperCase(),
        data['instrument']?.toString(),
      ),
      direction: ExtractedField(
        directionRaw == 'buy'
            ? TradeDirection.buy
            : directionRaw == 'sell'
                ? TradeDirection.sell
                : null,
        directionRaw,
      ),
      lotSize: ExtractedField(parseNum('lotSize'), data['lotSize']?.toString()),
      openTime: ExtractedField(date('openTime'), data['openTime']?.toString()),
      closeTime: ExtractedField(
          date('closeTime'), data['closeTime']?.toString()),
      entryPrice:
          ExtractedField(parseNum('entryPrice'), data['entryPrice']?.toString()),
      exitPrice:
          ExtractedField(parseNum('exitPrice'), data['exitPrice']?.toString()),
      stopLoss: parseNum('stopLoss') == null
          ? null
          : ExtractedField(parseNum('stopLoss'), data['stopLoss']?.toString()),
      takeProfit: parseNum('takeProfit') == null
          ? null
          : ExtractedField(parseNum('takeProfit'), data['takeProfit']?.toString()),
      profitLoss:
          ExtractedField(parseNum('profitLoss'), data['profitLoss']?.toString()),
      commission: null,
      swap: null,
    );

    return OcrStructured(extraction);
  }
}

/// Structured result from the Gemini gateway (P1-03 revision): the
/// extraction arrives pre-parsed as JSON, no on-device text parsing.
class OcrStructured extends OcrResult {
  const OcrStructured(this.extraction);

  final Mt5Extraction extraction;
}
