import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'device_key_vault.dart';

class FlutterSecureValueStore implements SecureValueStore {
  factory FlutterSecureValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'agent_talk_v1',
        resetOnError: false,
      ),
    ),
  }) => FlutterSecureValueStore._(storage);

  const FlutterSecureValueStore._(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
