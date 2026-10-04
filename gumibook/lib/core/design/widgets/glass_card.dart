import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted translucent surface (DESIGN.md §3.2).
///
/// Use for bottom navigation, primary floating controls, summary
/// cards, and modals/sheets that need visual separation. Not for
/// every component.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius = 16,
    this.blur = 12,
    this.border,
    this.gradient,
    this.clipBehavior = Clip.antiAlias,
    this.elevation = 1,
    this.glowColor,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blur;
  final BoxBorder? border;
  final Gradient? gradient;
  final Clip clipBehavior;
  final double elevation;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35 * elevation.clamp(0.5, 2.0)),
            blurRadius: 18 * elevation,
            offset: Offset(0, 6 * elevation),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.65),
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface.withValues(alpha: 0.75),
                      theme.colorScheme.surface.withValues(alpha: 0.50),
                    ],
                  ),
              borderRadius: borderRadius,
              border: border ??
                  Border.all(
                    color: const Color(0x1FFFFFFF), // subtle bright edge
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
