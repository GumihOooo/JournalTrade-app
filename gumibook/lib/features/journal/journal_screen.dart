import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/gumi.dart';
import '../../core/errors/failure.dart';
import '../settings/user_settings_provider.dart';
import '../trades/domain/trade.dart';
import 'journal_provider.dart';

/// Journal screen (P0-09.01..21): search, filter chips, sort sheet,
/// and the reactive newest-first trade list. All filtering/sorting is
/// local and reactive — the provider list stays the single source.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final _search = TextEditingController();
  JournalFilter _filter = const JournalFilter();
  JournalSort _sort = JournalSort.newest;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Server fetches newest-first; local sort overlays any of the five
  /// options without re-fetching.
  List<Trade> _visible(List<Trade> trades) =>
      sortTrades(filterTrades(trades, _filter, _search.text), _sort);

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    final journal = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      hintText: 'Search instrument, strategy, notes…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // P0-09.17..20: sort opens a glass bottom sheet.
                _SortButton(
                  sort: _sort,
                  onChanged: (s) => setState(() => _sort = s),
                ),
              ],
            ),
          ),
          // P0-09.09..16: horizontally scrollable filter chips.
          _FilterBar(
            filter: _filter,
            trades: journal.valueOrNull ?? const <Trade>[],
            onChanged: (f) => setState(() => _filter = f),
          ),
          Expanded(
            child: journal.when(
              loading: () => const LoadingState(message: 'Loading trades…'),
              error: (e, _) => ErrorState(
                message: e is Failure ? e.message : 'Could not load trades.',
                onRetry: () => ref.read(journalProvider.notifier).refresh(),
              ),
              data: (serverTrades) {
                if (serverTrades.isEmpty) {
                  // P0-09.04: empty journal — one clear action out.
                  return EmptyState(
                    message: 'No trades yet. Log your first trade.',
                    actionLabel: 'Add Trade',
                    onAction: () => context.push('/add-trade'),
                  );
                }
                final visible = _visible(serverTrades);
                if (visible.isEmpty) {
                  return const EmptyState(
                    message: 'No trades match your search or filters.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TradeListTile(
                        trade: visible[i],
                        currency: ref.read(balanceCurrencyProvider),
                        onTap: () =>
                            context.push('/trade/${visible[i].id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrollable filter bar (P0-09.09..16) inside a subtle
/// frosted strip. Options derive from the loaded trades so chips never
/// offer dead-ends.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.trades,
    required this.onChanged,
  });

  final JournalFilter filter;
  final List<Trade> trades;
  final ValueChanged<JournalFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final instruments = trades.map((t) => t.instrument.toUpperCase()).toSet();
    final strategies =
        trades.map((t) => t.strategy).whereType<String>().toSet();
    final sessions = trades.map((t) => t.session).whereType<String>().toSet();
    final emotions = trades.map((t) => t.emotion).whereType<String>().toSet();
    final mistakes = trades
        .expand((t) => t.mistakeTags)
        .toSet();

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      blur: 6,
      radius: 12,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          // Action chips first so the core filters (Date/Direction/
          // Outcome) are always visible; dataset chips follow.
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            _Chip(
              label: filter.dateRange == null ? 'Date' : 'Date ∙ filtered',
              active: filter.dateRange != null,
              icon: Icons.date_range_outlined,
              onTap: () => _pickDate(context),
            ),
            _Chip(
              label: filter.direction == null
                  ? 'Direction'
                  : filter.direction!.name.toUpperCase(),
              active: filter.direction != null,
              icon: Icons.swap_vert,
              onTap: () => _pickDirection(context),
            ),
            _Chip(
              // M-1: breakeven shows its own label, not 'Losses'.
              label: switch (filter.outcome) {
                null => 'Win/Loss',
                TradeOutcome.win => 'Wins',
                TradeOutcome.loss => 'Losses',
                TradeOutcome.breakeven => 'Break-even',
              },
              active: filter.outcome != null,
              // M-11: direction sign fits both sides of zero.
              icon: Icons.swap_vert,
              onTap: () => _pickOutcome(context),
            ),
            for (final i in instruments)
              _Chip(
                label: i,
                active: filter.instrument?.toUpperCase() == i,
                onTap: () => onChanged(filter.instrument?.toUpperCase() == i
                    ? filter.copyWith(instrumentNull: true)
                    : filter.copyWith(instrument: i)),
              ),
            for (final s in strategies)
              _Chip(
                label: s,
                active: filter.strategy == s,
                onTap: () => onChanged(
                    filter.strategy == s ? filter.copyWith(strategyNull: true) : filter.copyWith(strategy: s)),
              ),
            for (final s in sessions)
              _Chip(
                label: s,
                active: filter.session == s,
                onTap: () => onChanged(
                    filter.session == s ? filter.copyWith(sessionNull: true) : filter.copyWith(session: s)),
              ),
            for (final e in emotions)
              _Chip(
                label: e,
                active: filter.emotion == e,
                onTap: () => onChanged(
                    filter.emotion == e ? filter.copyWith(emotionNull: true) : filter.copyWith(emotion: e)),
              ),
            for (final m in mistakes)
              _Chip(
                label: m,
                active: filter.mistakeTag == m,
                onTap: () => onChanged(
                    filter.mistakeTag == m ? filter.copyWith(mistakeTagNull: true) : filter.copyWith(mistakeTag: m)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: filter.dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );
    if (picked != null) onChanged(filter.copyWith(dateRange: picked));
  }

  Future<void> _pickDirection(BuildContext context) async {
    final choice = await _optionSheet<TradeDirection>(
      context,
      title: 'Direction',
      options: const [TradeDirection.buy, TradeDirection.sell],
      labelOf: (d) => d.name.toUpperCase(),
    );
    if (choice != null) {
      onChanged(choice == filter.direction
          ? filter.copyWith(directionNull: true)
          : filter.copyWith(direction: choice));
    }
  }

  Future<void> _pickOutcome(BuildContext context) async {
    final choice = await _optionSheet<TradeOutcome>(
      context,
      title: 'Outcome',
      options: TradeOutcome.values,
      labelOf: (o) => switch (o) {
        TradeOutcome.win => 'Wins',
        TradeOutcome.loss => 'Losses',
        TradeOutcome.breakeven => 'Break-even',
      },
    );
    if (choice != null) {
      onChanged(choice == filter.outcome
          ? filter.copyWith(outcomeNull: true)
          : filter.copyWith(outcome: choice));
    }
  }

  Future<T?> _optionSheet<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
  }) {
    final c = context.gumiColors;
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GumiRadius.glass)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            // Small screens: scroll instead of overflow.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      title: Text(labelOf(o)),
                      trailing: _selectedMark(o),
                      onTap: () => Navigator.pop(sheetContext, o),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _selectedMark<T>(T o) {
    final bool selected;
    if (o is TradeDirection) {
      selected = filter.direction == o;
    } else if (o is TradeOutcome) {
      selected = filter.outcome == o;
    } else {
      selected = false;
    }
    return selected ? const Icon(Icons.check, size: 20) : null;
  }
}

/// Sort trigger (P0-09.17..20): icon button beside the search bar.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final JournalSort sort;
  final ValueChanged<JournalSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    // Active (non-default) sort shows an accent tint.
    final dirty = sort != JournalSort.newest;

    return IconButton(
      tooltip: 'Sort trades',
      onPressed: () => _openSheet(context),
      icon: Icon(
        Icons.sort,
        color: dirty ? c.accentSilver : theme.iconTheme.color,
      ),
      style: IconButton.styleFrom(
        backgroundColor: dirty ? c.surfaceGlass : c.bgSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
          side: BorderSide(color: dirty ? c.borderFocus : c.borderSubtle),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final c = context.gumiColors;
    final choice = await showModalBottomSheet<JournalSort>(
      context: context,
      backgroundColor: c.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GumiRadius.glass)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        const options = [
          (JournalSort.newest, 'Newest', 'Most recent close first'),
          (JournalSort.oldest, 'Oldest', 'Earliest close first'),
          (JournalSort.profitLossDesc, 'Highest P/L', 'Biggest profit first'),
          (JournalSort.profitLossAsc, 'Lowest P/L', 'Biggest loss first'),
          (JournalSort.riskRewardDesc, 'Highest RR', 'Best reward-to-risk first'),
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Sort by', style: theme.textTheme.titleMedium),
              ),
              // Small screens: scroll instead of overflow.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (value, label, hint) in options)
                      ListTile(
                        title: Text(label),
                        subtitle: Text(
                          hint,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: c.textMuted),
                        ),
                        trailing: sort == value
                            ? const Icon(Icons.check, size: 20)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (choice != null) onChanged(choice);
  }
}

/// One filter chip. Selected state uses gumi tokens: silver fill, dark
/// label — always paired with the label so state is not color-only.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: icon == null
          ? GumiFilterChip(
              label: label,
              selected: active,
              onSelected: (_) => onTap(),
            )
          : InputChip(
              label: text,
              avatar: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              selected: active,
              showCheckmark: false,
              onPressed: onTap,
              backgroundColor: scheme.surface,
              selectedColor: scheme.primary,
              side: BorderSide(color: active ? scheme.primary : scheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.all(Radius.circular(GumiRadius.control)),
              ),
              visualDensity: VisualDensity.compact,
            ),
    );
  }
}

