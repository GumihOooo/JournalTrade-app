import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/design/gumi.dart';
import '../../core/errors/failure.dart';
import '../journal/journal_provider.dart';
import '../settings/user_settings_provider.dart';
import 'domain/trade.dart';
import 'trade_detail_controller.dart';

/// Trade detail (P0-10.01..03, P0-10.12): Execution, Psychology, and
/// Reflection sections in separate frosted GlassCards. No screenshot
/// section ever — MT5 images are never stored (DATABASE.md §1, §9).
///
/// Reads from the shared journal state (no extra fetch); edit and
/// delete refresh it so the journal and dashboard follow (P0-10.07).
class TradeDetailScreen extends ConsumerWidget {
  const TradeDetailScreen({super.key, required this.tradeId});

  final String tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final currency = ref.watch(balanceCurrencyProvider);
    final journal = ref.watch(journalProvider);
    final trades = journal.valueOrNull ?? const <Trade>[];

    final trade = trades.where((t) => t.id == tradeId).firstOrNull;

    // S-7: while the journal is still loading, a missing trade is a
    // pending read — never "no longer available".
    if (trade == null && journal.isLoading) {
      return Scaffold(
        backgroundColor: c.bgPrimary,
        appBar: AppBar(
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/app/journal'),
          ),
          title: const Text('Trade Detail'),
        ),
        body: const LoadingState(message: 'Loading trade…'),
      );
    }

    if (trade == null) {
      // Deleted elsewhere or never owned: straight back to the journal.
      return Scaffold(
        backgroundColor: c.bgPrimary,
        appBar: AppBar(
          leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/app/journal'),
          ),
          title: const Text('Trade Detail'),
        ),
        body: const EmptyState(message: 'This trade is no longer available.'),
      );
    }

    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/app/journal'),
        ),
        title: Text(trade.instrument.toUpperCase()),
        // Action bar (P0-10.04, P0-10.08): edit + destructive delete.
        actions: [
          IconButton(
            tooltip: 'Edit trade',
            onPressed: () => context.push('/add-trade/manual', extra: trade),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete trade',
            onPressed: () => _confirmDelete(context, ref, trade),
            icon: const Icon(Icons.delete_outline),
            color: c.semanticLoss,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // --- Execution (P0-10.01) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Execution',
                    padding: const EdgeInsets.only(bottom: 16)),
                Row(
                  children: [
                    Text(trade.instrument.toUpperCase(),
                        style: theme.textTheme.titleLarge),
                    const SizedBox(width: 8),
                    _directionBadge(context, trade.direction),
                    const Spacer(),
                    ProfitLossText(
                      amount: trade.profitLoss,
                      currency: currency,
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Row('Direction', trade.direction.name.toUpperCase()),
                _Row('Account Type', trade.accountType.name.toUpperCase()),
                _Row('Entry Price', _fmt(trade.entryPrice)),
                _Row('Exit Price', _fmt(trade.exitPrice)),
                _Row('Stop Loss',
                    trade.stopLoss == null ? '—' : _fmt(trade.stopLoss!)),
                _Row('Take Profit',
                    trade.takeProfit == null ? '—' : _fmt(trade.takeProfit!)),
                _Row('Lot Size', '${_fmt(trade.lotSize)} lots'),
                _Row('Risk/Reward',
                    trade.riskReward == null ? '—' : trade.riskReward!.toStringAsFixed(2)),
                _Row('Open Time', _fmtDate(trade.openTime)),
                _Row('Close Time', _fmtDate(trade.closeTime)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Psychology (P0-10.02, M-7: Mistake lives here per
          //     DESIGN.md §5.7/§5.8) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Psychology',
                    padding: const EdgeInsets.only(bottom: 16)),
                _Row('Session', trade.session ?? '—'),
                _Row('Strategy', trade.strategy ?? '—'),
                _Row('Emotion', trade.emotion ?? '—'),
                _Row('Confluences',
                    trade.confluence.isEmpty ? '—' : trade.confluence.join(', ')),
                _Row('Mistake Tags',
                    trade.mistakeTags.isEmpty ? '—' : trade.mistakeTags.join(', ')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // --- Reflection (P0-10.03) ---
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Reflection',
                    padding: const EdgeInsets.only(bottom: 16)),
                _Row('Lesson Learned', trade.lessonLearned ?? '—'),
                _Row('Notes', trade.notes ?? '—'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);

  static String _fmtDate(DateTime v) {
    final local = v.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  // P0-10.09: destructive actions always confirm first (DESIGN.md §8).
  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Trade trade) async {
    final confirmed = await showGumiConfirmationDialog(
      context: context,
      title: 'Delete Trade',
      message:
          'This permanently deletes the ${trade.instrument.toUpperCase()} '
          'trade from your journal. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      // P0-10.10: repository delete + journal refresh.
      await ref.read(tradeDetailControllerProvider.notifier).delete(trade.id);
      // P0-10.11: back to the journal with a confirmation snackbar.
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Trade deleted.')));
      context.go('/app/journal');
    } on Failure catch (e) {
      if (context.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on AppwriteException catch (e) {
      if (context.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text(AppwriteFailureMapper.map(e).message)));
      }
    }
  }
}

/// Label + value row, muted label / primary value.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: c.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _directionBadge(BuildContext context, TradeDirection direction) {
  final c = context.gumiColors;
  final isBuy = direction == TradeDirection.buy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (isBuy ? c.semanticProfit : c.semanticLoss).withValues(alpha: 0.12),
        borderRadius: BorderRadius.all(Radius.circular(GumiRadius.control)),
        border: Border.all(
          color: (isBuy ? c.semanticProfit : c.semanticLoss).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Text(
        isBuy ? 'BUY' : 'SELL',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isBuy ? c.semanticProfit : c.semanticLoss,
        ),
      ),
    );
}
