import 'package:gumibook/features/trades/domain/trade.dart';

/// Minimal trade factory for analytics tests (P1-08.12) — only the
/// fields analytics reads; identity fields are fixed placeholders.
Trade t({
  String instr = 'XAUUSD',
  double pl = 0,
  double? rr,
  String? strategy,
  String? session,
  String? emotion,
  DateTime? close,
}) =>
    Trade(
      id: 't${_seq++}',
      userId: 'u',
      instrument: instr,
      direction: TradeDirection.buy,
      entryPrice: 1,
      exitPrice: 2,
      lotSize: 0.1,
      profitLoss: pl,
      riskReward: rr,
      openTime: close ?? DateTime(2026, 1, 1),
      closeTime: close ?? DateTime(2026, 1, 1),
      strategy: strategy,
      session: session,
      emotion: emotion,
      inputMethod: TradeInputMethod.manual,
    );

var _seq = 0;
