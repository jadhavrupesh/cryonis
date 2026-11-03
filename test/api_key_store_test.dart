import 'package:cryonis/services/api_key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingSecretStore implements SecretStore {
  @override
  Future<void> delete(String key) => throw StateError('unavailable');

  @override
  Future<String?> read(String key) => throw StateError('unavailable');

  @override
  Future<void> write(String key, String value) =>
      throw StateError('unavailable');
}

void main() {
  test('migrates the legacy API key into secure storage', () async {
    SharedPreferences.setMockInitialValues({ApiKeyStore.key: ' legacy-key '});
    final prefs = await SharedPreferences.getInstance();
    final secrets = MemorySecretStore();

    final value = await ApiKeyStore(secrets).loadAndMigrate(prefs);

    expect(value, 'legacy-key');
    expect(secrets.values[ApiKeyStore.key], 'legacy-key');
    expect(prefs.getString(ApiKeyStore.key), isNull);
  });

  test('secure value wins and removes a stale legacy copy', () async {
    SharedPreferences.setMockInitialValues({ApiKeyStore.key: 'old'});
    final prefs = await SharedPreferences.getInstance();
    final secrets = MemorySecretStore()..values[ApiKeyStore.key] = 'secure';

    expect(await ApiKeyStore(secrets).loadAndMigrate(prefs), 'secure');
    expect(prefs.getString(ApiKeyStore.key), isNull);
  });

  test('failed migration returns and preserves the legacy value', () async {
    SharedPreferences.setMockInitialValues({ApiKeyStore.key: 'keep-me'});
    final prefs = await SharedPreferences.getInstance();

    expect(
      await ApiKeyStore(_FailingSecretStore()).loadAndMigrate(prefs),
      'keep-me',
    );
    expect(prefs.getString(ApiKeyStore.key), 'keep-me');
  });
}
