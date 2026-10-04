import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appwrite_provider.dart';

/// Auth state (P0-04.05, P0-06, IMPLEMENTATION.md §10).
///
/// Boot: probes the persisted Appwrite session. login/register/logout
/// flip the state; GoRouter redirect reacts. No manual routing.
enum AuthStatus { unknown, unauthenticated, authenticated }

/// Session probe: resolves the persisted Appwrite session once at boot.
/// Kept separate so tests can override the network check.
///
/// S-6: a network failure is NOT a logout. Offline boot keeps the
/// status unknown so the user waits on splash instead of being dumped
/// on the login screen with a still-valid persisted session.
final authCheckProvider = FutureProvider<AuthStatus>((ref) async {
  try {
    await ref.read(appwriteAccountProvider).get();
    return AuthStatus.authenticated;
  } on AppwriteException catch (e) {
    // 401 = server answered: no valid session. Anything else
    // (network/DNS/socket) leaves the boot in limbo, not logout.
    if (e.code == 401) return AuthStatus.unauthenticated;
    return AuthStatus.unknown;
  } catch (_) {
    return AuthStatus.unknown;
  }
});

/// Auth actions + observable status.
final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);

class AuthController extends Notifier<AuthStatus> {
  Account get _account => ref.read(appwriteAccountProvider);

  /// True after an explicit login/logout set the state. The boot probe
  /// must never clobber an explicit state (slow-network race).
  bool _explicit = false;

  @override
  AuthStatus build() {
    // Adopt the boot probe's result when it resolves, but only while
    // nothing explicit happened yet (login/logout own the state then).
    ref.listen<AsyncValue<AuthStatus>>(authCheckProvider, (_, next) {
      if (_explicit || state != AuthStatus.unknown) return;
      next.whenData((status) => state = status);
    });
    return ref.read(authCheckProvider).valueOrNull ?? AuthStatus.unknown;
  }

  Future<void> login(String email, String password) async {
    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
    _explicit = true;
    state = AuthStatus.authenticated;
  }

  Future<void> register(String email, String password) async {
    await _account.create(
      userId: ID.unique(),
      email: email,
      password: password,
    );
    // Auto-login right after signup (IMPLEMENTATION.md §10).
    await login(email, password);
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
    _explicit = true;
    state = AuthStatus.unauthenticated;
  }
}

/// Sync view for guards (router, splash).
final authStateProvider = Provider<AuthStatus>((ref) {
  final status = ref.watch(authControllerProvider);
  // While the boot probe runs, controller state is unknown; after a
  // login/logout call it is the explicit value.
  return status;
});

/// Current user model, null when unauthenticated.
/// ponytail: refresh manually; no stream until profile editing (P0-12).
final currentUserProvider = FutureProvider<models.User?>((ref) async {
  final status = ref.watch(authStateProvider);
  if (status != AuthStatus.authenticated) return null;
  return ref.read(appwriteAccountProvider).get();
});

/// Synchronous user id for ownership stamping; null when unauthenticated
/// or while the account model is still loading. Repositories resolve
/// it asynchronously via `currentUserProvider.future` instead of
/// banging this mid-flight.
final currentUserIdProvider = Provider<String?>((ref) {
  final status = ref.watch(authStateProvider);
  if (status != AuthStatus.authenticated) return null;
  return ref.watch(currentUserProvider).valueOrNull?.$id;
});
