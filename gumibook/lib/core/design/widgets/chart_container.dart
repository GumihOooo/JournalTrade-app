import 'package:flutter/material.dart';

import '../gumi.dart';

/// Shared chart shell (DESIGN.md §6 `ChartContainer`, P1-09.02):
/// frosted GlassCard + SectionHeader + optional trailing value.
/// Charts never hardcode styles — tokens flow in from the theme.
class ChartContainer extends StatelessWidget {
  const ChartContainer({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.height = 200,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final String title;
  final String? subtitle;

  /// Small metric on the header row (e.g. max drawdown).
  final Widget? trailing;

  final Widget child;

  /// Chart body height; DESIGN.md §9: adaptive, mobile-first default.
  final double height;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: SectionHeader(title, padding: EdgeInsets.zero),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(height: height, width: double.infinity, child: child),
        ],
      ),
    );
  }
}
