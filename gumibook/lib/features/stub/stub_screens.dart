import 'package:flutter/material.dart';

import '../../core/design/gumi.dart';


/// Placeholder screens for P0-04 routing. Real content lands in
/// later epics (onboarding P0-05, auth P0-06, journal P0-09, etc.).

class StubScreen extends StatelessWidget {
  const StubScreen(this.title, {super.key, this.ctaLabel, this.onCta});

  final String title;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Placeholder — coming in a later epic.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textMuted),
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 24),
            PrimaryButton(label: ctaLabel!, onPressed: onCta),
          ],
        ],
      ),
    );
  }
}


