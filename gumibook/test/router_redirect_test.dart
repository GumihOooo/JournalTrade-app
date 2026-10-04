import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumibook/core/providers/auth_provider.dart';
import 'helpers/journal_stub.dart';
import 'package:gumibook/core/router/app_router.dart';
import 'package:gumibook/features/settings/user_settings_provider.dart';
import 'package:gumibook/features/settings/user_settings_repository.dart';
import 'package:gumibook/features/shell/gumi_scaffold.dart';
import 'package:gumibook/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Redirect-loop regression tests (P0-04.07).
///
/// Matrix: onboarding (not-done/done) x auth (unknown/unauth/authed).
/// Guards must be sequential: onboarding gate owns everything until
/// done; two guards never bounce the user back and forth.
void main() {
  Widget boot({
    required bool onboardingDone,
    required AuthStatus authStatus,
  }) =>
      ProviderScope(
        overrides: [
          // Test env has no network; session probe must be instant.
          authCheckProvider.overrideWith((ref) async => authStatus),
          journalStub(),
          // Dashboard reads balance settings — no network in tests.
          userSettingsProvider.overrideWith(
            (ref) async => const UserSettings(),
          ),
        ],
        child: const GumiBookApp(),
      );

  Future<void> settleBoot(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pump(); // first frame
    await tester.pump(const Duration(seconds: 12)); // lottie 7s + fade
    await tester.pump(const Duration(seconds: 1)); // route transition
  }

  group('redirect guard matrix', () {
    testWidgets(
        'onboarding not done + auth unknown → onboarding, no loop '
        '(regression: /onboarding => /auth/login => /onboarding)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await settleBoot(tester, boot(
        onboardingDone: false,
        authStatus: AuthStatus.unknown,
      ));

      expect(find.text('Track. Analyze. Improve.'), findsOneWidget);
      // Loop detector: go_router renders an error page on redirect loop.
      expect(find.textContaining('Page Not Found'), findsNothing);
      expect(find.textContaining('GoException'), findsNothing);
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets(
        'onboarding not done + unauthenticated → onboarding, stays there',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await settleBoot(tester, boot(
        onboardingDone: false,
        authStatus: AuthStatus.unauthenticated,
      ));

      expect(find.text('Track. Analyze. Improve.'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
    });

    testWidgets(
        'onboarding not done + authenticated → onboarding (gate owns entry)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await settleBoot(tester, boot(
        onboardingDone: false,
        authStatus: AuthStatus.authenticated,
      ));

      expect(find.text('Track. Analyze. Improve.'), findsOneWidget);
      expect(find.byType(GumiScaffold), findsNothing);
    });

    testWidgets('onboarding done + auth unknown → splash waits', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      await settleBoot(tester, boot(
        onboardingDone: true,
        authStatus: AuthStatus.unknown,
      ));

      expect(find.text('Track. Analyze. Improve.'), findsNothing);
      expect(find.text('Welcome Back'), findsNothing);
      expect(find.byType(GumiScaffold), findsNothing);
    });

    testWidgets('onboarding done + unauthenticated → login', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      await settleBoot(tester, boot(
        onboardingDone: true,
        authStatus: AuthStatus.unauthenticated,
      ));

      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('onboarding done + authenticated → dashboard shell',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      await settleBoot(tester, boot(
        onboardingDone: true,
        authStatus: AuthStatus.authenticated,
      ));

      expect(find.byType(GumiScaffold), findsOneWidget);
      expect(find.byType(GumiScaffold), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
      expect(find.text('Track. Analyze. Improve.'), findsNothing);
    });

    testWidgets(
        'Get Started: onboarding completes → auth gate takes over → login',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await settleBoot(tester, boot(
        onboardingDone: false,
        authStatus: AuthStatus.unauthenticated,
      ));
      expect(find.text('Track. Analyze. Improve.'), findsOneWidget);

      // Page 1: Get Started advances to page 2 (no persist yet).
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      final prefsAfterFirst = await SharedPreferences.getInstance();
      expect(prefsAfterFirst.getBool('onboarding_done'), isNull);

      // Page 2: Get Started persists the flag; redirect reacts → login.
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_done'), isTrue);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Track. Analyze. Improve.'), findsNothing);
    });

    testWidgets(
        'authenticated user hitting /auth route directly → dashboard',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      final container = ProviderContainer(overrides: [
        authCheckProvider.overrideWith(
          (ref) async => AuthStatus.authenticated,
        ),
        // Journal + user fetches must not hit the network in tests.
        journalStub(),
        currentUserProvider.overrideWith((ref) async => null),
        userSettingsProvider.overrideWith(
          (ref) async => const UserSettings(),
        ),
      ]);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      router.go('/auth/login');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const GumiBookApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 12));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GumiScaffold), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
    });
  });
}
