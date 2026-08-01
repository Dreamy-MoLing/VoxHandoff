import 'dart:convert';
import 'dart:math';

import '../../domain/direct_chat.dart';
import 'device_key_vault.dart';

/// The provider key is intentionally the only credential value this boundary
/// handles. Configuration records never contain the key.
class DirectLlmSecretStore {
  DirectLlmSecretStore(this._store);

  static const _prefix = 'voxhandoff.v2.direct-llm-key.';
  static const legacyPrefix = 'voxhandoff.v1.direct-llm-key.';
  final SecureValueStore _store;

  Future<void> save(
    String providerProfileId,
    String key, {
    int credentialRevision = 1,
  }) async {
    _validateProviderId(providerProfileId);
    _validateRevision(credentialRevision, 'credentialRevision');
    if (key.trim().isEmpty) {
      await delete(providerProfileId, credentialRevision: credentialRevision);
      return;
    }
    await _store.write(_key(providerProfileId, credentialRevision), key.trim());
  }

  Future<String?> read(String providerProfileId, {int credentialRevision = 1}) {
    _validateProviderId(providerProfileId);
    _validateRevision(credentialRevision, 'credentialRevision');
    return _store.read(_key(providerProfileId, credentialRevision));
  }

  Future<void> delete(String providerProfileId, {int credentialRevision = 1}) {
    _validateProviderId(providerProfileId);
    _validateRevision(credentialRevision, 'credentialRevision');
    return _store.delete(_key(providerProfileId, credentialRevision));
  }

  Future<void> deleteLegacy(String providerId) {
    _validateProviderId(providerId);
    return _store.delete('$legacyPrefix$providerId');
  }

  String _key(String providerProfileId, int credentialRevision) =>
      '$_prefix$providerProfileId.$credentialRevision';
}

class DirectLlmConfigurationStore {
  DirectLlmConfigurationStore(this._store);
  static const _key = 'voxhandoff.v2.direct-llm-configuration';
  static const legacyKey = 'voxhandoff.v1.direct-llm-configuration';
  final SecureValueStore _store;

  Future<void> save(DirectLlmConfiguration configuration) => _store.write(
    _key,
    jsonEncode({
      'version': 2,
      'provider_profile_id': configuration.profileId,
      'origin': configuration.origin.toString(),
      'model': configuration.model,
      'auth_realm': configuration.authRealm,
      'principal': configuration.principal,
      'credential_revision': configuration.credentialRevision,
      'configuration_revision': configuration.configurationRevision,
      'conversation_id': configuration.conversationId,
      'assistant_id': configuration.assistantId,
      'assistant_revision': configuration.assistantRevision,
      'context_snapshot_revision': configuration.contextSnapshotRevision,
      'context_snapshot_hash': configuration.contextSnapshotHash,
    }),
  );

  Future<AssistantProfile> readOrCreateDefaultAssistant() async {
    final raw = await _store.read('$_key.assistant');
    if (raw != null) {
      try {
        final value = jsonDecode(raw);
        if (value is Map<String, Object?> &&
            value['version'] == 1 &&
            value['assistant_id'] is String &&
            value['assistant_revision'] is int &&
            value['system_prompt'] is String) {
          return AssistantProfile(
            assistantId: value['assistant_id']! as String,
            assistantRevision: value['assistant_revision']! as int,
            systemPrompt: value['system_prompt']! as String,
          );
        }
      } on Object {
        // A malformed ordinary config is ignored and replaced below. It is
        // never interpreted as a credential or an active target.
      }
    }
    final profile = AssistantProfile(
      assistantId: _opaqueId('assistant'),
      assistantRevision: 1,
      systemPrompt: '',
    );
    await saveAssistant(profile);
    return profile;
  }

  Future<void> saveAssistant(AssistantProfile profile) => _store.write(
    '$_key.assistant',
    jsonEncode({
      'version': 1,
      'assistant_id': profile.assistantId,
      'assistant_revision': profile.assistantRevision,
      'system_prompt': profile.systemPrompt,
    }),
  );

  Future<DirectLlmConfiguration?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final assistant = await readOrCreateDefaultAssistant();
      final value = jsonDecode(raw);
      if (value is! Map<String, Object?> ||
          value['version'] != 2 ||
          value['provider_profile_id'] is! String ||
          value['origin'] is! String ||
          value['model'] is! String ||
          value['auth_realm'] is! String ||
          value['principal'] is! String ||
          value['credential_revision'] is! int ||
          value['configuration_revision'] is! int ||
          value['conversation_id'] is! String ||
          value['assistant_id'] is! String ||
          value['assistant_revision'] is! int ||
          value['context_snapshot_revision'] is! int ||
          value['context_snapshot_hash'] is! String) {
        return null;
      }
      final origin = Uri.tryParse(value['origin']! as String);
      if (origin == null) return null;
      final configuration = DirectLlmConfiguration(
        providerProfileId: value['provider_profile_id']! as String,
        origin: origin,
        model: value['model']! as String,
        systemPrompt: assistant.systemPrompt,
        authRealm: value['auth_realm']! as String,
        principal: value['principal']! as String,
        credentialRevision: value['credential_revision']! as int,
        configurationRevision: value['configuration_revision']! as int,
        conversationId: value['conversation_id']! as String,
        assistantId: value['assistant_id']! as String,
        assistantRevision: value['assistant_revision']! as int,
        contextSnapshotRevision: value['context_snapshot_revision']! as int,
        contextSnapshotHash: value['context_snapshot_hash']! as String,
      );
      return configuration.isSafe &&
              configuration.assistantId == assistant.assistantId &&
              configuration.assistantRevision == assistant.assistantRevision &&
              configuration.profileId.isNotEmpty &&
              configuration.conversationId.isNotEmpty &&
              configuration.assistantId.isNotEmpty &&
              configuration.credentialRevision > 0 &&
              configuration.configurationRevision > 0
          ? configuration
          : null;
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

void _validateRevision(int value, String name) {
  if (value < 1) throw ArgumentError.value(value, name, 'must be positive');
}

String _opaqueId(String prefix) =>
    '$prefix-${List<int>.generate(16, (_) => Random.secure().nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
