import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/gumi.dart';
import '../../core/errors/failure.dart';
import 'market_parsers.dart';
import 'market_session_clock.dart';
import 'market_providers.dart';
import '../watchlist/watchlist_provider.dart';
import 'widgets/price_flash_text.dart';

/// Market tab (P2-05, DESIGN.md §5.14): watchlist prices (Sugra via
/// gumibook-ai-gateway), TradingView chart widget, today-only economic
/// calendar (LSE), business news with GDELT market mood, Fear & Greed
/// (public), and the ICT kill-zone session clock.
///
/// Each section owns its own loading/available/no-data/unavailable/error
/// state — one failing section never blocks another.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          // Pull-to-refresh + haptic (DESIGN.md §5.14).
          unawaited(HapticFeedback.mediumImpact());
          await refreshAll(ref);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const _SessionClockSection(),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Watchlist',
              child: const _WatchlistSection(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Chart',
              child: const _ChartSection(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Economic Calendar (today)',
              child: const _CalendarSection(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'News',
              child: const _NewsSection(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Fear & Greed',
              child: const _FearGreedSection(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic section scaffolding
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title, padding: const EdgeInsets.only(bottom: 12)),
          child,
        ],
      ),
    );
  }
}

/// Friendly empty state: icon + copy, not bare text (DESIGN.md §5.14).
class _MarketEmptyState extends StatelessWidget {
  const _MarketEmptyState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(icon, size: 40, color: c.textMuted),
          const SizedBox(height: 10),
          Text(title, style: theme.textTheme.bodyLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.playlist_add, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section error row: message + retry. Never crashes the section.
class _MarketErrorState extends StatelessWidget {
  const _MarketErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _MarketEmptyState(
      icon: Icons.cloud_off_outlined,
      title: message,
    );
  }
}

// ---------------------------------------------------------------------------
// Session clock (pure UTC math — no API, always available)
// ---------------------------------------------------------------------------

class _SessionClockSection extends ConsumerWidget {
  const _SessionClockSection();

  static const _labels = {
    IctKillZone.asia: 'Asia',
    IctKillZone.london: 'London',
    IctKillZone.nyAm: 'NY AM',
    IctKillZone.nyPm: 'NY PM',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final state = ref.watch(sessionClockProvider).valueOrNull ??
        killZoneState(DateTime.now());

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          for (final session in IctKillZone.values) ...[
            Expanded(
              child: _SessionChip(
                label: _labels[session]!,
                active: state.active.contains(session),
              ),
            ),
          ],
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: state.isOverlap
                ? Container(
                    key: const ValueKey('overlap'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.semanticProfit.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('OVERLAP',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: c.semanticProfit,
                            fontWeight: FontWeight.bold)),
                  )
                : const SizedBox.shrink(key: ValueKey('no-overlap')),
          ),
        ],
      ),
    );
  }
}

class _SessionChip extends StatelessWidget {
  const _SessionChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(vertical: 6),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? c.semanticProfit.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: active ? c.semanticProfit : c.textMuted,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: active ? c.semanticProfit : c.textMuted,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Watchlist prices (P2-05.06)
// ---------------------------------------------------------------------------

class _WatchlistSection extends ConsumerWidget {
  const _WatchlistSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final prices = ref.watch(pricesProvider);

    return prices.when(
      loading: () => const Column(
        children: [
          ShimmerRow(widthFraction: 0.5),
          ShimmerRow(widthFraction: 0.4),
          ShimmerRow(widthFraction: 0.45),
        ],
      ),
      error: (e, _) => _MarketErrorState(
        message: e is Failure ? e.message : 'Prices unavailable.',
        onRetry: () => ref.invalidate(pricesProvider),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return _MarketEmptyState(
            icon: Icons.star_border_rounded,
            title: 'Your watchlist is empty',
            subtitle: 'Load the default set (NQ, Gold, YM, ES, FX, BTC, '
                'DXY, US10Y, USOIL) or add instruments one by one.',
            actionLabel: 'Load Default Watchlist',
            onAction: () =>
                ref.read(watchlistProvider.notifier).addDefaults(),
          );
        }
        return Column(
          children: [
            for (final row in rows)
              ListTile(
                key: Key('price-${row.instrument}'),
                contentPadding: EdgeInsets.zero,
                title: Text(row.instrument,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                subtitle: !row.isAvailable
                    ? Text('Market data unavailable',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textMuted))
                    : (row.instrument == 'XAUUSD'
                        ? Text('Gold futures proxy — not spot',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: c.textMuted))
                        : null),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PriceFlashText(
                      value: row.quote?.price,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 10),
                    _ChangeChip(quote: row.quote),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Change chip: green/red with sign; hidden when change is null.
class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.quote});

  final Quote? quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final pct = quote?.changePercent;
    if (pct == null) return const SizedBox.shrink();
    final up = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (up ? c.semanticProfit : c.semanticLoss).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${up ? '+' : ''}${pct.toStringAsFixed(2)}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: up ? c.semanticProfit : c.semanticLoss,
          fontWeight: FontWeight.bold,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TradingView chart widget (official embed, NOT a manual render)
// ---------------------------------------------------------------------------

class _ChartSection extends ConsumerStatefulWidget {
  const _ChartSection();

  @override
  ConsumerState<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends ConsumerState<_ChartSection> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    // WebView platform missing (some test hosts / old devices) → the
    // section degrades to the unavailable state instead of crashing.
    if (WebViewPlatform.instance != null) {
      _initWebView('CME_MINI:NQ1!');
    }
  }

  void _initWebView(String tvSymbol) {
    final config = _chartHtml(tvSymbol);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(config);
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final instruments =
        ref.watch(pricesProvider).valueOrNull ?? const <WatchlistQuote>[];
    final first = instruments.where((r) => r.isAvailable).isNotEmpty
        ? instruments.firstWhere((r) => r.isAvailable).instrument
        : (instruments.isNotEmpty ? instruments.first.instrument : null);
    final tvSymbol = first == null
        ? 'CME_MINI:NQ1!'
        : (instrumentToTradingViewSymbol(first) ?? 'CME_MINI:NQ1!');

    if (WebViewPlatform.instance == null) {
      return _MarketEmptyState(
        icon: Icons.show_chart,
        title: 'Chart not available on this device',
        subtitle: 'The TradingView chart needs a WebView-capable device.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Chart: $tvSymbol',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: c.textMuted)),
        SizedBox(
          height: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _controller == null
                ? const ShimmerCard(height: 320)
                : WebViewWidget(controller: _controller!),
          ),
        ),
      ],
    );
  }

  String _chartHtml(String symbol) => '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
    .tradingview-widget-container { height: 320px; }
  </style>
