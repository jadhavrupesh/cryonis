import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal storage interface so secure credential behavior can be tested
/// without loading a platform keychain plugin.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecretStore implements SecretStore {
  PlatformSecretStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // The legacy macOS Keychain remains OS-protected but avoids the
            // Keychain Sharing entitlement and its provisioning requirement.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Owns the Ollama API key and migrates the old SharedPreferences value into
/// secure platform storage. The legacy value is removed only after a
/// successful secure write, so an unavailable keychain cannot lose the key.
class ApiKeyStore {
  ApiKeyStore(this._secrets);

  static const key = 'ollama_api_key';

  final SecretStore _secrets;

  Future<String?> loadAndMigrate(SharedPreferences prefs) async {
    try {
      final secure = (await _secrets.read(key))?.trim();
      if (secure != null && secure.isNotEmpty) {
        await prefs.remove(key);
        return secure;
      }
    } catch (_) {
      // Fall through to the legacy value. This keeps startup usable if the
      // keychain is temporarily unavailable.
    }

    final legacy = prefs.getString(key)?.trim();
    if (legacy == null || legacy.isEmpty) return null;
    try {
      await _secrets.write(key, legacy);
      await prefs.remove(key);
    } catch (_) {
      // Keep the legacy value until secure migration succeeds on a later run.
    }
    return legacy;
  }

  Future<void> save(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) {
      await _secrets.delete(key);
    } else {
      await _secrets.write(key, clean);
    }
  }
}

/// Used by tests and callers that do not need persistent credentials.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
