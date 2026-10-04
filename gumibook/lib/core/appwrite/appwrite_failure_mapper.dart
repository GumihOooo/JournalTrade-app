import 'package:appwrite/appwrite.dart';

import '../errors/failure.dart';

/// Maps AppwriteException and other exceptions to typed failures
/// (IMPLEMENTATION.md §27). Never leaks server details to UI.
abstract final class AppwriteFailureMapper {
  static const _messagesByType = {
    'user_unauthorized': 'Invalid email or password.',
    'user_not_found': 'Invalid email or password.',
    'user_email_not_confirmed': 'Please confirm your email first.',
    'user_session_already_exists': 'A session already exists.',
    'general_unauthorized_scope':
        'You do not have permission to perform this action.',
    'general_rate_limit_exceeded': 'Too many requests. Try again shortly.',
  };

  static Failure map(Object error) {
    if (error is AppwriteException) {
      final byType = _messagesByType[error.type];
      if (byType != null) return AuthFailure(byType);
      final code = error.code;
      return switch (code) {
        401 => const AuthFailure('Authentication failed. Please log in again.'),
        403 => const PermissionFailure(
            'You do not have permission to perform this action.'),
        404 => const DatabaseFailure('The requested data was not found.'),
        int c when c >= 500 =>
          const DatabaseFailure('A server error occurred. Try again shortly.'),
        _ => const DatabaseFailure('Request failed. Try again shortly.'),
      };
    }
    if (error is FormatException) {
      return const DatabaseFailure('Received invalid data.');
    }
    // Unknown errors (SocketException etc. reach here) stay generic:
    // never leak raw transport/server detail to the UI.
    return const NetworkFailure('Network error. Check your connection.');
  }
}
