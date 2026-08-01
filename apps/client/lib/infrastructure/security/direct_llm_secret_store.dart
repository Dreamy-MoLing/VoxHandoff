import 'dart:convert';
import 'dart:math';

import '../../domain/confirmed_draft.dart';
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
            (value['version'] == 1 || value['version'] == 2) &&
            value['assistant_id'] is String &&
            value['assistant_revision'] is int &&
            value['system_prompt'] is String) {
          return AssistantProfile(
            assistantId: value['assistant_id']! as String,
            assistantRevision: value['assistant_revision']! as int,
            systemPrompt: value['system_prompt']! as String,
            displayName: _assistantString(value, 'display_name', 'VoxHandoff'),
            persona: _assistantString(value, 'persona', ''),
            memoryPolicy: _assistantMemoryPolicy(value['memory_policy']),
            voiceProfileId: _assistantString(
              value,
              'voice_profile_id',
              'default-voice',
            ),
            signalCoreProfile: _assistantString(
              value,
              'signal_core_profile',
              'signal-core',
            ),
            defaultChatSource: _assistantChatSource(
              value['default_chat_source'],
            ),
            hermesWorkBackend: _assistantString(
              value,
              'hermes_work_backend',
              'hermes-gateway',
            ),
            speechPolicy: _assistantSpeechPolicy(value['speech_policy']),
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
      'version': 2,
      'assistant_id': profile.assistantId,
      'assistant_revision': profile.assistantRevision,
      'system_prompt': profile.systemPrompt,
      'display_name': profile.displayName,
      'persona': profile.persona,
      'memory_policy': profile.memoryPolicy.name,
      'voice_profile_id': profile.voiceProfileId,
      'signal_core_profile': profile.signalCoreProfile,
      'default_chat_source': profile.defaultChatSource.name,
      'hermes_work_backend': profile.hermesWorkBackend,
      'speech_policy': profile.speechPolicy.name,
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

String _assistantString(
  Map<String, Object?> value,
  String key,
  String fallback,
) => value[key] is String ? value[key]! as String : fallback;

AssistantMemoryPolicy _assistantMemoryPolicy(Object? value) => switch (value) {
  'disabled' => AssistantMemoryPolicy.disabled,
  _ => AssistantMemoryPolicy.localOnly,
};

AssistantSpeechPolicy _assistantSpeechPolicy(Object? value) => switch (value) {
  'off' => AssistantSpeechPolicy.off,
  'manual' => AssistantSpeechPolicy.manual,
  _ => AssistantSpeechPolicy.afterCompleted,
};

ChatSource _assistantChatSource(Object? value) => switch (value) {
  'hermes' => ChatSource.hermes,
  _ => ChatSource.directLlm,
};
