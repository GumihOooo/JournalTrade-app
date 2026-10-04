/// P2-01 Trading Calculator formulas (IMPLEMENTATION.md §21).
///
/// Pure functions, no widgets, no database. Every function returns
/// null when an input is missing, zero where meaningful, or invalid —
/// never throws, never NaN. UI converts null into "enter all fields".
library;

/// P2-01.02 Lot Size.
///
/// `stopDistance` is either a price distance (e.g. 0.01 for 10 pips on
/// a 4-decimal FX pair) or a pip distance — `pipValuePerLot` decides:
/// when null, `stopDistance` is treated as price distance and the
/// result is lots = riskAmount / stopDistance.
/// when given, result is lots = riskAmount / (stopDistance × pipValuePerLot).
double? lotSize({
  required double? balance,
  required double? riskPercent,
  required double? stopDistance,
  double? pipValuePerLot,
}) {
  if (balance == null || riskPercent == null || stopDistance == null) {
    return null;
  }
  if (balance <= 0 || stopDistance <= 0) return null;
  final riskAmount = balance * riskPercent / 100;
  final valuePerLot = pipValuePerLot == null
      ? stopDistance
      : stopDistance * pipValuePerLot;
  if (valuePerLot <= 0) return null;
  return riskAmount / valuePerLot;
}

/// P2-01.03 Position Size: lots × contract size (units).
double? positionSize({required double? lots, required double? contractSize}) {
  if (lots == null || contractSize == null) return null;
  if (lots <= 0 || contractSize <= 0) return null;
  return lots * contractSize;
}

/// P2-01.04 Risk (money): stopDistance × lots × pipValuePerLot.
double? riskMoney({
  required double? stopDistance,
  required double? lots,
  required double? pipValuePerLot,
}) {
  if (stopDistance == null || lots == null || pipValuePerLot == null) {
    return null;
  }
  if (stopDistance <= 0 || pipValuePerLot <= 0) return null;
  return stopDistance * lots * pipValuePerLot;
}

/// P2-01.05 Risk %: riskMoney / balance × 100.
double? riskPercent({required double? riskMoney, required double? balance}) {
  if (riskMoney == null || balance == null || balance <= 0) return null;
  return riskMoney / balance * 100;
}

/// P2-01.06 Pip Value: one-pip price distance × contract size × lots.
double? pipValue({
  required double? pipDistance,
  required double? contractSize,
  required double? lots,
}) {
  if (pipDistance == null || contractSize == null || lots == null) {
    return null;
  }
  if (contractSize <= 0 || lots <= 0) return null;
  return pipDistance * contractSize * lots;
}

/// P2-01.07 Margin: price × lots × contractSize / leverage.
double? margin({
  required double? price,
  required double? lots,
  required double? contractSize,
  required double? leverage,
}) {
  if (price == null || lots == null || contractSize == null ||
      leverage == null) {
    return null;
  }
  if (leverage <= 0 || contractSize <= 0 || lots <= 0) return null;
  return price * lots * contractSize / leverage;
}

/// P2-01.08 Profit: (exit − entry) × contractSize × lots, direction-aware.
double? profit({
  required double? entry,
  required double? exit,
  required double? contractSize,
  required double? lots,
  required bool isBuy,
}) {
  if (entry == null || exit == null || contractSize == null || lots == null) {
    return null;
  }
  if (contractSize <= 0 || lots <= 0) return null;
  return (exit - entry) * contractSize * lots * (isBuy ? 1 : -1);
}

/// P2-01.09 Drawdown (money): decline from peak, floored at 0.
double? drawdown({required double? peak, required double? current}) {
  if (peak == null || current == null || peak <= 0) return null;
  final dd = peak - current;
  return dd > 0 ? dd : 0;
}

/// P2-01.09 Drawdown %: decline from peak, floored at 0.
double? drawdownPercent({required double? peak, required double? current}) {
  if (peak == null || current == null || peak <= 0) return null;
  final dd = (peak - current) / peak * 100;
  return dd > 0 ? dd : 0;
}

/// P2-01.10 Compound: balance × (1 + gainPercent/100)^periods.
double? compound({
  required double? balance,
  required double? gainPercent,
  required double? periods,
}) {
  if (balance == null || gainPercent == null || periods == null) return null;
  if (balance <= 0 || periods <= 0) return null;
  final p = periods.round();
  return balance * _pow(1 + gainPercent / 100, p);
}

/// Integer exponent pow (no dart:math import needed for p ≥ 0).
double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

/// P2-01.11 Risk/Reward: |takeProfit − entry| / |entry − stopLoss|.
/// Entry equal to stop = no risk = null (same rule as P1-08 auto RR).
double? riskReward({
  required double? entry,
  required double? stopLoss,
  required double? takeProfit,
}) {
  if (entry == null || stopLoss == null || takeProfit == null) return null;
  final risk = (entry - stopLoss).abs();
  if (risk == 0) return null;
  return (takeProfit - entry).abs() / risk;
}
