import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/gumi.dart';
import 'core/providers/auth_provider.dart';
import 'core/router/app_router.dart';

/// App bootstrap (P0-04.01): ProviderScope wraps everything; the
/// Appwrite client initializes once inside its provider (P0-04.02);
/// MaterialApp.router owns navigation (P0-04.06/07).
void main() {
  runApp(const ProviderScope(child: GumiBookApp()));
}

class GumiBookApp extends ConsumerWidget {
  const GumiBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Touch the auth provider so the session check starts immediately.
    ref.watch(authStateProvider);

    return MaterialApp.router(
      title: 'GumiBook',
      debugShowCheckedModeBanner: false,
      theme: GumiTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
