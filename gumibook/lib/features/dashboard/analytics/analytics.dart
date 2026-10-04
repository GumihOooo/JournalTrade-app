/// Analytics engine (P1-08, IMPLEMENTATION.md §19, PRD §8):
/// pure functions over `List<Trade>` — no widgets, no providers, no
/// network. The dashboard (P1-09) consumes these for every chart.
///
/// Rules baked in:
/// - Win Rate = wins / total × 100 (breakeven counts as non-win).
/// - Average RR = mean over trades that carry RR only (P1-08.14).
/// - Equity = starting balance (nullable → 0, P1-08.05a) + cumulative
///   P/L, ordered by close time ascending.
/// - Drawdown = decline from the previous equity peak, in money and
///   percent of that peak (P1-08.06).
/// - Breakdowns exclude trades with a null key (never a fake bucket).
/// - Heatmap buckets trades by ISO weekday × close hour (P1-08.11).
/// - Zero trades → zero/empty results, never NaN, never throws
///   (P1-08.13).
library;

import '../../trades/domain/trade.dart';

/// Headline metrics (P1-08.01..04).
class TradeSummary {
  const TradeSummary({
    required this.totalTrades,
    required this.totalProfitLoss,
    required this.winRate,
    required this.averageRiskReward,
    required this.wins,
    required this.losses,
    required this.breakevens,
  });

  final int totalTrades;
  final double totalProfitLoss;

  /// 0..100; 0 when no trades.
  final double winRate;

  /// Null when no trade carries RR (P1-08.14).
  final double? averageRiskReward;
  final int wins;
  final int losses;
  final int breakevens;
}

const _emptySummary = TradeSummary(
  totalTrades: 0,
  totalProfitLoss: 0,
  winRate: 0,
  averageRiskReward: null,
  wins: 0,
  losses: 0,
  breakevens: 0,
);

TradeSummary summarizeTrades(List<Trade> trades) {
  if (trades.isEmpty) return _emptySummary;
  var wins = 0, losses = 0, breakevens = 0, pl = 0.0;
  final rrs = <double>[];
  for (final t in trades) {
    pl += t.profitLoss;
    switch (t.outcome) {
      case TradeOutcome.win:
        wins++;
      case TradeOutcome.loss:
        losses++;
      case TradeOutcome.breakeven:
        breakevens++;
    }
    final rr = t.riskReward;
    if (rr != null) rrs.add(rr);
  }
  return TradeSummary(
    totalTrades: trades.length,
    totalProfitLoss: pl,
    winRate: wins / trades.length * 100,
    averageRiskReward:
        rrs.isEmpty ? null : rrs.reduce((a, b) => a + b) / rrs.length,
    wins: wins,
    losses: losses,
    breakevens: breakevens,
  );
}

/// Equity curve (P1-08.05): trades ordered by close time, equity
/// after each trade. Ties keep input order (stable sort).
class EquityCurve {
  const EquityCurve(this.orderedTrades, this.equity);

  final List<Trade> orderedTrades;

  /// One equity value per trade, AFTER that trade's P/L.
  final List<double> equity;
}

EquityCurve equityCurve(
  List<Trade> trades, {
  double? startingBalance,
}) {
  if (trades.isEmpty) return const EquityCurve([], []);
  final ordered = [...trades]..sort((a, b) => a.closeTime.compareTo(b.closeTime));
  var equity = startingBalance ?? 0.0;
  final points = <double>[];
  for (final t in ordered) {
    equity += t.profitLoss;
    points.add(equity);
  }
  return EquityCurve(ordered, points);
}

/// Drawdown over an equity curve (P1-08.06): the deepest decline from
/// a previous peak, money and percent of that peak. Negative money,
/// positive percent. Zero when equity never declines.
class DrawdownStats {
  const DrawdownStats(this.maxDrawdownMoney, this.maxDrawdownPercent);

  /// Negative or 0.
  final double maxDrawdownMoney;

  /// 0..100.
  final double maxDrawdownPercent;
}

DrawdownStats drawdown(EquityCurve curve, {double? startingBalance}) {
  // The origin itself is a peak candidate: a loss on trade 1 is a
  // drawdown from the starting balance, not from nothing.
  var peak = startingBalance ?? 0.0;
  var ddMoney = 0.0, ddPercent = 0.0;
  for (var i = 0; i < curve.equity.length; i++) {
    final e = curve.equity[i];
    if (e > peak) {
      peak = e;
      continue;
    }
    final decline = e - peak;
    if (decline < ddMoney) {
      ddMoney = decline;
      ddPercent = peak == 0 ? 0 : -decline / peak * 100;
    }
  }
  return DrawdownStats(ddMoney, ddPercent);
}

