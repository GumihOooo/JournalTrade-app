import 'package:flutter/material.dart';

/// Shimmer loading placeholder (P2-05, DESIGN.md §5.14): a soft
/// highlight sweeping over the card's real shape — never a bare
/// spinner. Wrap any child widget; unshaped areas read as skeleton.
class GumiShimmer extends StatefulWidget {
  const GumiShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<GumiShimmer> createState() => _GumiShimmerState();
}

class _GumiShimmerState extends State<GumiShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        widget.baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlight = widget.highlightColor ?? theme.colorScheme.surface;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (bounds.width * 2) * (_ctrl.value - 0.5);
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradientTransform(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

/// Skeleton row matching the watchlist/quote row shape.
class ShimmerRow extends StatelessWidget {
  const ShimmerRow({super.key, this.height = 20, this.widthFraction = 1});

  final double height;
  final double widthFraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GumiShimmer(
      child: Container(
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFraction,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton card matching section card shapes.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GumiShimmer(
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
