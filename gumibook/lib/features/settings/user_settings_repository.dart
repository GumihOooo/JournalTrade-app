// ignore_for_file: deprecated_member_use, use_null_aware_elements
// Classic Databases API is deliberate (see trade_repository note).
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appwrite/appwrite_failure_mapper.dart';
import '../../core/config/appwrite_config.dart';
import '../../core/errors/failure.dart';
import '../../core/providers/appwrite_provider.dart';
import '../../core/providers/auth_provider.dart';

/// Settings fields the Settings screen + Dashboard need (DATABASE.md §7.1).
class UserSettings {
  const UserSettings({
    this.displayName,
    this.bio,
    this.tradingSince,
    this.startingBalance,
    this.balanceCurrency,
    this.balanceSetAt,
  });

  final String? displayName;
  final String? bio;
  final DateTime? tradingSince;
  final double? startingBalance;
  final String? balanceCurrency;
  final DateTime? balanceSetAt;
}

/// User settings repository (P0-06.12, P0-13.09/K-2 hardening).
///
/// Document ID is RANDOM (`ID.unique()`), never the userId — a
/// predictable id let any authenticated user pre-create the victim's
/// settings doc (doc-squatting: poisoned defaults or permanent 403).
/// Lookup goes through `Query.equal('userId', userId)` with explicit
/// ownership verification; anything ambiguous (0 or >1 docs, foreign
/// owner) falls back to safe defaults instead of rendering suspect
/// data.
/// Scale note: 5-7 users; server-side create hook stays the proper
/// long-term fix.
class UserSettingsRepository {
  UserSettingsRepository(this._ref);

  final Ref _ref;

  Databases get _db => _ref.read(appwriteDatabasesProvider);

