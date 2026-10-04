import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/auth_provider.dart';
import '../trade_repository.dart';
import 'trade_exporter.dart';

/// Export + share flow (P2-02.07). Loads the current user's full
/// trade list via TradeRepository (already user-scoped server-side),
/// serializes through the ownership-checked exporter, writes a temp
/// file, and hands it to the system share sheet.
class TradeExportController {
  TradeExportController(this._ref);

  final Ref _ref;

  /// Exports [format] ('json' or 'csv'), shares it, and returns the
  /// number of exported trades (for the confirmation snackbar).
  Future<int> exportAndShare(String format) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw StateError('Not authenticated');
    final trades = await _ref.read(tradeRepositoryProvider).listAll();
    final userId = user.$id;

    final String content;
    final String fileName;
    switch (format) {
      case 'csv':
        content = exportTradesAsCsv(trades, userId: userId);
        fileName = 'gumibook-trades.csv';
      default:
        content = _prettyJson(exportTradesAsJson(trades, userId: userId));
        fileName = 'gumibook-trades.json';
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);

    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, name: fileName)]),
    );
    // ponytail: keep the temp file when dismissed/unavailable so a
    // retry shares the same artifact; delete only on clear success.
    if (result.status == ShareResultStatus.success) {
      unawaited(file.delete().catchError((_) => file));
    }
    return trades.length;
  }

  static String _prettyJson(Map<String, dynamic> data) =>
      const JsonEncoder.withIndent('  ').convert(data);
}

final tradeExportControllerProvider = Provider<TradeExportController>(
  (ref) => TradeExportController(ref),
);
