import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/providers/appwrite_provider.dart';
import 'package:gumibook/core/providers/auth_provider.dart';
import 'package:gumibook/features/settings/user_settings_repository.dart';

/// P0-13.09 (audit K-2): random documentId + userId lookup + explicit
/// ownership verification. A squat doc (foreign or duplicate userId)
/// must read back as safe defaults and never poison the app.
void main() {
  late ProviderContainer container;
  late FakeDatabases db;

  setUp(() {
    db = FakeDatabases();
    container = ProviderContainer(overrides: [
      appwriteDatabasesProvider.overrideWithValue(db),
      currentUserProvider.overrideWith(
        (ref) async => models.User(
          $id: 'user-a',
          $createdAt: '',
          $updatedAt: '',
          name: '',
          registration: '',
          status: true,
          labels: const [],
          passwordUpdate: '',
          email: 'a@test.dev',
          emailVerification: false,
          phone: '',
          phoneVerification: false,
          mfa: false,
          prefs: models.Preferences(data: <String, dynamic>{}),
          targets: <models.Target>[],
          accessedAt: '',
        ),
      ),
    ]);
  });

  tearDown(() => container.dispose());

  models.Document doc(String id, String owner, {double? balance}) =>
      models.Document(
        $id: id,
        $sequence: '',
        $collectionId: 'c',
        $databaseId: 'd',
        $createdAt: '',
        $updatedAt: '',
        $permissions: const [],
        data: {
          'userId': owner,
          if (balance != null) 'startingBalance': balance,
        },
      );

  test('read uses userId lookup, not userId as documentId', () async {
    db.docs = [doc('random-id-not-userid', 'user-a', balance: 500)];

    final s = await container.read(userSettingsRepositoryProvider).read();

    expect(s.startingBalance, 500);
    // getDocument only ever receives the RANDOM doc id, never 'user-a'.
    expect(db.requestedDocumentIds, ['random-id-not-userid']);
    expect(db.lastQueries, isNotNull); // Query.equal('userId', ...)
  });

  test('foreign-owner doc reads as defaults (squat guard)', () async {
    db.docs = [doc('squat', 'attacker')];

    final s = await container.read(userSettingsRepositoryProvider).read();

    expect(s, const UserSettings()); // suspect data never rendered
  });

  test('duplicate userId docs read as defaults (split/squat)', () async {
    db.docs = [
      doc('d1', 'user-a', balance: 100),
      doc('d2', 'user-a', balance: 999999),
    ];

    final s = await container.read(userSettingsRepositoryProvider).read();

    expect(s, const UserSettings());
  });

  test('absent doc reads as defaults, no crash', () async {
    db.docs = [];

    final s = await container.read(userSettingsRepositoryProvider).read();

    expect(s, const UserSettings());
  });

  test('ensureDefault creates with random id, not userId', () async {
    db.docs = [];

    await container.read(userSettingsRepositoryProvider).ensureDefault();

    expect(db.createdDocumentIds, isNotEmpty);
    expect(db.createdDocumentIds.single, isNot('user-a'));
    expect(db.createdPermissions, isNotEmpty); // owner perms attached
  });

  test('ensureDefault is a no-op when the user already has a doc',
      () async {
    db.docs = [doc('mine', 'user-a')];

    await container.read(userSettingsRepositoryProvider).ensureDefault();

    expect(db.createdDocumentIds, isEmpty);
  });

  test('updateProfile patches the owned doc found by userId', () async {
    db.docs = [doc('mine', 'user-a', balance: 100)];

    await container
        .read(userSettingsRepositoryProvider)
        .updateProfile(startingBalance: 200, isBalanceEdit: true);

    expect(db.updatedDocumentIds, ['mine']);
  });

  // P2-03.04 / Bug 1: register creates the settings doc; Delete Account
  // must remove it. This test creates the doc for real (ensureDefault),
  // then deletes and asserts the doc is GONE from the store — not a
  // return-value assumption.
  test('deleteOwnDocument removes the doc created by ensureDefault',
      () async {
    db.docs = [];
    await container.read(userSettingsRepositoryProvider).ensureDefault();
    expect(db.docs, hasLength(1)); // settings doc now exists

    await container.read(userSettingsRepositoryProvider).deleteOwnDocument();

    expect(db.docs, isEmpty);
    expect(db.deletedDocumentIds.single, isNot('user-a')); // random id
  });

  test('deleteOwnDocument never touches a foreign-owner doc', () async {
    db.docs = [doc('squat', 'attacker')];

    await container.read(userSettingsRepositoryProvider).deleteOwnDocument();

    // Ownership guard (K-2): a foreign doc is not ours to delete.
    expect(db.deletedDocumentIds, isEmpty);
  });

  test('deleteOwnDocument is a no-op when no doc exists', () async {
    db.docs = [];

    await container.read(userSettingsRepositoryProvider).deleteOwnDocument();

    expect(db.deletedDocumentIds, isEmpty);
  });
}

// ignore_for_file: deprecated_member_use, use_null_aware_elements
/// In-memory Databases stub: only the surface the repository touches.
class FakeDatabases implements Databases {
  List<models.Document> docs = [];
  final createdDocumentIds = <String>[];
  final updatedDocumentIds = <String>[];
  final deletedDocumentIds = <String>[];
  final requestedDocumentIds = <String>[];
  final createdPermissions = <List<String>>[];
  List<String>? lastQueries;

  @override
  Future<models.DocumentList> listDocuments({
    required String databaseId,
    required String collectionId,
    List<String>? queries,
    String? transactionId,
    bool? total,
    int? ttl,
  }) async {
    lastQueries = queries;
    // Emulate server-side Query.equal('userId', x) + permissions scope.
    final wanted = queries
        ?.where((q) => q.startsWith('equal("userId"'))
        .map((q) => q.split('"')[3])
        .toList();
    var visible = docs;
    if (wanted != null && wanted.isNotEmpty) {
      visible = docs
          .where((d) => wanted.contains(d.data['userId'] as String?))
          .toList();
    }
    return models.DocumentList(
      total: visible.length,
      documents: visible,
    );
  }

  @override
  Future<models.Document> getDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    List<String>? queries,
    String? transactionId,
  }) async {
    requestedDocumentIds.add(documentId);
    final found = docs.where((d) => d.$id == documentId).firstOrNull;
    if (found == null) {
      throw AppwriteException('', 404, 'document_not_found');
    }
    return found;
  }

  @override
  Future<models.Document> createDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    required Map data,
    List<String>? permissions,
    String? transactionId,
  }) async {
    createdDocumentIds.add(documentId);
    createdPermissions.add(permissions ?? const []);
    final created = models.Document(
      $id: documentId,
      $sequence: '',
      $collectionId: collectionId,
      $databaseId: databaseId,
      $createdAt: '',
      $updatedAt: '',
      $permissions: permissions ?? const [],
      data: data.cast<String, dynamic>(),
    );
    docs = [...docs, created];
    return created;
  }

  @override
  Future<models.Document> updateDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    Map? data,
    List<String>? permissions,
    String? transactionId,
  }) async {
    updatedDocumentIds.add(documentId);
    final found = docs.where((d) => d.$id == documentId).first;
    return found;
  }

  @override
  Future<void> deleteDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    String? transactionId,
  }) async {
    deletedDocumentIds.add(documentId);
    docs = docs.where((d) => d.$id != documentId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unstubbed: ${invocation.memberName}');
}
