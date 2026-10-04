import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gumibook/core/providers/appwrite_provider.dart';
import 'package:gumibook/main.dart';
import 'package:gumibook/features/shell/gumi_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAccount extends Account {
  _FakeAccount(super.client, {this.hasSession = false});

  static const validEmail = 'trader@gumi.dev';
  static const validPassword = 'password123';

  /// Boot probe result: false = starts at login screen.
  final bool hasSession;

  @override
  Future<models.Session> createEmailPasswordSession(
      {required String email, required String password}) async {
    if (email != validEmail || password != validPassword) {
      throw AppwriteException('Invalid credentials.', 401, 'user_unauthorized');
    }
    return _session(email);
  }

  models.Session _session(String email) => models.Session(
        $id: 's1',
        $createdAt: '',
        $updatedAt: '',
        userId: 'u1',
        expire: '',
        provider: 'email',
        providerUid: email,
        providerAccessToken: '',
        providerAccessTokenExpiry: '',
        providerRefreshToken: '',
        ip: '',
        osCode: '',
        osName: '',
        osVersion: '',
        clientType: '',
        clientCode: '',
        clientName: '',
        clientVersion: '',
        clientEngine: '',
        clientEngineVersion: '',
        deviceName: '',
        deviceBrand: '',
        deviceModel: '',
        countryCode: '',
        countryName: '',
        current: true,
        factors: [],
        secret: '',
        mfaUpdatedAt: '',
      );

  @override
  Future<models.User> get() async {
    if (!hasSession) {
      throw AppwriteException('No session.', 401, 'user_unauthorized');
    }
    return models.User(
      $id: 'u1',
      $createdAt: '',
      $updatedAt: '',
      name: '',
      registration: '',
      status: true,
      labels: [],
      passwordUpdate: '',
      email: validEmail,
      phone: '',
      emailVerification: true,
      phoneVerification: false,
      mfa: false,
      prefs: models.Preferences(data: {}),
      targets: [],
      accessedAt: '',
    );
  }
}

Widget _boot() => ProviderScope(
      overrides: [
        appwriteAccountProvider
            .overrideWithValue(_FakeAccount(Client(), hasSession: false)),
      ],
      child: const GumiBookApp(),
    );

void main() {
  testWidgets('login success flips auth state and lands on dashboard',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_boot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));

    expect(find.text('Welcome Back'), findsOneWidget);

    await tester.enterText(
        find.byType(EditableText).at(0), 'trader@gumi.dev');
    await tester.enterText(find.byType(EditableText).at(1), 'password123');
    await tester.tap(find.text('Log In'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(GumiScaffold), findsOneWidget);
    expect(find.text('Welcome Back'), findsNothing);
  });

  testWidgets('invalid credentials show snackbar, stay on auth',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_boot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));

    await tester.enterText(
        find.byType(EditableText).at(0), 'trader@gumi.dev');
    await tester.enterText(find.byType(EditableText).at(1), 'wrongpass1');
    await tester.tap(find.text('Log In'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('invalid email blocked by validation before submit',
      (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_boot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));

    await tester.enterText(find.byType(EditableText).at(0), 'notanemail');
    await tester.enterText(find.byType(EditableText).at(1), 'password123');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('short password blocked by validation', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_boot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));

    await tester.enterText(
        find.byType(EditableText).at(0), 'trader@gumi.dev');
    await tester.enterText(find.byType(EditableText).at(1), 'short');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
  });

  testWidgets('toggle switches to register mode', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_done': true});
    await tester.pumpWidget(_boot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));

    await tester.tap(find.text('No account? Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
