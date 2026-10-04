import 'package:flutter/material.dart';

import '../gumi_colors.dart';
import 'gumi_buttons.dart';
/// Confirmation dialog for destructive actions (DESIGN.md §8).
/// Always explains the impact before the action runs.
Future<bool> showGumiConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        destructive
            ? DestructiveButton(
                label: confirmLabel,
                onPressed: () => Navigator.pop(dialogContext, true),
              )
            : FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(confirmLabel),
              ),
      ],
    ),
  );
  return result ?? false;
}

/// Profit/loss semantic text (DESIGN.md §2.4, §8).
///
/// Color is semantic only. Never color-only: prefix + sign keep
/// meaning when color is not perceivable.
class ProfitLossText extends StatelessWidget {
  const ProfitLossText({
    super.key,
    required this.amount,
    this.currency,
    this.style,
    this.showSign = true,
  });

  final double amount;
  final String? currency;
  final TextStyle? style;
  final bool showSign;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color color;
    final String prefix;
    if (amount > 0) {
      color = GumiColors.dark.semanticProfit;
      prefix = '+';
    } else if (amount < 0) {
      color = scheme.error;
      prefix = '';
    } else {
      color = theme.colorScheme.onSurfaceVariant;
      prefix = '';
    }

    final value = amount.toStringAsFixed(2);
    final text = currency == null ? value : '$value $currency';

    return Text(
      showSign && amount != 0 ? '$prefix$text' : text,
      style: (style ?? theme.textTheme.titleMedium)?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontFeatures: _tabular,
      ),
    );
  }
}
