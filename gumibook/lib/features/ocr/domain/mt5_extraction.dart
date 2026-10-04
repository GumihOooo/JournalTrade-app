import '../../trades/domain/trade.dart';

/// One OCR-extracted field (IMPLEMENTATION.md §17): value + the raw
/// text it came from. `rawText` is in-memory only — never persisted.
class ExtractedField<T> {
  const ExtractedField(this.value, this.rawText);

  final T? value;
  final String? rawText;

  bool get detected => value != null;
}

/// MT5 History row extraction (P1-04). Every field nullable: missing
/// stays missing — the parser never guesses, never infers direction
/// from profit, never computes SL/TP (PRD §10 extraction rules).
class Mt5Extraction {
  const Mt5Extraction({
    required this.instrument,
    required this.direction,
    required this.lotSize,
    required this.openTime,
    required this.closeTime,
    required this.entryPrice,
    required this.exitPrice,
    required this.stopLoss,
    required this.takeProfit,
    required this.profitLoss,
    required this.commission,
    required this.swap,
  });

  final ExtractedField<String> instrument;
  final ExtractedField<TradeDirection> direction;
  final ExtractedField<double> lotSize;
  final ExtractedField<DateTime> openTime;
  final ExtractedField<DateTime> closeTime;
  final ExtractedField<double> entryPrice;
  final ExtractedField<double> exitPrice;
  final ExtractedField<double>? stopLoss;
  final ExtractedField<double>? takeProfit;
  final ExtractedField<double> profitLoss;
  final ExtractedField<double>? commission;
  final ExtractedField<double>? swap;

  /// Which required-ish fields the OCR read — drives the `needs
  /// review` UX (P1-05) without leaking TradeDraft's required fields.
  bool get hasAnyField => [
        instrument,
        direction,
        lotSize,
        openTime,
        closeTime,
        entryPrice,
        exitPrice,
        profitLoss,
      ].any((f) => f.detected);
}