/// P0-09.03: one trade row. Frosted GlassCard — backdrop-blur glass,
/// never liquid glass inside a scrollable list (DESIGN.md §3.2).
/// Tapping opens the trade detail (P0-10).
class TradeListTile extends StatelessWidget {
  const TradeListTile({
    super.key,
    required this.trade,
    this.currency = 'USD',
    this.onTap,
  });

  final Trade trade;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final localDate = trade.closeTime.toLocal();

    final isProfit = trade.profitLoss >= 0;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      glowColor: isProfit ? c.cardGlowProfit : c.cardGlowLoss,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GumiRadius.card),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          trade.instrument.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _DirectionBadge(direction: trade.direction),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Locale-aware short date + 24h time, local timezone.
                    '${MaterialLocalizations.of(context).formatShortDate(localDate)} '
                    '${localDate.hour.toString().padLeft(2, '0')}:'
                    '${localDate.minute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.textSecondary),
                  ),
                  if (trade.riskReward != null)
                    Text(
                      'RR ${trade.riskReward!.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: c.textMuted),
                    ),
                  // M-8 (DESIGN.md §5.8): optional metadata — strategy
                  // preferred, session as fallback.
                  if (trade.strategy != null || trade.session != null)
                    Text(
                      trade.strategy ?? trade.session!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: c.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ProfitLossText(
              amount: trade.profitLoss,
              currency: currency,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// BUY/SELL badge. Never color-only — the label carries the meaning.
class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({required this.direction});

  final TradeDirection direction;

  @override
  Widget build(BuildContext context) {
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
}
