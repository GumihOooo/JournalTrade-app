import 'package:flutter/foundation.dart';

/// Central configuration. Values injected at build/run time via --dart-define.
/// Only public, non-secret identifiers belong here (IMPLEMENTATION.md §7).
class AppConfig {
  const AppConfig._();

  static const appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://sgp.cloud.appwrite.io/v1',
  );
  static const appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '6a96070c001fa35e432c',
  );

  static const databaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: '6a960b8d0035adcd1c0d',
  );
  static const tradesCollectionId = String.fromEnvironment(
    'APPWRITE_TRADES_COLLECTION_ID',
    defaultValue: '6a960c2e0034859eb771',
  );
  static const userSettingsCollectionId = String.fromEnvironment(
    'APPWRITE_USER_SETTINGS_COLLECTION_ID',
    defaultValue: '6a960c4b0037051b0c8a',
  );
  static const watchlistCollectionId = String.fromEnvironment(
    'APPWRITE_WATCHLIST_COLLECTION_ID',
    defaultValue: 'watchlist',
  );

  /// `gumibook-ai-gateway` Appwrite Function (single AI entry point).
  static const aiGatewayFunctionId = String.fromEnvironment(
    'APPWRITE_AI_GATEWAY_FUNCTION_ID',
    defaultValue: '6a9f27840000f13ef60f',
  );

  static const onboardingDoneKey = 'onboarding_done';

  static void debugDump() {
    if (kDebugMode) {
      debugPrint('AppConfig endpoint=$appwriteEndpoint project=$appwriteProjectId');
    }
  }
}
