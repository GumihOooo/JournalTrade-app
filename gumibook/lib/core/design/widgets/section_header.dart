import 'package:flutter/material.dart';

/// Shared section header (DESIGN.md §6 `SectionHeader`, P0-08.02).
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.padding = const EdgeInsets.only(top: 24, bottom: 12),
  });

  final String title;
  final String? subtitle;

  /// Outer padding; cards pass [EdgeInsets.zero] to sit flush inside
  /// their own GlassCard padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null)
            Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
