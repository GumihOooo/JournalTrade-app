/// Default watchlist (P2-05 revisi) — priority order per user's
/// trading style: index futures first, gold, then forex, crypto, and
/// macro gauges. Used as the one-tap seed set for a new watchlist.
library;

/// Priority-ordered instrument keys (see DESIGN.md §5.14).
const defaultWatchlistInstruments = <String>[
  'NQ', // primary index future (Nasdaq 100)
  'XAUUSD', // Gold — primary metal
  'YM', // index future (Dow 30)
  'ES', // index future (S&P 500)
  'EURUSD',
  'GBPUSD',
  'USDJPY',
  'BTCUSD',
  'DXY', // macro gauge (dollar index)
  'US10Y', // macro gauge (10y yield)
  'USOIL', // macro gauge (WTI crude)
];
