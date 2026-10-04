import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'gumi_scaffold.dart';

/// Shell host (P0-04.08..10): maps shell routes to GumiScaffold tabs
/// and wires the Add Trade action.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabByPath = {
    '/app/dashboard': 0,
    '/app/journal': 1,
    '/app/market': 2,
    '/app/settings': 3,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabByPath[location] ?? 0;

    return GumiScaffold(
      currentIndex: index,
      onDestinationSelected: (i) => context.go(_tabByPath.entries
          .firstWhere((e) => e.value == i)
          .key),
      onAddTrade: () => context.push('/add-trade'),
      body: child,
    );
  }
}
