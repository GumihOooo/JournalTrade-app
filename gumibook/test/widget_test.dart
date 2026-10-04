import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumibook/core/design/gumi.dart';
import 'package:gumibook/core/providers/auth_provider.dart';
import 'helpers/journal_stub.dart';
import 'package:gumibook/features/shell/gumi_scaffold.dart';
import 'package:gumibook/features/settings/user_settings_provider.dart';
import 'package:gumibook/features/settings/user_settings_repository.dart';
import 'package:gumibook/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _bootApp({AuthStatus? authStatus}) => ProviderScope(
      overrides: [
        // Test env has no network; the session probe must not hang.
        authCheckProvider.overrideWith(
          (ref) async => authStatus ?? AuthStatus.unauthenticated,
        ),
        journalStub(),
        // Dashboard reads balance settings — no network in tests.
        userSettingsProvider.overrideWith(
          (ref) async => const UserSettings(),
        ),
      ],
      child: const GumiBookApp(),
    );

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pumpWidget(_bootApp());
  // Lottie half speed = 7s; fixed pumps, no settle (glass keeps animating).
  await tester.pump();
  await tester.pump(const Duration(seconds: 12));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('boot: onboarding not done → onboarding after splash',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpPastSplash(tester);

    expect(find.text('Track. Analyze. Improve.'), findsOneWidget);
  });

  testWidgets('onboarding done + no session → login', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await _pumpPastSplash(tester);

    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('onboarding Get Started persists flag and moves to login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpPastSplash(tester);
    expect(find.text('Track. Analyze. Improve.'), findsOneWidget);

    // Two pages: first tap advances, second tap persists + redirects.
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done'), isTrue);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('authenticated + onboarding done → dashboard shell',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_bootApp(authStatus: AuthStatus.authenticated));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(GumiScaffold), findsOneWidget);
    expect(find.byType(GumiScaffold), findsOneWidget);
  });

  testWidgets('design system components still render in shell stubs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GumiTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              ProfitLossText(amount: 250.5, currency: 'USD'),
              ProfitLossText(amount: -120.75, currency: 'USD'),
            ],
          ),
        ),
      ),
    );

    final win = tester.widget<Text>(find.byType(Text).first);
    expect(win.data, contains('+250.50'));
    final loss = tester.widget<Text>(find.byType(Text).last);
    expect(loss.data, contains('-120.75'));
  });

  testWidgets('ProfitLossText shows sign and not color-only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GumiTheme.dark(),
        home: const Scaffold(
          body: ProfitLossText(amount: 250.5, currency: 'USD'),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text).first);
    expect(text.data, contains('+'));
    expect(text.data, contains('250.50'));
  });

  testWidgets('password field has visibility toggle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: GumiTheme.dark(),
        home: const Scaffold(
          body: GumiPasswordField(label: 'Password'),
        ),
      ),
    );

    expect(find.byType(GumiPasswordField), findsOneWidget);
    final toggle = find.byType(IconButton);
    expect(toggle, findsOneWidget);
    expect(find.byTooltip('Show password'), findsOneWidget);
  });

  testWidgets('destructive confirmation dialog returns true on confirm',
      (tester) async {
    var confirmed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: GumiTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  confirmed = await showGumiConfirmationDialog(
                    context: context,
                    title: 'Delete trade?',
                    message: 'This trade will be permanently deleted.',
                    confirmLabel: 'Delete',
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete trade?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('numeric field uses numeric keyboard', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        theme: GumiTheme.dark(),
        home: Scaffold(body: NumericField(label: 'Lot Size', controller: controller)),
      ),
    );

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
  });
}
