import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/gumi.dart';
import 'calculator_specs.dart';

/// P2-01.01 Calculator hub (DESIGN.md §5.16): ten calculators in a
/// minimal list. Standalone — nothing here touches the database.
class CalculatorHubScreen extends StatelessWidget {
  const CalculatorHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gumiColors;

    return Scaffold(
      backgroundColor: c.bgPrimary,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/app/settings'),
        ),
        title: const Text('Trading Calculator'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(GumiSpacings.md),
        children: [
          for (final spec in calculatorSpecs)
            Padding(
              padding: const EdgeInsets.only(bottom: GumiSpacings.sm),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: GumiSpacings.md,
                      vertical: GumiSpacings.xs,
                    ),
                    leading: Icon(spec.icon, color: c.accentSilver),
                    title: Text(spec.title),
                    subtitle: Text(
                      spec.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.textMuted),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(
                        '/settings/calculator/${spec.id}'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
