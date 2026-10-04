/// MT5 contract sizes per instrument (P0-08 auto P/L).
///
/// P/L = (exit - entry) x contractSize x lots x directionSign.
/// Unknown instruments are not guessed — the fields stay manual.
library;

const Map<String, double> instrumentContractSizes = {
  'XAUUSD': 100,
  'EURUSD': 100000,
  'GBPUSD': 100000,
  'BTCUSD': 1,
  'NAS100': 10,
  'SPX500': 10,
  'US30': 1,
};

/// Contract size for [instrument], null when unknown (stay manual).
double? contractSizeOf(String? instrument) =>
    instrument == null ? null : instrumentContractSizes[instrument.trim().toUpperCase()];

/// Auto P/L: (exit - entry) x contractSize x lots x direction.
/// Requires every input; null when anything is missing or unknown.
double? autoProfitLoss({
  required String? instrument,
  required bool isBuy,
  required double? entry,
  required double? exit,
  required double? lotSize,
}) {
  final size = contractSizeOf(instrument);
  if (size == null || entry == null || exit == null || lotSize == null) {
    return null;
  }
  return (exit - entry) * size * lotSize * (isBuy ? 1 : -1);
}

/// Auto RR: |exit - entry| / |entry - stopLoss|, null when incomplete
/// or the stop equals the entry (division by zero).
double? autoRiskReward({
  required double? entry,
  required double? exit,
  required double? stopLoss,
}) {
  if (entry == null || exit == null || stopLoss == null) return null;
  final risk = (entry - stopLoss).abs();
  if (risk == 0) return null;
  return (exit - entry).abs() / risk;
}
