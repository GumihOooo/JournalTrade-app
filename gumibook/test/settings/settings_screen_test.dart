import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:gumibook/core/providers/auth_provider.dart';
import 'package:gumibook/features/settings/settings_screen.dart';
import 'package:gumibook/features/settings/user_settings_provider.dart';
import 'package:gumibook/features/settings/user_settings_repository.dart';

/// Settings screen (P0-12): sections render, balance edit persists via
/// the controller (fake repository, no network), logout confirms.
void main() {
  FakeUserSettingsRepository? repo;

  Future<void> boot(
    WidgetTester tester, {
    UserSettings settings = const UserSettings(),
  }) async {
    final router = GoRouter(
      initialLocation: '/app/settings',
      routes: [
        GoRoute(
          path: '/app/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );
    // Create the fake eagerly — nothing else reads the provider, so a
    // lazy factory would leave `repo` null until too late.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Eager: touching the repo provider here (before the screen
          // builds) instantiates the fake so test assertions can read
          // it — nothing else reads the provider since the controller
          // is faked.
          userSettingsProvider.overrideWith((ref) async {
            ref.watch(userSettingsRepositoryProvider);
            return settings;
          }),
          // Keep the real Appwrite client out of the tree: the boot
          // probe would fire a network call and leave pending timers.
          authCheckProvider.overrideWith((ref) async => AuthStatus.authenticated),
          currentUserProvider.overrideWith((ref) async => null),
          settingsControllerProvider.overrideWith(() => _FakeController(
                () => repo,
              )),
          userSettingsRepositoryProvider.overrideWith((ref) =>
              repo ??= FakeUserSettingsRepository(ref)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders all four sections', (tester) async {
    await boot(tester);

    expect(find.text('Profile'), findsOneWidget);
    // Cards below the fold — search the whole tree.
    expect(find.text('Appearance', skipOffstage: false), findsOneWidget);
    expect(find.text('Trading Tools', skipOffstage: false), findsOneWidget);
    expect(find.text('Account', skipOffstage: false), findsOneWidget);
  });

  testWidgets('profile fields pre-fill from settings', (tester) async {
    await boot(
      tester,
      settings: const UserSettings(displayName: 'Gumi'),
    );

    final name = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Display Name'),
    );
    expect(name.controller!.text, 'Gumi');
    // Dark theme is locked and active (P0-12.08) — below the fold.
    expect(find.text('Dark Theme', skipOffstage: false), findsOneWidget);
    expect(find.text('LOCKED', skipOffstage: false), findsOneWidget);
  });

  testWidgets('save profile validates and persists balance', (tester) async {
    await boot(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display Name'),
      'Gumi',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Starting Balance'),
      '1000',
    );
    await tester.pump();

    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    expect(repo!.balance, 1000);
    expect(repo!.currency, 'USD');
    expect(find.text('Profile saved.'), findsOneWidget);
  });

  testWidgets('invalid balance shows error snackbar, no write',
      (tester) async {
    repo = null;
    await boot(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display Name'),
      'Gumi',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Starting Balance'),
      'abc',
    );
    await tester.pump();

    await tester.tap(find.text('Save Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Starting balance must be a number.'), findsOneWidget);
    expect(repo!.balance, isNull); // validation failed, no write
  });

  testWidgets('logout asks for confirmation first', (tester) async {
    await boot(tester);

    await tester.scrollUntilVisible(
      find.text('Log Out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // P0-12.11: destructive — dialog explains before acting.
    expect(find.text('Log Out'), findsWidgets); // tile + dialog title
    expect(
      find.text('You will need to sign in again to access your journal.'),
      findsOneWidget,
    );
  });

  testWidgets('no overflow at 320px width', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await boot(tester);

    expect(tester.takeException(), isNull);
  });
}

class _FakeController extends SettingsController {
  _FakeController(this.repoHandle);
  final FakeUserSettingsRepository? Function() repoHandle;

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    DateTime? tradingSince,
    bool clearTradingSince = false,
    double? startingBalance,
    bool clearStartingBalance = false,
    String? balanceCurrency,
    bool isBalanceEdit = false,
  }) async {
    await repoHandle()?.updateProfile(
      displayName: displayName,
          bio: bio,
          tradingSince: tradingSince,
          clearTradingSince: clearTradingSince,
          startingBalance: startingBalance,
          clearStartingBalance: clearStartingBalance,
          balanceCurrency: balanceCurrency,
          isBalanceEdit: isBalanceEdit,
        );
  }

  @override
  Future<void> clearStartingBalance() async =>
      repoHandle()?.clearStartingBalance();

  @override
  Future<void> changePassword(String newPassword) async {}
}

class FakeUserSettingsRepository extends UserSettingsRepository {
  FakeUserSettingsRepository(super.ref);

  double? balance;
  String? currency;
  bool balanceStamped = false;

  @override
  Future<UserSettings> read() async => const UserSettings();

  @override
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    DateTime? tradingSince,
    bool clearTradingSince = false,
    double? startingBalance,
    bool clearStartingBalance = false,
    String? balanceCurrency,
    bool isBalanceEdit = false,
  }) async {
    balance = clearStartingBalance ? null : startingBalance;
    currency = balanceCurrency;
    balanceStamped = isBalanceEdit;
  }

  @override
  Future<void> clearStartingBalance() async => balance = null;

  @override
  Future<void> changePassword(String newPassword) async {}
}
