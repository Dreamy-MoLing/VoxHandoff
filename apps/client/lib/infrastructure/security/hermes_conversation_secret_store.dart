import 'dart:convert';

import '../../domain/hermes_conversation.dart';
import 'device_key_vault.dart';

/// Hermes API credentials have their own secure-storage namespace. They are
/// never read through the Direct LLM or STT secret stores.
class HermesConversationSecretStore {
  HermesConversationSecretStore(this._store);

  static const prefix = 'voxhandoff.v1.hermes-conversation-api-key.';
  final SecureValueStore _store;

  Future<void> save(
    String providerProfileId,
    String apiKey, {
    int credentialRevision = 1,
  }) async {
    _validateHermesProviderProfileId(providerProfileId);
    _validateHermesRevision(credentialRevision);
    final normalized = apiKey.trim();
    if (normalized.isEmpty) {
      await delete(providerProfileId, credentialRevision: credentialRevision);
      return;
    }
    if (normalized.length > 4096) {
      throw const FormatException('Hermes API key is too long.');
    }
    await _store.write(_key(providerProfileId, credentialRevision), normalized);
  }

  Future<String?> read(String providerProfileId, {int credentialRevision = 1}) {
    _validateHermesProviderProfileId(providerProfileId);
    _validateHermesRevision(credentialRevision);
    return _store.read(_key(providerProfileId, credentialRevision));
  }

  Future<void> delete(String providerProfileId, {int credentialRevision = 1}) {
    _validateHermesProviderProfileId(providerProfileId);
    _validateHermesRevision(credentialRevision);
    return _store.delete(_key(providerProfileId, credentialRevision));
  }

  String _key(String providerProfileId, int credentialRevision) =>
      '$prefix$providerProfileId.$credentialRevision';
}

class HermesConversationConfigurationStore {
  HermesConversationConfigurationStore(this._store);

  static const key = 'voxhandoff.v1.hermes-conversation-configuration';
  final SecureValueStore _store;

  Future<void> save(HermesConversationConfiguration configuration) {
    if (!configuration.isSafe) {
      throw const FormatException(
        'The Hermes conversation configuration is unsafe.',
      );
    }
    return _store.write(
      key,
      encodeHermesConversationConfiguration(configuration),
    );
  }

  Future<HermesConversationConfiguration?> read() async {
    final raw = await _store.read(key);
    if (raw == null) return null;
    try {
      return HermesConversationConfiguration.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  Future<void> delete() => _store.delete(key);
}

void _validateHermesProviderProfileId(String value) {
  if (value.isEmpty ||
      value.length > 128 ||
      !RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value)) {
    throw const FormatException('The Hermes provider profile ID is invalid.');
  }
}

void _validateHermesRevision(int value) {
  if (value < 1) {
    throw const FormatException('The Hermes credential revision is invalid.');
  }
}