</head>
<body>
  <div class="tradingview-widget-container">
    <div class="tradingview-widget-container__widget" style="height:320px;"></div>
    <script src="https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js" async>
    {
      "autosize": true,
      "symbol": "$symbol",
      "interval": "60",
      "timezone": "Etc/UTC",
      "theme": "dark",
      "style": "1",
      "hide_top_toolbar": false,
      "hide_legend": false,
      "save_image": false,
      "calendar": false,
      "support_host": "https://www.tradingview.com"
    }
    </script>
  </div>
</body>
</html>
''';
}

// ---------------------------------------------------------------------------
// Economic calendar — today only (P2-05.07)
// ---------------------------------------------------------------------------

class _CalendarSection extends ConsumerWidget {
  const _CalendarSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final events = ref.watch(calendarTodayProvider);

    return events.when(
      loading: () => const ShimmerCard(height: 96),
      error: (e, _) => _MarketErrorState(
        message: e is Failure ? e.message : 'Calendar unavailable.',
        onRetry: () => ref.invalidate(calendarTodayProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _MarketEmptyState(
            icon: Icons.event_note_outlined,
            title: 'No economic events today',
            subtitle: 'High-impact events appear here as they are announced.',
          );
        }
        return Column(
          children: [
            for (final e in list.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(e.name, style: theme.textTheme.bodyLarge),
                subtitle: e.datetime == null
                    ? null
                    : Text(
                        '${e.country ?? ''} '
                        '${e.datetime!.toUtc().toString().substring(11, 16)} UTC',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.textMuted),
                      ),
                trailing: e.impact == null
                    ? null
                    : Text(e.impact!,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: (e.impact ?? '').toUpperCase() == 'HIGH'
                                ? c.semanticLoss
                                : c.textMuted)),
              ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// News + AI sentiment (P2-05.08, P2-05.09)
// ---------------------------------------------------------------------------

class _NewsSection extends ConsumerWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final bundle = ref.watch(currencyNewsProvider);

    return bundle.when(
      loading: () => const Column(
        children: [
          ShimmerRow(widthFraction: 0.8),
          ShimmerRow(widthFraction: 0.7),
          ShimmerRow(widthFraction: 0.75),
        ],
      ),
      error: (e, _) => _MarketErrorState(
        message: e is Failure ? e.message : 'News unavailable.',
        onRetry: () => ref.invalidate(currencyNewsProvider),
      ),
      data: (data) {
        final list = data.news;
        if (list.isEmpty) {
          return const _MarketEmptyState(
            icon: Icons.newspaper_outlined,
            title: 'No market news right now',
            subtitle: 'Headlines show up here as they publish.',
          );
        }
        return Column(
          children: [
            if (data.sentiment != null) ...[
              _NewsMoodBadge(sentiment: data.sentiment!),
              const SizedBox(height: 4),
            ],
            for (final item in list.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item.title,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(item.source ?? '',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.textMuted)),
              ),
          ],
        );
      },
    );
  }
}

/// GDELT market-mood chip (P2-05.09): one tone chart per news payload,
/// not per headline — no second AI round trip.
class _NewsMoodBadge extends StatelessWidget {
  const _NewsMoodBadge({required this.sentiment});

  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final (color, text) = switch (sentiment.label) {
      SentimentLabel.positive => (c.semanticProfit, 'MOOD: POSITIVE'),
      SentimentLabel.negative => (c.semanticLoss, 'MOOD: NEGATIVE'),
      SentimentLabel.neutral => (c.textMuted, 'MOOD: NEUTRAL'),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fear & Greed (P2-05.10) — public feargreedchart.com, no API key
// ---------------------------------------------------------------------------

class _FearGreedSection extends ConsumerWidget {
  const _FearGreedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final fg = ref.watch(fearGreedProvider);

    return fg.when(
      loading: () => const ShimmerCard(height: 80),
      error: (e, _) => _MarketErrorState(
        message: e is Failure ? e.message : 'Fear & Greed unavailable.',
        onRetry: () => ref.invalidate(fearGreedProvider),
      ),
      data: (index) {
        if (index == null) {
          return const _MarketEmptyState(
            icon: Icons.psychology_outlined,
            title: 'Fear & Greed index not available',
            subtitle: 'The general US market mood updates daily; check '
                'back later.',
          );
        }
        final value = index.value;
        final color = switch (index.rating) {
          'extreme fear' => c.semanticLoss,
          'fear' => c.semanticLoss,
          'neutral' => c.textMuted,
          _ => c.semanticProfit,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$value',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Text('General market mood: ${index.rating}',
                    style: theme.textTheme.titleSmall?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text('US stock market sentiment — not specific to any pair.',
                style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
                backgroundColor: c.borderSubtle,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }
}
