import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'add_trade_routes.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/market/market_screen.dart';
import '../../features/onboarding/onboarding_screen.dart' as onboarding;
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/calculator/calculator_detail_screen.dart';
import '../../features/calculator/calculator_hub_screen.dart';
import '../../features/calculator/calculator_specs.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';

/// App router (P0-04.06/07, IMPLEMENTATION.md §9).
///
/// Redirect flow: booting → splash; onboarding not done → /onboarding;
/// no session → /auth/login; session → /app/dashboard. No loops: each
/// guard only redirects away from routes it does not own.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: _GoRouterRefresh(ref),
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const onboarding.OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/app/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/app/journal',
            builder: (context, state) => const JournalScreen(),
          ),
          GoRoute(
            path: '/app/market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/app/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        // P2-01: Trading Calculator hub + one route per calculator.
        path: '/settings/calculator',
        builder: (context, state) => const CalculatorHubScreen(),        routes: [
          for (final spec in calculatorSpecs)
            GoRoute(
              path: spec.id,
              builder: (context, state) =>
                  CalculatorDetailScreen(spec: spec),
            ),
        ],
      ),
      ...addTradeRoutes,
    ],
  );
  return router;
});

/// Sequential early-return guards: exactly ONE guard decides per
/// evaluation, so two guards can never bounce the user back and forth.
///
/// 1. Onboarding gate FIRST — while onboarding is incomplete, auth is
///    never evaluated. Anyone outside /onboarding lands there and stays.
/// 2. Auth gates only run after onboarding is done.
String? _redirect(Ref ref, GoRouterState state) {
  final onboardingAsync = ref.read(onboardingProvider);
  final path = state.uri.path;

  // Flag still loading: hold position (splash stays until prefs
  // resolve) instead of guessing false and flashing onboarding.
  if (!onboardingAsync.hasValue) {
    return path == '/splash' ? null : '/splash';
  }
  final onboarding = onboardingAsync.value!;

  // --- Guard 1: onboarding (owns everything until done) ---
  if (!onboarding) {
    return path == '/onboarding' ? null : '/onboarding';
    // No auth evaluation below this point until onboarding completes.
  }

  // --- Guard 2: auth (only reached when onboarding is done) ---
  final authStatus = ref.read(authStateProvider);
  if (authStatus == AuthStatus.unknown) {
    return path == '/splash' ? null : '/splash';
  }
  if (authStatus == AuthStatus.unauthenticated) {
    return path.startsWith('/auth') ? null : '/auth/login';
  }

  // --- Guard 3: authenticated user never sits on onboarding/auth ---
  // Splash is excluded: it leaves on its own after the Lottie finishes,
  // so a fast session probe never cuts the animation short.
  if (path == '/onboarding' || path.startsWith('/auth')) {
    return '/app/dashboard';
  }
  return null;
}

/// Bridges auth-state and onboarding-flag changes into GoRouter's
/// refresh, so redirects re-evaluate when async providers resolve.
class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh(Ref ref) {
    ref.listen<AuthStatus>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
    ref.listen<AsyncValue<bool>>(
      onboardingProvider,
      (_, _) => notifyListeners(),
    );
  }
}
