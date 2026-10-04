import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/features/ocr/domain/mt5_draft_adapter.dart';
import 'package:gumibook/features/ocr/domain/mt5_trade_parser.dart';
import 'package:gumibook/features/trades/domain/trade.dart';

/// P1-05 Step 5: extraction → TradeDraft pre-fill. Unread fields stay
/// empty/safe defaults — never inferred, never fabricated.
void main() {
  test('full row fills every draft field, inputMethod = ocr', () {
    final d = mt5ExtractionToDraft(parseMt5TradeRow([
      'XAUUSD sell 0.10 2026.09.05 14:32:11 2026.09.05 15:01:22',
      '3304.55 3306.10',
      'sl 3302.00 tp 3308.50',
      'commission -0.70 swap -5.20 25.00',
    ]));

    expect(d.inputMethod, TradeInputMethod.ocr);
    expect(d.instrument, 'XAUUSD');
    expect(d.direction, TradeDirection.sell);
    expect(d.lotSize, 0.10);
    expect(d.entryPrice, 3304.55);
    expect(d.exitPrice, 3306.10);
    expect(d.stopLoss, 3302.00);
    expect(d.takeProfit, 3308.50);
    expect(d.profitLoss, 25.00);
    expect(d.openTime, DateTime(2026, 9, 5, 14, 32, 11));
    expect(d.closeTime, DateTime(2026, 9, 5, 15, 1, 22));
    expect(ocrDraftNeedsReview(parseMt5TradeRow([
      'XAUUSD sell 0.10 2026.09.05 14:32:11 2026.09.05 15:01:22',
      '3304.55 3306.10',
      'sl 3302.00 tp 3308.50',
      'commission -0.70 swap -5.20 25.00',
    ])), isFalse);
  });

  test('partial row: unread fields become form-safe sentinels + review flag',
      () {
    final e = parseMt5TradeRow(['GBPJPY buy']);
    final d = mt5ExtractionToDraft(e);

    expect(d.instrument, 'GBPJPY');
    expect(d.direction, TradeDirection.buy);
    expect(d.lotSize, 0); // form renders empty (sentinel)
    expect(d.entryPrice, 0);
    expect(d.profitLoss, 0);
    expect(d.openTime, DateTime.fromMillisecondsSinceEpoch(0));
    expect(d.riskReward, isNull); // never computed to fill a gap
    expect(ocrDraftNeedsReview(e), isTrue);
  });

  test('direction missing: form default buy, review flagged', () {
    final e = parseMt5TradeRow(['XAUUSD 0.10 3304.55 3306.10 25.00']);
    final d = mt5ExtractionToDraft(e);

    expect(d.direction, TradeDirection.buy); // safe default, flagged
    expect(ocrDraftNeedsReview(e), isTrue); // times unread
  });
}
