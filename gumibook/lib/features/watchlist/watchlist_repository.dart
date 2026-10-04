// ignore_for_file: deprecated_member_use
// Classic Databases API is deliberate (see trade_repository note).
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/config/appwrite_config.dart';
import '../../core/providers/appwrite_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../trades/trade_repository.dart' show ownerPermissions;
import 'watchlist_item.dart';

export 'watchlist_item.dart';

/// Watchlist CRUD (P2-04.01..05, DATABASE.md §8).
///
/// One document per (userId, instrument). Duplicate prevention is the
/// pre-check + friendly failure here; a server-side unique index on
/// (userId, instrument) is the long-term backstop.
class WatchlistRepository {
  WatchlistRepository(this._ref);

  final Ref _ref;

  Databases get _db => _ref.read(appwriteDatabasesProvider);

  Future<String> _userId() async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw StateError('Not authenticated');
    return user.$id;
  }

  /// All of the current user's instruments, sorted by `sortOrder` then
  /// instrument name (P2-04.05). Foreign rows never appear — server
  /// permissions + userId filter.
  Future<List<WatchlistItem>> list() async {
    final userId = await _userId();
    try {
      final docList = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.watchlistCollectionId,
        queries: [Query.equal('userId', userId)],
      );
      final items = docList.documents.map(_fromDocument).toList()
        ..sort((a, b) {
          final sa = a.sortOrder, sb = b.sortOrder;
          if (sa != sb) return (sa ?? _maxInt).compareTo(sb ?? _maxInt);
          return a.instrument.compareTo(b.instrument);
        });
      return items;
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  static const int _maxInt = 1 << 31;

  /// Adds [raw] (P2-04.02). Trims and uppercases for storage.
  /// Throws [ArgumentError] on empty input and
  /// [DuplicateInstrumentFailure] when the user already tracks it
  /// (case-insensitive, P2-04.04).
  Future<WatchlistItem> addInstrument(String raw) async {
    final instrument = raw.trim().toUpperCase();
    if (instrument.isEmpty) {
      throw ArgumentError.value(raw, 'instrument', 'must not be empty');
    }
    final userId = await _userId();
    final existing = await list();
    if (existing.any((i) => i.instrument == instrument)) {
      throw DuplicateInstrumentFailure(instrument);
    }
    var max = 0;
    for (final i in existing) {
      if (i.sortOrder != null && i.sortOrder! > max) max = i.sortOrder!;
    }
    try {
      final doc = await _db.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.watchlistCollectionId,
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'instrument': instrument,
          'sortOrder': max + 1,
        },
        permissions: ownerPermissions(userId),
      );
      return _fromDocument(doc);
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Removes the current user's row for [instrument] (P2-04.03).
  /// Missing instrument = idempotent no-op.
  Future<void> removeInstrument(String instrument) async {
    final userId = await _userId();
    final wanted = instrument.trim().toUpperCase();
    try {
      final docList = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.watchlistCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.equal('instrument', wanted),
        ],
      );
      for (final doc in docList.documents) {
        await _db.deleteDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.watchlistCollectionId,
          documentId: doc.$id,
        );
      }
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  WatchlistItem _fromDocument(models.Document doc) {
    final d = doc.data;
    return WatchlistItem(
      id: doc.$id,
      userId: d['userId'] as String? ?? '',
      instrument: d['instrument'] as String? ?? '',
      sortOrder: (d['sortOrder'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(doc.$createdAt),
    );
  }
}

final watchlistRepositoryProvider =
    Provider<WatchlistRepository>((ref) => WatchlistRepository(ref));
