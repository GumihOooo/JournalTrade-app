import 'dart:convert';
import 'dart:io';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart';

import '../../core/config/appwrite_config.dart';
import '../../core/errors/failure.dart';

/// Calls the `gumibook-ai-gateway` Appwrite Function (P1-03 revision).
///
/// Single entry point for every AI task. The app NEVER talks to Gemini
/// directly; no API key exists client-side. Images are sent transiently
/// for extraction only — never stored on any server.
class AiGatewayService {
  AiGatewayService(this._functions);

  final Functions _functions;

  /// Sends an image crop for OCR and returns the structured Trade JSON
  /// produced by Gemini. Throws [Failure] on any gateway error.
  Future<Map<String, dynamic>> extractTradeFromImage({
    required String imagePath,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final base64 = base64Encode(bytes);
    return executeTask('ocr', {
      'imageBase64': base64,
      'imageMimeType': _mimeType(imagePath),
    });
  }

  /// Generic task execution — future tasks (market/news/prices) reuse
  /// this without any service-layer change.
  Future<Map<String, dynamic>> executeTask(
    String task,
    Map<String, dynamic> payload,
  ) async {
    try {
      final execution = await _functions.createExecution(
        functionId: AppwriteConfig.aiGatewayFunctionId,
        body: jsonEncode({'task': task, 'payload': payload}),
        method: ExecutionMethod.pOST,
      );

      final status = execution.status;
      final body = execution.responseBody;
      if (status == ExecutionStatus.failed || body.isEmpty) {
        throw const OcrFailure('AI gateway execution failed.');
      }

      final decoded = jsonDecode(body) as Map<String, dynamic>;
      if (decoded['ok'] != true) {
        throw OcrFailure(
          (decoded['error'] as String?) ?? 'AI gateway error.',
        );
      }
      return (decoded['data'] as Map<String, dynamic>?) ?? const {};
    } on OcrFailure {
      rethrow;
    } on AppwriteException catch (e) {
      throw OcrFailure('AI gateway unavailable: ${e.message}');
    } on Object {
      throw const OcrFailure(
        'AI gateway unreachable. Check your connection.',
      );
    }
  }

  static String _mimeType(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }
}
