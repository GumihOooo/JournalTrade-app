import 'package:flutter/foundation.dart';

import 'domain/trade.dart';
import '../../core/errors/failure.dart';

/// Trade validation (P0-07.04, DATABASE.md §4.2).
///
/// Returns null when the draft is valid; otherwise the first failed
/// rule as a human-readable message.
String? validateTradeDraft(TradeDraft d) {
  if (d.instrument.trim().isEmpty) return 'Instrument is required.';
  if (d.instrument.length > 32) return 'Instrument is too long.';
  switch (d.direction) {
    case TradeDirection.buy:
    case TradeDirection.sell:
      break;
  }
  if (d.entryPrice == d.exitPrice) return 'Entry and exit prices must differ.';
  if (d.lotSize <= 0) return 'Lot size must be greater than 0.';
  if (d.profitLoss.isNaN || d.profitLoss.isInfinite) {
    return 'Profit/Loss is not a valid number.';
  }
  if (!_validDate(d.openTime)) return 'Open time is not a valid date.';
  if (!_validDate(d.closeTime)) return 'Close time is not a valid date.';
  if (d.closeTime.isBefore(d.openTime)) {
    return 'Close time must not be before open time.';
  }
  for (final tag in d.confluence) {
    if (tag.length > 64) return 'Confluence tags must be at most 64 characters.';
  }
  for (final tag in d.mistakeTags) {
    if (tag.length > 64) return 'Mistake tags must be at most 64 characters.';
  }
  if (d.strategy != null && d.strategy!.length > 100) {
    return 'Strategy is too long.';
  }
  if (d.session != null && d.session!.length > 32) return 'Session is too long.';
  if (d.emotion != null && d.emotion!.length > 64) return 'Emotion is too long.';
  if (d.lessonLearned != null && d.lessonLearned!.length > 4000) {
    return 'Lesson learned is too long.';
  }
  if (d.notes != null && d.notes!.length > 8000) return 'Notes are too long.';
  return null;
}

bool _validDate(DateTime date) => !date.isBefore(DateTime.fromMillisecondsSinceEpoch(0));

/// Same rules, but throws [ValidationFailure] for repository use.
void assertValidTradeDraft(TradeDraft d) {
  final error = validateTradeDraft(d);
  if (error != null) throw ValidationFailure(error);
}

@visibleForTesting
void debugTradeValidation(TradeDraft d) {
  debugPrint('trade validation: ${validateTradeDraft(d) ?? 'ok'}');
}
