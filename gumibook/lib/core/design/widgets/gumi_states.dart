import 'package:flutter/material.dart';

import '../gumi_spacing_radius.dart';

/// Loading state (DESIGN.md §6: `LoadingState`).
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: GumiSpacings.lg),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Empty state (DESIGN.md §6: `EmptyState`).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GumiSpacings.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: GumiSpacings.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: GumiSpacings.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry (DESIGN.md §6: `ErrorState`).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GumiSpacings.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: GumiSpacings.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: GumiSpacings.xl),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
