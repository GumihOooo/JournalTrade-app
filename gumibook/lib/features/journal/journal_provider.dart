import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../trades/domain/trade.dart';
import '../trades/trade_repository.dart';

/// Journal state (P0-08.15, P0-09): the app-wide trade list.
///
/// `state` holds the freshest full list; save/delete flows call
/// [refresh] so every screen reading this provider sees new data.
///
/// S-2: the list walks every page — dashboard stats and journal
/// filters must see the whole dataset, not a server page window.
/// ponytail: one-shot full load; switch to lazy paging when a real
/// journal passes a few thousand trades.
class JournalController extends AsyncNotifier<List<Trade>> {
  @override
  Future<List<Trade>> build() async {
    if (ref.watch(authStateProvider) != AuthStatus.authenticated) {
      return const [];
    }
    return _load();
  }

  Future<void> refresh() async {
    // Keep the previous list visible during reload — a full-screen
    // spinner on every save reads as data loss.
    state = await AsyncValue.guard(() => _load());
  }

  Future<List<Trade>> _load() =>
      ref.read(tradeRepositoryProvider).listAll();
}

final journalProvider =
    AsyncNotifierProvider<JournalController, List<Trade>>(
        JournalController.new);

/// Sort options for the journal (P0-09.17..20). Mirrors TradeSort but
/// lives UI-side so local re-sorting never re-fetches.
enum JournalSort { newest, oldest, profitLossDesc, profitLossAsc, riskRewardDesc }

/// Active journal filters (P0-09.09..16). Null field = no filter.
class JournalFilter {
  const JournalFilter({
    this.dateRange,
    this.instrument,
    this.direction,
    this.strategy,
    this.session,
    this.emotion,
    this.mistakeTag,
    this.outcome,
  });

  /// Inclusive close-time window (local dates).
  final DateTimeRange? dateRange;
  final String? instrument;
  final TradeDirection? direction;
  final String? strategy;
  final String? session;
  final String? emotion;
  final String? mistakeTag;
  final TradeOutcome? outcome;

  bool get isEmpty => toStringKey() == const JournalFilter().toStringKey();

  /// Stable identity for equality in setState comparisons/tests.
  String toStringKey() =>
      '${dateRange?.start.toIso8601String() ?? ''}-'
      '${dateRange?.end.toIso8601String() ?? ''}|'
      '${instrument ?? ''}|${direction?.name ?? ''}|'
      '${strategy ?? ''}|${session ?? ''}|${emotion ?? ''}|'
      '${mistakeTag ?? ''}|${outcome?.name ?? ''}';

  JournalFilter copyWith({
    DateTimeRange? dateRange,
    bool dateRangeNull = false,
    String? instrument,
    bool instrumentNull = false,
    TradeDirection? direction,
    bool directionNull = false,
    String? strategy,
    bool strategyNull = false,
    String? session,
    bool sessionNull = false,
    String? emotion,
    bool emotionNull = false,
    String? mistakeTag,
    bool mistakeTagNull = false,
    TradeOutcome? outcome,
    bool outcomeNull = false,
  }) =>
      JournalFilter(
        dateRange: dateRangeNull ? null : (dateRange ?? this.dateRange),
        instrument: instrumentNull ? null : (instrument ?? this.instrument),
        direction: directionNull ? null : (direction ?? this.direction),
        strategy: strategyNull ? null : (strategy ?? this.strategy),
        session: sessionNull ? null : (session ?? this.session),
        emotion: emotionNull ? null : (emotion ?? this.emotion),
        mistakeTag: mistakeTagNull ? null : (mistakeTag ?? this.mistakeTag),
        outcome: outcomeNull ? null : (outcome ?? this.outcome),
      );
}

/// P0-09.09..16: pure filter, testable without widgets.
List<Trade> filterTrades(List<Trade> trades, JournalFilter f, String query) {
  final q = query.trim().toLowerCase();
  bool match(Trade t) {
    if (q.isNotEmpty &&
        !(t.instrument.toLowerCase().contains(q) ||
            (t.strategy ?? '').toLowerCase().contains(q) ||
            (t.notes ?? '').toLowerCase().contains(q))) {
      return false;
    }
    if (f.instrument != null &&
        t.instrument.toLowerCase() != f.instrument!.toLowerCase()) {
      return false;
    }
    if (f.direction != null && t.direction != f.direction) return false;
    if (f.strategy != null && t.strategy != f.strategy) return false;
    if (f.session != null && t.session != f.session) return false;
    if (f.emotion != null && t.emotion != f.emotion) return false;
    if (f.mistakeTag != null && !t.mistakeTags.contains(f.mistakeTag)) {
      return false;
    }
    if (f.outcome != null && t.outcome != f.outcome) return false;
    final range = f.dateRange;
    if (range != null) {
      final day = t.closeTime.toLocal();
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final end = DateTime(
          range.end.year, range.end.month, range.end.day, 23, 59, 59);
      if (day.isBefore(start) || day.isAfter(end)) return false;
    }
    return true;
  }

  return trades.where(match).toList();
}

/// P0-09.17..20: pure sort. Newest stays first when [newest] — server
/// already ordered by closeTime DESC.
List<Trade> sortTrades(List<Trade> trades, JournalSort sort) =>
    switch (sort) {
      JournalSort.newest => trades,
      JournalSort.oldest => trades.reversed.toList(),
      JournalSort.profitLossDesc =>
        [...trades]..sort((a, b) => b.profitLoss.compareTo(a.profitLoss)),
      JournalSort.profitLossAsc =>
        [...trades]..sort((a, b) => a.profitLoss.compareTo(b.profitLoss)),
      JournalSort.riskRewardDesc => [...trades]..sort((a, b) {
          final ar = a.riskReward ?? double.negativeInfinity;
          final br = b.riskReward ?? double.negativeInfinity;
          return br.compareTo(ar);
        }),
    };

/// Dashboard aggregate (P0-08.16, P0-11): derived metrics.
class DashboardStats {
  const DashboardStats({
    required this.totalTrades,
    required this.totalProfitLoss,
    required this.winRate,
    required this.averageRiskReward,
  });

  final int totalTrades;
  final double totalProfitLoss;
  /// 0..100; 0 when no trades.
  final double winRate;
  /// Null when no trade carries a riskReward value.
  final double? averageRiskReward;
}

/// Computed from the journal list — one source of truth, no extra fetch.
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final trades = ref.watch(journalProvider).valueOrNull ?? const <Trade>[];
  return computeStats(trades);
});

/// Pure aggregate over trades (testable without any provider/network).
DashboardStats computeStats(List<Trade> trades) {
  if (trades.isEmpty) {
    return const DashboardStats(
      totalTrades: 0,
      totalProfitLoss: 0,
      winRate: 0,
      averageRiskReward: null,
    );
  }
  final wins = trades.where((t) => t.profitLoss > 0).length;
  final rrTrades =
      trades.where((t) => t.riskReward != null).map((t) => t.riskReward!).toList();
  return DashboardStats(
    totalTrades: trades.length,
    totalProfitLoss: trades.fold(0, (sum, t) => sum + t.profitLoss),
    winRate: wins / trades.length * 100,
    averageRiskReward:
        rrTrades.isEmpty ? null : rrTrades.reduce((a, b) => a + b) / rrTrades.length,
  );
}
