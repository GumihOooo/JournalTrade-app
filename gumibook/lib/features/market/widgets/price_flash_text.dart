
import 'package:flutter/material.dart';

import '../../../core/design/gumi.dart';

/// Price flash animation (P2-05, DESIGN.md §5.14): number blinks
/// green/red for ~600ms when the value changes, then settles. Pure
/// visual feedback — the value itself never fakes (null stays N/A).
class PriceFlashText extends StatelessWidget {
  const PriceFlashText({
    super.key,
    required this.value,
    this.style,
    this.currency,
  });

  final double? value;
  final TextStyle? style;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return Text('N/A',
          key: const ValueKey('price-na'),
          style: style?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    final theme = Theme.of(context);
    final c = context.gumiColors;
    final text = value!.toStringAsFixed(
        value! == value!.roundToDouble() ? 2 : (value! < 10 ? 4 : 2));
    final display = currency == null ? text : '$text $currency';

    // Flash on change: TweenAnimationBuilder keyed by value — a new key
    // restarts the tween; color fades from flash to normal.
    return TweenAnimationBuilder<double>(
      key: ValueKey(display),
      tween: Tween(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        // t=1 fresh change → strong flash; t=0 settled.
        final flash = (t.clamp(0.0, 1.0) * 0.85);
        return Text(
          display,
          key: const ValueKey('price-value'),
          style: (style ?? theme.textTheme.titleSmall)?.copyWith(
            color: Color.lerp(
              theme.colorScheme.onSurface,
              c.semanticProfit,
              flash,
            ),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }
}