/// One breakdown row (P1-08.07..10): aggregated P/L, count, win rate,
/// and average RR of the trades sharing one key (instrument, strategy,
/// session, emotion).
class BreakdownRow {
  const BreakdownRow({
    required this.key,
    required this.tradeCount,
    required this.totalProfitLoss,
    required this.winRate,
    required this.averageRiskReward,
  });

  final String key;
  final int tradeCount;
  final double totalProfitLoss;
  final double winRate;
  final double? averageRiskReward;
}

/// Shared breakdown engine: groups by [keyOf], skips null keys (never
/// fabricate an "Unassigned" bucket), sorts by total P/L descending so
/// the chart's best performer reads first.
List<BreakdownRow> _breakdown(
  List<Trade> trades,
  String? Function(Trade) keyOf,
) {
  final groups = <String, List<Trade>>{};
  for (final t in trades) {
    final k = keyOf(t);
    if (k == null || k.isEmpty) continue;
    (groups[k] ??= []).add(t);
  }
  final rows = groups.entries.map((e) {
    final s = summarizeTrades(e.value);
    return BreakdownRow(
      key: e.key,
      tradeCount: s.totalTrades,
      totalProfitLoss: s.totalProfitLoss,
      winRate: s.winRate,
      averageRiskReward: s.averageRiskReward,
    );
  }).toList();
  rows.sort((a, b) => b.totalProfitLoss.compareTo(a.totalProfitLoss));
  return rows;
}

List<BreakdownRow> breakdownByInstrument(List<Trade> trades) =>
    _breakdown(trades, (t) => t.instrument);

List<BreakdownRow> breakdownByStrategy(List<Trade> trades) =>
    _breakdown(trades, (t) => t.strategy);

List<BreakdownRow> breakdownBySession(List<Trade> trades) =>
    _breakdown(trades, (t) => t.session);

List<BreakdownRow> breakdownByEmotion(List<Trade> trades) =>
    _breakdown(trades, (t) => t.emotion);

/// One heatmap cell (P1-08.11): every trade that closed in [weekday]
/// (ISO 1..7, Mon..Sun) during [hour] (0..23, local close time).
class HeatmapCell {
  const HeatmapCell({
    required this.weekday,
    required this.hour,
    required this.tradeCount,
    required this.totalProfitLoss,
  });

  final int weekday;
  final int hour;
  final int tradeCount;
  final double totalProfitLoss;
}

List<HeatmapCell> tradingHeatmap(List<Trade> trades) {
  final cells = <(int, int), HeatmapCell>{};
  for (final t in trades) {
    final k = (t.closeTime.weekday, t.closeTime.hour);
    final prev = cells[k];
    cells[k] = prev == null
        ? HeatmapCell(
            weekday: k.$1,
            hour: k.$2,
            tradeCount: 1,
            totalProfitLoss: t.profitLoss,
          )
        : HeatmapCell(
            weekday: prev.weekday,
            hour: prev.hour,
            tradeCount: prev.tradeCount + 1,
            totalProfitLoss: prev.totalProfitLoss + t.profitLoss,
          );
  }
  return cells.values.toList();
}

/// Day-level aggregation for calendar heatmap (P1-10)
class DaySummary {
  const DaySummary({
    required this.date,
    required this.trades,
    required this.totalProfitLoss,
    required this.winRate,
  });

  final DateTime date; // YYYY-MM-DD local
  final List<Trade> trades;
  final double totalProfitLoss;
  final double winRate;
}

Map<DateTime, DaySummary> groupByDate(List<Trade> trades) {
  final map = <DateTime, List<Trade>>{};
  for (final t in trades) {
    final local = t.closeTime.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    (map[d] ??= []).add(t);
  }

  return map.map((d, dayTrades) {
    final s = summarizeTrades(dayTrades);
    return MapEntry(
      d,
      DaySummary(
        date: d,
        trades: dayTrades,
        totalProfitLoss: s.totalProfitLoss,
        winRate: s.winRate,
      ),
    );
  });
}
