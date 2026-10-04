/// Trade domain (P0-07.01..03, DATABASE.md §4, §11).
///
/// `Trade` is the persisted entity; `TradeDraft` is the pre-confirm
/// state (manual input or OCR extraction). Optional fields stay null
/// when OCR or the user did not fill them — never inferred.
library;

enum TradeDirection { buy, sell }

enum TradeInputMethod { manual, ocr }

/// Funding status of the traded account (DATABASE.md §4.1).
enum TradeAccountType { real, funded }

TradeAccountType? accountTypeFromString(String? value) =>
    switch (value?.toLowerCase()) {
      'real' => TradeAccountType.real,
      'funded' => TradeAccountType.funded,
      _ => null,
    };

enum TradingSession { sydney, tokyo, london, newyork }

enum TradeOutcome { win, loss, breakeven }

TradeDirection? directionFromString(String? value) => switch (value?.toLowerCase()) {
      'buy' => TradeDirection.buy,
      'sell' => TradeDirection.sell,
      _ => null,
    };

TradeInputMethod? inputMethodFromString(String? value) =>
    switch (value?.toLowerCase()) {
      'manual' => TradeInputMethod.manual,
      'ocr' => TradeInputMethod.ocr,
      _ => null,
    };

/// One persisted trade document (DATABASE.md §4.1).
class Trade {
  const Trade({
    required this.id,
    required this.userId,
    required this.instrument,
    required this.direction,
    this.accountType = TradeAccountType.real,
    required this.entryPrice,
    required this.exitPrice,
    this.stopLoss,
    this.takeProfit,
    required this.lotSize,
    required this.profitLoss,
    this.riskReward,
    required this.openTime,
    required this.closeTime,
    this.strategy,
    this.session,
    this.confluence = const [],
    this.emotion,
    this.mistakeTags = const [],
    this.lessonLearned,
    this.notes,
    required this.inputMethod,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String instrument;
  final TradeDirection direction;
  final TradeAccountType accountType;
  final double entryPrice;
  final double exitPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double lotSize;
  final double profitLoss;
  final double? riskReward;
  final DateTime openTime;
  final DateTime closeTime;
  final String? strategy;
  final String? session;
  final List<String> confluence;
  final String? emotion;
  final List<String> mistakeTags;
  final String? lessonLearned;
  final String? notes;
  final TradeInputMethod inputMethod;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TradeOutcome get outcome {
    if (profitLoss > 0) return TradeOutcome.win;
    if (profitLoss < 0) return TradeOutcome.loss;
    return TradeOutcome.breakeven;
  }

  /// Pre-fill payload for the shared trade form (edit flow, P0-10.05).
  TradeDraft toDraft() => TradeDraft(
        instrument: instrument,
        direction: direction,
        accountType: accountType,
        entryPrice: entryPrice,
        exitPrice: exitPrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        lotSize: lotSize,
        profitLoss: profitLoss,
        riskReward: riskReward,
        openTime: openTime,
        closeTime: closeTime,
        strategy: strategy,
        session: session,
        confluence: confluence,
        emotion: emotion,
        mistakeTags: mistakeTags,
        lessonLearned: lessonLearned,
        notes: notes,
        inputMethod: inputMethod,
      );

  Trade copyWith({
    String? instrument,
    TradeDirection? direction,
    TradeAccountType? accountType,
    double? entryPrice,
    double? exitPrice,
    Object? stopLoss = _unset,
    Object? takeProfit = _unset,
    double? lotSize,
    double? profitLoss,
    Object? riskReward = _unset,
    DateTime? openTime,
    DateTime? closeTime,
    Object? strategy = _unset,
    Object? session = _unset,
    List<String>? confluence,
    Object? emotion = _unset,
    List<String>? mistakeTags,
    Object? lessonLearned = _unset,
    Object? notes = _unset,
  }) =>
      Trade(
        id: id,
        userId: userId,
        instrument: instrument ?? this.instrument,
        direction: direction ?? this.direction,
        accountType: accountType ?? this.accountType,
        entryPrice: entryPrice ?? this.entryPrice,
        exitPrice: exitPrice ?? this.exitPrice,
        stopLoss: stopLoss == _unset ? this.stopLoss : stopLoss as double?,
        takeProfit: takeProfit == _unset ? this.takeProfit : takeProfit as double?,
        lotSize: lotSize ?? this.lotSize,
        profitLoss: profitLoss ?? this.profitLoss,
        riskReward: riskReward == _unset ? this.riskReward : riskReward as double?,
        openTime: openTime ?? this.openTime,
        closeTime: closeTime ?? this.closeTime,
        strategy: strategy == _unset ? this.strategy : strategy as String?,
        session: session == _unset ? this.session : session as String?,
        confluence: confluence ?? this.confluence,
        emotion: emotion == _unset ? this.emotion : emotion as String?,
        mistakeTags: mistakeTags ?? this.mistakeTags,
        lessonLearned:
            lessonLearned == _unset ? this.lessonLearned : lessonLearned as String?,
        notes: notes == _unset ? this.notes : notes as String?,
        inputMethod: inputMethod,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static const _unset = Object();
}

/// Pre-confirm state: manual form input or OCR extraction
/// (DATABASE.md §11). Unread fields stay null; nothing is guessed.
class TradeDraft {
  const TradeDraft({
    required this.instrument,
    required this.direction,
    this.accountType = TradeAccountType.real,
    required this.entryPrice,
    required this.exitPrice,
    this.stopLoss,
    this.takeProfit,
    required this.lotSize,
    required this.profitLoss,
    this.riskReward,
    required this.openTime,
    required this.closeTime,
    this.strategy,
    this.session,
    this.confluence = const [],
    this.emotion,
    this.mistakeTags = const [],
    this.lessonLearned,
    this.notes,
    this.inputMethod = TradeInputMethod.manual,
  });

  final String instrument;
  final TradeDirection direction;
  final TradeAccountType accountType;
  final double entryPrice;
  final double exitPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double lotSize;
  final double profitLoss;
  final double? riskReward;
  final DateTime openTime;
  final DateTime closeTime;
  final String? strategy;
  final String? session;
  final List<String> confluence;
  final String? emotion;
  final List<String> mistakeTags;
  final String? lessonLearned;
  final String? notes;
  final TradeInputMethod inputMethod;
}