  /// Resolves the user id once the account model is loaded — avoids the
  /// mid-flight null race between auth flip and account.get().
  Future<String> _userId() async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw StateError('Not authenticated');
    return user.$id;
  }

  /// Creates the default settings document if none exists.
  /// Random documentId (P0-13.09): squatting a victim's id is now
  /// impossible; a duplicate userId field can only be created by the
  /// user themself, and [findOwnDocument] still verifies ownership.
  Future<void> ensureDefault() async {
    final userId = await _userId();
    final existing = await _findOwnDocument(userId);
    if (existing != null) return;
    try {
      await _db.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.userSettingsCollectionId,
        documentId: ID.unique(),
        data: {
          'userId': userId,
          'theme': 'dark',
          'dailyJournalReminder': false,
          'weeklyPerformanceSummary': false,
          'economicCalendarAlerts': false,
          'biometricLockEnabled': false,
        },
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );
    } on AppwriteException catch (e) {
      // Lost a legit create race (user double-tapped signup): fine.
      if (e.code == 409) return;
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Finds the caller's own settings doc by userId, or null when none
  /// or when anything looks off (P0-13.09 ownership verification).
  /// Server permissions already scope the list to readable docs, so
  /// docs from other users never appear; the explicit checks below
  /// stay as defense-in-depth against doc-squatting variants.
  Future<String?> _findOwnDocument(String userId) async {
    final docList = await _db.listDocuments(
      databaseId: AppwriteConfig.databaseId,
      collectionId: AppwriteConfig.userSettingsCollectionId,
      queries: [
        Query.equal('userId', userId),
        Query.limit(2),
      ],
    );
    if (docList.total != 1) return null; // 0 = absent; >1 = squat/split — treat as absent
    final doc = docList.documents.single;
    if (doc.data['userId'] != userId) return null; // ownership mismatch
    return doc.$id;
  }

  /// Reads the full settings document; empty fields when absent
  /// (P0-11.02, P0-12). Never renders suspect data (P0-13.09).
  ///
  /// A stored `startingBalance` of 0 is the "unset" sentinel (classic
  /// Databases cannot null an attribute via updateDocument) — read it
  /// back as null so 0 and absent behave identically everywhere.
  Future<UserSettings> read() async {
    final userId = await _userId();
    String? docId;
    try {
      docId = await _findOwnDocument(userId);
      if (docId == null) return const UserSettings();
      final doc = await _db.getDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.userSettingsCollectionId,
        documentId: docId,
      );
      if (doc.data['userId'] != userId) return const UserSettings();
      final d = doc.data;
      final balance = (d['startingBalance'] as num?)?.toDouble();
      return UserSettings(
        displayName: d['displayName'] as String?,
        bio: d['bio'] as String?,
        tradingSince: DateTime.tryParse(d['tradingSince'] as String? ?? ''),
        startingBalance: balance == 0 ? null : balance,
        balanceCurrency: d['balanceCurrency'] as String?,
        balanceSetAt: DateTime.tryParse(d['balanceSetAt'] as String? ?? ''),
      );
    } on AppwriteException catch (e) {
      // 404 = never created (or signup fire-and-forget lost the race):
      // fields stay empty, not an error screen.
      if (e.code == 404) return const UserSettings();
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Back-compat alias for the dashboard read path (P0-11.02).
  Future<UserSettings> readBalance() => read();

  /// Deletes the caller's own settings document (P2-03.04, DATABASE.md
  /// §14 Delete Account). No-op when none exists. Never touches anyone
  /// else's doc — lookup goes through the ownership-verified
  /// `_findOwnDocument`.
  Future<void> deleteOwnDocument() async {
    final userId = await _userId();
    final docId = await _findOwnDocument(userId);
    if (docId == null) return;
    try {
      await _db.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.userSettingsCollectionId,
        documentId: docId,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) return; // already gone — idempotent
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Patches profile fields (P0-12.04..06). Null values are omitted —
  /// Appwrite keeps the stored value; explicit clearing goes through
  /// [clearStartingBalance].
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
    final userId = await _userId();
    String? docId = await _findOwnDocument(userId);
    if (docId == null) {
      // First profile edit before any ensureDefault ran (e.g. legacy
      // account): create the doc, then patch it with these values.
      await ensureDefault();
      docId = await _findOwnDocument(userId);
      if (docId == null) {
        throw const DatabaseFailure(
            'Could not initialize settings. Try again.');
      }
    }
    try {
      await _db.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.userSettingsCollectionId,
        documentId: docId,
        data: {
          if (displayName != null) 'displayName': displayName,
          if (bio != null) 'bio': bio,
          if (tradingSince != null)
            'tradingSince': tradingSince.toUtc().toIso8601String(),
          // M-2: explicit clear — classic Databases cannot null an
          // attribute via updateDocument, so the epoch is the unset
          // sentinel; read() maps it back to null.
          if (clearTradingSince)
            'tradingSince': DateTime.fromMillisecondsSinceEpoch(0)
                .toUtc()
                .toIso8601String(),
          if (startingBalance != null) 'startingBalance': startingBalance,
          if (clearStartingBalance) 'startingBalance': 0,
          if (balanceCurrency != null) 'balanceCurrency': balanceCurrency,
          // P0-12.06c: stamp every balance change.
          if (isBalanceEdit)
            'balanceSetAt': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }

  /// Clears the starting balance back to unset (P0-12.06a: nullable).
  /// 0 is the unset sentinel — read() maps it to null.
  Future<void> clearStartingBalance() =>
      updateProfile(clearStartingBalance: true, isBalanceEdit: true);

  /// P0-12.10: change password via Appwrite account API.
  Future<void> changePassword(String newPassword) async {
    try {
      await _ref.read(appwriteAccountProvider).updatePassword(
            password: newPassword,
          );
    } on AppwriteException catch (e) {
      throw AppwriteFailureMapper.map(e);
    }
  }
}

final userSettingsRepositoryProvider =
    Provider<UserSettingsRepository>((ref) => UserSettingsRepository(ref));
