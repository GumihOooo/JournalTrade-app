import 'app_config.dart';

/// Appwrite connection and resource IDs (P0-03.01..03.10).
///
/// Read-only view over [AppConfig]. All values are public identifiers —
/// safe in app code; no secret API keys (TASKS.md P0-13.02). Repositories
/// read collection IDs from here, never hardcode them.
abstract final class AppwriteConfig {
  static String get endpoint => AppConfig.appwriteEndpoint;
  static String get projectId => AppConfig.appwriteProjectId;

  /// `gumibook` database.
  static String get databaseId => AppConfig.databaseId;

  /// `trades` collection.
  static String get tradesCollectionId => AppConfig.tradesCollectionId;

  /// `user_settings` collection.
  static String get userSettingsCollectionId => AppConfig.userSettingsCollectionId;

  /// `watchlist` collection (P2; ID assigned when created).
  static String get watchlistCollectionId => AppConfig.watchlistCollectionId;

  /// `gumibook-ai-gateway` Function (all AI tasks route through it).
  static String get aiGatewayFunctionId => AppConfig.aiGatewayFunctionId;
}
