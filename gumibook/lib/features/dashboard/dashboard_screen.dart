import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/gumi.dart';
import '../../core/errors/failure.dart';
import '../journal/journal_provider.dart';
import '../settings/user_settings_provider.dart';
import 'analytics/analytics.dart';
import 'charts/equity_drawdown_charts.dart';
import 'charts/performance_breakdown.dart';
import 'charts/trading_calendar_heatmap.dart';
import 'charts/trading_heatmap.dart';

/// Dashboard base (P0-11.01..08): Balance (optional), Total P/L, and
/// the Win Rate / Avg RR / Trades row, all fed by the shared journal
/// provider. Empty state owns the screen until the first trade exists.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final journal = ref.watch(journalProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final settings = ref.watch(userSettingsProvider);

    return journal.when(
      loading: () => const LoadingState(message: 'Loading trades…'),
      error: (e, _) => ErrorState(
        // Failure carries a UI-safe message; anything else stays generic.
        message: e is Failure ? e.message : 'Could not load trades.',
        onRetry: () => ref.read(journalProvider.notifier).refresh(),
      ),
      data: (trades) {
        if (trades.isEmpty) {
          // P0-11.07/08: empty journal — one clear action out.
          return EmptyState(
            message: 'Start your trading journal by adding your first trade.',
            actionLabel: 'Add Trade',
            onAction: () => context.push('/add-trade'),
          );
        }
        final balance = settings.valueOrNull;
        final showBalance = balance?.startingBalance != null;
        final currency = balance?.balanceCurrency ?? 'USD';
        final startingBalance = balance?.startingBalance;
        final curve = equityCurve(trades, startingBalance: startingBalance);
        final dd = drawdown(curve, startingBalance: startingBalance);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (showBalance) ...[
              // P0-11.02: Balance only when a starting balance is set
              // (DATABASE.md §13 — hidden, not zero, when unset).
              MetricCard(
                label: 'Balance',
                icon: Icons.account_balance_wallet_outlined,
                value: (balance!.startingBalance! + stats.totalProfitLoss)
                    .toStringAsFixed(2),
                suffix: currency,
              ),
              const SizedBox(height: 12),
            ],
            MetricCard(
              label: 'Total P/L',
              icon: Icons.show_chart,
              glowColor: stats.totalProfitLoss >= 0
                  ? c.cardGlowProfit
                  : c.cardGlowLoss,
              customValue: ProfitLossText(
                amount: stats.totalProfitLoss,
                currency: currency,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'Win Rate',
                    icon: Icons.pie_chart_outline,
                    value: '${stats.winRate.toStringAsFixed(1)}%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Avg RR',
                    icon: Icons.balance_outlined,
                    // P0-11.05: placeholder dash while no RR exists.
                    value: stats.averageRiskReward?.toStringAsFixed(2) ?? '—',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    label: 'Trades',
                    icon: Icons.format_list_bulleted,
                    value: '${stats.totalTrades}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // P1-09.02: Equity Curve (origin = starting balance or 0).
            ChartContainer(
              title: 'Equity Curve',
              trailing: ProfitLossText(
                amount: curve.equity.isEmpty ? 0 : curve.equity.last,
                currency: currency,
                style: theme.textTheme.bodyMedium!,
              ),
              child: EquityCurveChart(
                trades: trades,
                startingBalance: startingBalance,
              ),
            ),
            const SizedBox(height: 12),
            // P1-09.03: Drawdown (deepest decline from peak).
            ChartContainer(
              title: 'Drawdown',
              trailing: Text(
                dd.maxDrawdownMoney == 0
                    ? 'No drawdown'
                    : '${dd.maxDrawdownPercent.toStringAsFixed(1)}% peak',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: c.semanticLoss),
              ),
              child: DrawdownChart(
                trades: trades,
                startingBalance: startingBalance,
              ),
            ),
            const SizedBox(height: 12),
            // P1-09.05..08: the four performance breakdowns. Empty
            // breakdowns are hidden — an "empty" chart card is noise
            // (P1-09.10: the screen-level empty state covers zero
            // trades; section-level gaps just don't render).
            if (breakdownByInstrument(trades).isNotEmpty)
              _breakdownCard(
                  'Instrument Performance', breakdownByInstrument(trades)),
            if (breakdownByStrategy(trades).isNotEmpty)
              _breakdownCard(
                  'Strategy Performance', breakdownByStrategy(trades)),
            if (breakdownBySession(trades).isNotEmpty)
              _breakdownCard(
                  'Session Performance', breakdownBySession(trades)),
            if (breakdownByEmotion(trades).isNotEmpty)
              _breakdownCard(
                  'Emotion Performance', breakdownByEmotion(trades)),
            const SizedBox(height: 12),
            // Trading Calendar Heatmap
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRADING CALENDAR',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: c.textMuted,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TradingCalendarHeatmap(
                    trades: trades,
                    currency: currency,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // P1-09.09: Trading heatmap — fixed 12px cells, 318px total
            // width fits any phone (DESIGN.md §9); height covers
            // 7 rows + legend without clipping.
            ChartContainer(
              title: 'Trading Heatmap',
              height: 168,
              child: TradingHeatmap(cells: tradingHeatmap(trades)),
            ),
            const SizedBox(height: 24),
            Text(
              // Newest trade first (server ordering).
              'Latest: ${trades.first.instrument.toUpperCase()} '
              '${trades.first.direction.name.toUpperCase()} '
              '${trades.first.profitLoss.toStringAsFixed(2)} $currency',
              style: theme.textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ],
        );
      },
    );
  }

  /// One GlassCard per breakdown (P1-09.04) — the shell is shared, the
  /// rows come from analytics.dart pure functions.
  Widget _breakdownCard(String title, List<BreakdownRow> rows) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ChartContainer(
          title: title,
          height: rows.length * 44 + 16,
          child: PerformanceBreakdown(rows: rows),
        ),
      );
}

/// Shared metric tile (P0-11.02..06): frosted GlassCard, label above a
/// large tabular value. Either [value] (plain text) or [customValue]
/// (e.g. ProfitLossText) — never both.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    this.value,
    this.suffix,
    this.customValue,
    this.icon,
    this.glowColor,
  });

  final String label;
  final String? value;
  final String? suffix;
  final Widget? customValue;
  final IconData? icon;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      glowColor: glowColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.borderSubtle),
                  ),
                  child: Icon(icon, size: 13, color: c.textMuted),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c.textMuted,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (customValue != null)
            customValue!
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    suffix!,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: c.textMuted),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
