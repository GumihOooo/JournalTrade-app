import '../../trades/domain/trade.dart';
import 'mt5_extraction.dart';

/// OCR extraction → pre-fill payload for the shared Add Trade form
/// (P1-05.01/02, IMPLEMENTATION.md §17 Step 5).
///
/// Required-by-form fields with no OCR value fall back to safe form
/// defaults (buy/0) — the FORM flags them, the draft never lies:
/// anything unread stays empty/null, nothing is inferred. P/L and RR
/// never ride along when OCR missed them; the form's auto-calc can
/// still offer a value the user may accept or edit.
TradeDraft mt5ExtractionToDraft(Mt5Extraction e) => TradeDraft(
      instrument: e.instrument.value ?? '',
      direction: e.direction.value ?? TradeDirection.buy,
      accountType: TradeAccountType.real,
      entryPrice: e.entryPrice.value ?? 0,
      exitPrice: e.exitPrice.value ?? 0,
      stopLoss: e.stopLoss?.value,
      takeProfit: e.takeProfit?.value,
      lotSize: e.lotSize.value ?? 0,
      profitLoss: e.profitLoss.value ?? 0,
      riskReward: null, // P1-04.15: never computed to fill a gap
      openTime: e.openTime.value ?? DateTime.fromMillisecondsSinceEpoch(0),
      closeTime: e.closeTime.value ?? DateTime.fromMillisecondsSinceEpoch(0),
      inputMethod: TradeInputMethod.ocr,
    );

/// Form-required fields the OCR could not read (P1-05.03): each gets
/// a `Needs review` flag in the review UI. `entryPrice == exitPrice`
/// counts as unread — the form rejects equal prices anyway.
bool ocrDraftNeedsReview(Mt5Extraction e) => [
      e.instrument,
      e.lotSize,
      e.entryPrice,
      e.exitPrice,
      e.profitLoss,
      e.openTime,
      e.closeTime,
    ].any((f) => !f.detected) ||
    (e.entryPrice.value != null &&
        e.entryPrice.value == e.exitPrice.value);
