// ignore_for_file: deprecated_member_use
// Classic Databases API is deliberate: console collections are classic
// database shaped. Migrate to TablesDB when the backend does.
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/config/appwrite_config.dart';
import '../../core/providers/appwrite_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'domain/trade.dart';
import 'trade_mapper.dart';
import 'trade_validation.dart';

/// Owner-only document permissions (DATABASE.md §5).
/// No public read/write, no role:any. `userId` stays on the document as
/// defense-in-depth; Appwrite permissions are the access boundary.
List<String> ownerPermissions(String userId) => [
      Permission.read(Role.user(userId)),
      Permission.update(Role.user(userId)),
      Permission.delete(Role.user(userId)),
    ];

/// Trade CRUD against Appwrite (P0-07.06..11).
///
/// All calls are scoped to the signed-in user: server-side permissions
/// enforce it, and every write stamps the current user id client-side.
class TradeRepository {
  TradeRepository(this._ref);

  final Ref _ref;

  Databases get _db => _ref.read(appwriteDatabasesProvider);

  /// Resolves the user id once the account model is loaded — avoids the
  /// mid-flight null race between auth flip and account.get().
  Future<String> _userId() async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw StateError('Not authenticated');
    return user.$id;
  }

  /// Creates the trade with owner-only permissions. Returns the
  /// persisted entity (includes server-generated id and timestamps).
  Future<Trade> create(TradeDraft draft) async {
    assertValidTradeDraft(draft);
    final userId = await _userId();
    final trade = Trade(
      id: '',
      userId: userId,
      instrument: draft.instrument.trim(),
      direction: draft.direction,
      accountType: draft.accountType,
      entryPrice: draft.entryPrice,
      exitPrice: draft.exitPrice,
      stopLoss: draft.stopLoss,
      takeProfit: draft.takeProfit,
      lotSize: draft.lotSize,
      profitLoss: draft.profitLoss,
      riskReward: draft.riskReward,
      openTime: draft.openTime,
      closeTime: draft.closeTime,
      strategy: draft.strategy,
      session: draft.session,
      confluence: draft.confluence,
      emotion: draft.emotion,
      mistakeTags: draft.mistakeTags,
      lessonLearned: draft.lessonLearned,
      notes: draft.notes,
      inputMethod: draft.inputMethod,
    );

    try {
      final doc = await _db.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.tradesCollectionId,
        documentId: ID.unique(),
        data: TradeMapper.toDocument(trade),
        permissions: ownerPermissions(userId),
      );
      return TradeMapper.fromDocument(doc);
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  Future<Trade> update(Trade trade) async {
    assertValidTradeDraft(_draftFrom(trade));
    try {
      final doc = await _db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.tradesCollectionId,
        documentId: trade.id,
        data: TradeMapper.toDocument(trade),
      );
      return TradeMapper.fromDocument(doc);
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  Future<void> delete(String tradeId) async {
    try {
      await _db.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.tradesCollectionId,
        documentId: tradeId,
      );
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  Future<Trade?> getById(String tradeId) async {
    final userId = await _userId();
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.tradesCollectionId,
        documentId: tradeId,
      );
      final trade = TradeMapper.fromDocument(doc);
      // Defense-in-depth: never hand back another user's record.
      return trade.userId == userId ? trade : null;
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Journal list (DATABASE.md §12). Defaults: newest by closeTime.
  /// ponytail: Databases.* is deprecated in favor of TablesDB on
  /// Appwrite 1.8+, but the console collections are classic-database
  /// shaped; migrate when the backend does.
  Future<List<Trade>> list(
      {TradeSort sort = TradeSort.newest, int limit = 100}) async {
    final userId = await _userId();
    try {
      final docList = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.tradesCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc(_orderField(sort)),
          Query.limit(limit),
        ],
      );
      final trades = docList.documents.map(TradeMapper.fromDocument).toList();
      // ponytail: oldest reuses the newest index, reversed in memory;
      // per-sort server-side ASC orders if the list grows large.
      return sort == TradeSort.oldest ? trades.reversed.toList() : trades;
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Full dataset, newest first (S-2): walks every page until the
  /// server says there are no more. Dashboard stats and journal
  /// filters aggregate over this — a page window would silently
  /// truncate them past 100 trades.
  /// ponytail: sequential full load; lazy windowed paging when a real
  /// journal passes a few thousand trades.
  Future<List<Trade>> listAll() async {
    final trades = <Trade>[];
    String? cursor;
    while (true) {
      final page = await listPaged(limit: _pageSize, cursor: cursor);
      trades.addAll(page.trades);
      if (!page.hasMore || page.trades.isEmpty) break;
      cursor = page.lastId;
    }
    return trades;
  }

  static const _pageSize = 100;

  /// Paged journal list (P0-09.21). Cursor pagination: pass the last
  /// loaded document id as [cursor] for the next page. Appwrite always
  /// returns newest-first for a sort, so `oldest` reverses in memory —
  /// only the first page should use [oldest]; prefer [newest] + local
  /// re-sort for paged UIs.
  Future<TradePage> listPaged(
      {TradeSort sort = TradeSort.newest, int limit = 25, String? cursor}) async {
    final userId = await _userId();
    try {
      final docList = await _db.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.tradesCollectionId,
        queries: [
          Query.equal('userId', userId),
          Query.orderDesc(_orderField(sort)),
          Query.limit(limit),
          if (cursor != null) Query.cursorAfter(cursor),
        ],
      );
      return TradePage(
        trades: docList.documents.map(TradeMapper.fromDocument).toList(),
        // Total beyond the page means more pages exist.
        hasMore: docList.total > docList.documents.length,
        lastId: docList.documents.isEmpty ? null : docList.documents.last.$id,
      );
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  String _orderField(TradeSort sort) => switch (sort) {
        TradeSort.newest || TradeSort.oldest => 'closeTime',
        TradeSort.profitLoss => 'profitLoss',
        TradeSort.riskReward => 'riskReward',
      };
}

/// One page of trades (P0-09.21 cursor pagination).
class TradePage {
  const TradePage({
    required this.trades,
    required this.hasMore,
    this.lastId,
  });

  final List<Trade> trades;
  final bool hasMore;
  final String? lastId;
}

TradeDraft _draftFrom(Trade t) => TradeDraft(
      instrument: t.instrument,
      direction: t.direction,
      entryPrice: t.entryPrice,
      exitPrice: t.exitPrice,
      stopLoss: t.stopLoss,
      takeProfit: t.takeProfit,
      lotSize: t.lotSize,
      profitLoss: t.profitLoss,
      riskReward: t.riskReward,
      openTime: t.openTime,
      closeTime: t.closeTime,
      strategy: t.strategy,
      session: t.session,
      confluence: t.confluence,
      emotion: t.emotion,
      mistakeTags: t.mistakeTags,
      lessonLearned: t.lessonLearned,
      notes: t.notes,
      inputMethod: t.inputMethod,
    );

enum TradeSort { newest, oldest, profitLoss, riskReward }

final tradeRepositoryProvider =
    Provider<TradeRepository>((ref) => TradeRepository(ref));
