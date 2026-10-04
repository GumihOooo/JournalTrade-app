import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gumibook/core/providers/appwrite_provider.dart';
import 'package:gumibook/core/providers/auth_provider.dart';
import 'package:gumibook/features/watchlist/watchlist_repository.dart';

/// P2-04: add/remove/duplicate-guard/sort-order against the real
/// repository shape (no network — in-memory Databases stub).
void main() {
  late ProviderContainer container;
  late FakeDb db;

  setUp(() {
    db = FakeDb();
    container = ProviderContainer(overrides: [
      appwriteDatabasesProvider.overrideWithValue(db),
      currentUserProvider.overrideWith((ref) async => user('user-a')),
    ]);
  });

  tearDown(() => container.dispose());

  models.Document doc(String id, String owner, String instrument,
          {int? sortOrder}) =>
      models.Document(
        $id: id,
        $sequence: '',
        $collectionId: 'watchlist',
        $databaseId: 'db',
        $createdAt: '',
        $updatedAt: '',
        $permissions: const [],
        data: {
          'userId': owner,
          'instrument': instrument,
          if (sortOrder != null) 'sortOrder': sortOrder,
        },
      );

  WatchlistRepository repo() =>
      container.read(watchlistRepositoryProvider);

  test('P2-04.02 addInstrument creates an owner-permissioned document',
      () async {
    db.docs = [doc('d1', 'user-a', 'EURUSD', sortOrder: 0)];

    final item = await repo().addInstrument('XAUUSD');

    expect(item.instrument, 'XAUUSD');
    expect(item.userId, 'user-a');
    expect(db.createdDocumentIds, isNotEmpty);
    // New item sorts after the existing tail.
    expect(db.lastCreatedSortOrder, 1);
    expect(db.createdPermissions.single, isNotEmpty);
  });

  test('P2-04.04 addInstrument throws on duplicate (case-insensitive)',
      () async {
    db.docs = [doc('d1', 'user-a', 'XAUUSD')];

    await expectLater(
      repo().addInstrument('xauusd'),
      throwsA(isA<DuplicateInstrumentFailure>()),
    );
    // Pre-check means no server create was attempted.
    expect(db.createdDocumentIds, isEmpty);
  });

  test('P2-04.03 removeInstrument deletes the owned document', () async {
    db.docs = [doc('d1', 'user-a', 'XAUUSD'), doc('d2', 'attacker', 'EURUSD')];

    await repo().removeInstrument('XAUUSD');

    expect(db.deletedDocumentIds, ['d1']);
  });

  test('removeInstrument on missing instrument is a no-op (idempotent)',
      () async {
    db.docs = [];

    await repo().removeInstrument('XAUUSD');

    expect(db.deletedDocumentIds, isEmpty);
  });

  test('P2-04.05 list returns user items sorted by sortOrder, then name',
      () async {
    db.docs = [
      doc('d1', 'user-a', 'XAUUSD', sortOrder: 1),
      doc('d2', 'user-a', 'EURUSD', sortOrder: 0),
      doc('d3', 'user-a', 'NAS100'), // null sortOrder sorts last
      doc('d4', 'attacker', 'SPX500', sortOrder: 0),
    ];

    final items = await repo().list();

    expect(items.map((i) => i.instrument).toList(),
        ['EURUSD', 'XAUUSD', 'NAS100']);
  });

  test('addInstrument trims input and rejects empty', () async {
    db.docs = [];
    await expectLater(
      repo().addInstrument('  '),
      throwsA(isA<ArgumentError>()),
    );
  });
}

models.User user(String id) => models.User(
      $id: id,
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
    );

/// Duplicate guard failure (P2-04.04) — not a crash, a friendly state.
// ignore_for_file: deprecated_member_use, use_null_aware_elements
/// In-memory Databases stub: only the watchlist surface.
class FakeDb implements Databases {
  List<models.Document> docs = [];
  final createdDocumentIds = <String>[];
  final createdPermissions = <List<String>>[];
  final deletedDocumentIds = <String>[];
  int? lastCreatedSortOrder;
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
    var visible = docs;
    // Emulate server-side Query.equal(...) for userId and instrument.
    for (final raw in queries ?? const <String>[]) {
      final q = jsonDecode(raw) as Map<String, dynamic>;
      if (q['method'] != 'equal') continue;
      final attr = q['attribute'] as String?;
      final values = (q['values'] as List?)?.cast<dynamic>() ?? const [];
      visible = visible
          .where((d) => values.contains(d.data[attr]))
          .toList();
    }
    return models.DocumentList(total: visible.length, documents: visible);
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
    lastCreatedSortOrder = data['sortOrder'] as int?;
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
