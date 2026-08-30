import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around flutter_secure_storage — backs genuinely sensitive
/// values (API keys, OAuth tokens, the HMAC request-signing secret) with the
/// platform's hardware-backed encrypted storage (Android Keystore / iOS
/// Keychain, AES-256 under the hood) instead of SharedPreferences' plaintext
/// XML/JSON file.
///
/// On web there is no OS keystore to hook into — flutter_secure_storage
/// falls back to browser storage wrapped with a WebCrypto-derived key, which
/// is better than nothing but not hardware-backed like mobile. This is a
/// platform limitation, not a bug in this wrapper.
///
/// Kept as a thin, overridable class (not a set of top-level functions) so
/// tests can substitute an in-memory fake — see FakeSecureStorageService in
/// command_router_test.dart — without ever touching the real plugin's
/// platform channel, which isn't available in `flutter test`.
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}
