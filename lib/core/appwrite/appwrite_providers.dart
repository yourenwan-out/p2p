import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Appwrite Configuration Constants
const String appwriteProjectId = '69cc14ce000d6ee3e15b';
const String appwriteEndpoint = 'https://fra.cloud.appwrite.io/v1';

// Provider for the Appwrite Client
final appwriteClientProvider = Provider<Client>((ref) {
  final client = Client()
    ..setEndpoint(appwriteEndpoint)
    ..setProject(appwriteProjectId)
    ..setSelfSigned(status: true); // Allow self-signed certificates for dev
  return client;
});

// Provider for Appwrite Account (for Authentication)
final appwriteAccountProvider = Provider<Account>((ref) {
  final client = ref.watch(appwriteClientProvider);
  return Account(client);
});

// Provider for Appwrite Databases
final appwriteDatabasesProvider = Provider<Databases>((ref) {
  final client = ref.watch(appwriteClientProvider);
  return Databases(client);
});

// Provider for Realtime (WebSockets)
final appwriteRealtimeProvider = Provider<Realtime>((ref) {
  final client = ref.watch(appwriteClientProvider);
  return Realtime(client);
});

// Auth Service to handle Anonymous Login
final authServiceProvider = Provider<AuthService>((ref) {
  final account = ref.watch(appwriteAccountProvider);
  return AuthService(account);
});

class AuthService {
  final Account _account;

  AuthService(this._account);

  // Checks for an active session, creates an anonymous one if missing
  Future<void> ensureAnonymousSession() async {
    try {
      // Trying to get the current session
      await _account.get();
      // If no exception is thrown, the user is already logged in
    } on AppwriteException catch (e) {
      if (e.code == 401) {
        // Unauthenticated, create anonymous session
        try {
          await _account.createAnonymousSession();
        } catch (createError) {
          rethrow;
        }
      } else {
        rethrow;
      }
    }
  }
}
