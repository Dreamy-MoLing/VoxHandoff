import 'dart:convert';

import '../../domain/direct_chat.dart';
import 'device_key_vault.dart';

/// The provider key is intentionally the only credential value this boundary
/// handles. Configuration records never contain the key.
class DirectLlmSecretStore {
  DirectLlmSecretStore(this._store);

  static const _prefix = 'voxhandoff.v1.direct-llm-key.';
  final SecureValueStore _store;

  Future<void> save(String providerId, String key) async {
    _validateProviderId(providerId);
    if (key.trim().isEmpty) {
      await delete(providerId);
      return;
    }
    await _store.write('$_prefix$providerId', key.trim());
  }

  Future<String?> read(String providerId) {
    _validateProviderId(providerId);
    return _store.read('$_prefix$providerId');
  }

  Future<void> delete(String providerId) {
    _validateProviderId(providerId);
    return _store.delete('$_prefix$providerId');
  }
}

class DirectLlmConfigurationStore {
  DirectLlmConfigurationStore(this._store);
  static const _key = 'voxhandoff.v1.direct-llm-configuration';
  final SecureValueStore _store;

  Future<void> save(DirectLlmConfiguration configuration) => _store.write(
    _key,
    jsonEncode({
      'version': 1,
      'id': configuration.id,
      'origin': configuration.origin.toString(),
      'model': configuration.model,
      'system_prompt': configuration.systemPrompt,
    }),
  );

  Future<DirectLlmConfiguration?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, Object?> ||
          value['version'] != 1 ||
          value['id'] is! String ||
          value['origin'] is! String ||
          value['model'] is! String ||
          value['system_prompt'] is! String) {
        return null;
      }
      final origin = Uri.tryParse(value['origin']! as String);
      if (origin == null) return null;
      final configuration = DirectLlmConfiguration(
        id: value['id']! as String,
        origin: origin,
        model: value['model']! as String,
        systemPrompt: value['system_prompt']! as String,
      );
      return configuration.isSafe ? configuration : null;
    } on Object {
      return null;
    }
  }
}

void _validateProviderId(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value)) {
    throw ArgumentError.value(value, 'providerId', 'must be an opaque ID');
  }
}
