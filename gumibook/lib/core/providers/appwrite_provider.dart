import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/appwrite_config.dart';

/// Riverpod providers for the Appwrite SDK (P0-03 foundation).
///
/// One Client for the whole app; Account and Databases derive from it.
/// No UI or auth logic here — repositories consume these providers.
final appwriteClientProvider = Provider<Client>((ref) {
  // ponytail: SDK Client has no dispose/close API in appwrite 26;
  // nothing to clean up on provider teardown.
  return Client()
    ..setEndpoint(AppwriteConfig.endpoint)
    ..setProject(AppwriteConfig.projectId);
});

final appwriteAccountProvider =
    Provider<Account>((ref) => Account(ref.watch(appwriteClientProvider)));

final appwriteDatabasesProvider =
    Provider<Databases>((ref) => Databases(ref.watch(appwriteClientProvider)));

final appwriteFunctionsProvider =
    Provider<Functions>((ref) => Functions(ref.watch(appwriteClientProvider)));
