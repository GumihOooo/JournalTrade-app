import 'package:flutter/material.dart';

import '../gumi_spacing_radius.dart';

/// GumiBook primary button: solid silver, dark text (DESIGN.md §3.1).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = _buildChild(context);

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: _wrap(FilledButton(onPressed: _effectiveOnPressed, child: child)),
      );
    }
    return _wrap(FilledButton(onPressed: _effectiveOnPressed, child: child));
  }

  Widget _wrap(Widget button) {
    // Keep height stable while loading (DESIGN.md §5.3: no double submit).
    return button;
  }

  VoidCallback? get _effectiveOnPressed => loading ? null : onPressed;

  Widget _buildChild(BuildContext context) {
    if (loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      );
    }
    return Text(label);
  }
}

/// GumiBook secondary button: outline style, no fill.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final child = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
          )
        : Text(label);

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(onPressed: onPressed, child: child),
      );
    }
    return OutlinedButton(onPressed: onPressed, child: child);
  }
}

/// GumiBook destructive button: semantic loss red.
/// Destructive actions must always confirm first (DESIGN.md §8).
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.expanded = false,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final loss = Theme.of(context).colorScheme.error;

    final style = filled
        ? FilledButton.styleFrom(
            backgroundColor: loss,
            foregroundColor: Colors.black,
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
            ),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: loss,
            minimumSize: const Size(64, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            side: BorderSide(color: loss),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(GumiRadius.input)),
            ),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          );

    final button = filled
        ? FilledButton(style: style, onPressed: onPressed, child: Text(label))
        : OutlinedButton(style: style, onPressed: onPressed, child: Text(label));

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
