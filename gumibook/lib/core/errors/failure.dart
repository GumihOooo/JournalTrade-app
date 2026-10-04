/// Typed application failures (ARCHITECTURE.md §17).
/// UI never renders raw stack traces or backend details.
sealed class Failure {
  const Failure({required this.message});

  /// Human-readable, non-sensitive message safe to show in UI.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class AuthFailure extends Failure {
  const AuthFailure(String message) : super(message: message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(String message, {this.errors = const {}})
      : super(message: message);

  /// field name to error message.
  final Map<String, String> errors;
}

class NetworkFailure extends Failure {
  const NetworkFailure(String message) : super(message: message);
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(String message) : super(message: message);
}

class OcrFailure extends Failure {
  const OcrFailure(String message) : super(message: message);
}

class ImageTooBlurryFailure extends Failure {
  const ImageTooBlurryFailure(String message) : super(message: message);
}

class UnsupportedScreenshotFailure extends Failure {
  const UnsupportedScreenshotFailure(String message) : super(message: message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(String message) : super(message: message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(String message) : super(message: message);
}
