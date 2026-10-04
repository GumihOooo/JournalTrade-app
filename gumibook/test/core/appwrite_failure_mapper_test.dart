import 'package:appwrite/appwrite.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/appwrite/appwrite_failure_mapper.dart';

void main() {
  test('maps credentials type to friendly AuthFailure', () {
    final f = AppwriteFailureMapper.map(
      AppwriteException('Invalid credentials', 401, 'user_unauthorized'),
    );
    expect(f.message, 'Invalid email or password.');
  });

  test('maps 401 to AuthFailure', () {
    final f = AppwriteFailureMapper.map(AppwriteException('nope', 401, 'x'));
    expect(f.message, 'Authentication failed. Please log in again.');
  });

  test('maps 403 to PermissionFailure', () {
    final f = AppwriteFailureMapper.map(AppwriteException('denied', 403, null));
    expect(f.message, 'You do not have permission to perform this action.');
  });

  test('maps 500 to DatabaseFailure', () {
    final f = AppwriteFailureMapper.map(AppwriteException('boom', 500, null));
    expect(f.message, 'A server error occurred. Try again shortly.');
  });

  test('maps unknown exception to NetworkFailure', () {
    final f = AppwriteFailureMapper.map(Exception('socket died'));
    expect(f.message, 'Network error. Check your connection.');
  });
}
