import 'dart:convert';

import '../../domain/voice_provider_settings.dart';
import 'device_key_vault.dart';

class RemoteSttSecretStore {
  RemoteSttSecretStore(this._store);

  static const _prefix = 'voxhandoff.v1.remote-stt-token.';
  final SecureValueStore _store;

  Future<void> save(String providerId, String token) async {
    final normalizedProviderId = _validateProviderId(providerId);
    final normalized = token.trim();
    if (normalized.isEmpty) {
      await delete(normalizedProviderId);
      return;
    }
    if (normalized.length > 4096) {
      throw const FormatException('Remote STT token is too long.');
    }
    await _store.write(_key(normalizedProviderId), normalized);
  }

  Future<String?> read(String providerId) {
    final normalized = _validateProviderId(providerId);
    return _store.read(_key(normalized));
  }

  Future<void> delete(String providerId) {
    final normalized = _validateProviderId(providerId);
    return _store.delete(_key(normalized));
  }

  String _key(String providerId) => '$_prefix$providerId';
}

class VoiceProviderSettingsStore {
  VoiceProviderSettingsStore(this._store);

  static const _key = 'voxhandoff.v1.voice-provider-settings';
  final SecureValueStore _store;

  RemoteSttSecretStore get remoteSttSecrets => RemoteSttSecretStore(_store);

  Future<void> save(VoiceProviderSettings settings) => _store.write(
    _key,
    jsonEncode({
      'version': 3,
      'assistant_id': settings.assistantId,
      'assistant_revision': settings.assistantRevision,
      if (settings.microphoneId != null) 'microphone_id': settings.microphoneId,
      'stt': {
        'kind': settings.stt.kind.name,
        'language': settings.stt.language,
        if (settings.stt.modelPath.isNotEmpty)
          'model_path': settings.stt.modelPath,
        if (settings.stt.remote != null)
          'remote': _encodeRemoteStt(settings.stt.remote!),
      },
      'tts': {
        'kind': settings.tts.kind.name,
        if (settings.tts.origin != null)
          'origin': settings.tts.origin.toString(),
        if (settings.tts.voice != null) 'voice': settings.tts.voice,
        if (settings.tts.speaker != null) 'speaker': settings.tts.speaker,
        if (settings.tts.speakerId != null)
          'speaker_id': settings.tts.speakerId,
        'length_scale': settings.tts.lengthScale,
        if (settings.tts.referenceAudioPath != null)
          'reference_audio_path': settings.tts.referenceAudioPath,
        if (settings.tts.promptText != null)
          'prompt_text': settings.tts.promptText,
        'text_language': settings.tts.textLanguage,
        'prompt_language': settings.tts.promptLanguage,
      },
    }),
  );

  Future<VoiceProviderSettings?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> ||
          (decoded['version'] != 1 &&
              decoded['version'] != 2 &&
              decoded['version'] != 3)) {
        return null;
      }
      final stt = _readStt(decoded['stt']);
      final tts = _readTts(decoded['tts']);
      if (stt == null || tts == null) return null;
      if (!tts.isSafe) return null;
      final microphoneId = decoded['microphone_id'];
      if (microphoneId != null &&
          (microphoneId is! String || microphoneId.trim().isEmpty)) {
        return null;
      }
      final assistantId = decoded['assistant_id'];
      final assistantRevision = decoded['assistant_revision'];
      if (assistantId != null &&
          (assistantId is! String || assistantId.trim().isEmpty)) {
        return null;
      }
      if (assistantRevision != null &&
          (assistantRevision is! int || assistantRevision < 1)) {
        return null;
      }
      return VoiceProviderSettings(
        assistantId: assistantId is String ? assistantId : 'unbound-assistant',
        assistantRevision: assistantRevision is int ? assistantRevision : 1,
        stt: stt,
        tts: tts,
        microphoneId: microphoneId as String?,
      );
    } on Object {
      return null;
    }
  }
}

SttProviderConfiguration? _readStt(Object? value) {
  if (value is! Map<String, Object?> ||
      value['kind'] is! String ||
      value['language'] is! String) {
    return null;
  }
  final kind = _sttKind(value['kind']! as String);
  if (kind == null) return null;
  final config = SttProviderConfiguration(
    kind: kind,
    language: value['language']! as String,
    modelPath: value['model_path'] is String
        ? value['model_path']! as String
        : '',
    remote: _readRemoteStt(value['remote']),
  );
  return config.isSafe ? config : null;
}

Map<String, Object?> _encodeRemoteStt(RemoteSttProviderConfiguration value) => {
  'provider_id': value.providerId,
  'origin': value.origin.toString(),
  'tls_policy': value.tlsPolicy,
  'retention_policy': value.retentionPolicy,
  'streaming': value.streaming,
  'revision': value.revision,
  if (value.consentedAt != null)
    'consented_at': value.consentedAt!.toUtc().toIso8601String(),
};

RemoteSttProviderConfiguration? _readRemoteStt(Object? value) {
  if (value is! Map<String, Object?> ||
      value['provider_id'] is! String ||
      value['origin'] is! String ||
      value['tls_policy'] is! String ||
      value['retention_policy'] is! String ||
      value['streaming'] is! bool ||
      value['revision'] is! String) {
    return null;
  }
  final origin = Uri.tryParse(value['origin']! as String);
  final consentedAt = value['consented_at'];
  final parsedConsent = consentedAt is String
      ? DateTime.tryParse(consentedAt)
      : null;
  if (origin == null || consentedAt != null && parsedConsent == null) {
    return null;
  }
  return RemoteSttProviderConfiguration(
    providerId: value['provider_id']! as String,
    origin: origin,
    tlsPolicy: value['tls_policy']! as String,
    retentionPolicy: value['retention_policy']! as String,
    streaming: value['streaming']! as bool,
    revision: value['revision']! as String,
    consentedAt: parsedConsent,
  );
}

TtsProviderConfiguration? _readTts(Object? value) {
  if (value is! Map<String, Object?> || value['kind'] is! String) return null;
  final kind = _ttsKind(value['kind']! as String);
  switch (kind) {
    case TtsProviderKind.disabled:
      return const TtsProviderConfiguration.disabled();
    case TtsProviderKind.piperHttp:
      if (value['origin'] is! String ||
          value['length_scale'] is! num ||
          (value['voice'] != null && value['voice'] is! String) ||
          (value['speaker'] != null && value['speaker'] is! String) ||
          (value['speaker_id'] != null && value['speaker_id'] is! int)) {
        return null;
      }
      final origin = Uri.tryParse(value['origin']! as String);
      if (origin == null) return null;
      try {
        return TtsProviderConfiguration.piper(
          origin: origin,
          voice: value['voice'] as String?,
          speaker: value['speaker'] as String?,
          speakerId: value['speaker_id'] as int?,
          lengthScale: (value['length_scale']! as num).toDouble(),
        );
      } on Object {
        return null;
      }
    case TtsProviderKind.gptSoVits:
      if (value['origin'] is! String ||
          value['reference_audio_path'] is! String ||
          value['prompt_text'] is! String ||
          (value['text_language'] != null &&
              value['text_language'] is! String) ||
          (value['prompt_language'] != null &&
              value['prompt_language'] is! String)) {
        return null;
      }
      final origin = Uri.tryParse(value['origin']! as String);
      return origin == null
          ? null
          : TtsProviderConfiguration.gptSoVits(
              origin: origin,
              referenceAudioPath: value['reference_audio_path']! as String,
              promptText: value['prompt_text']! as String,
              textLanguage: value['text_language'] as String? ?? 'zh',
              promptLanguage: value['prompt_language'] as String? ?? 'zh',
            );
    case null:
      return null;
  }
}

SttProviderKind? _sttKind(String value) {
  for (final kind in SttProviderKind.values) {
    if (kind.name == value) return kind;
  }
  return null;
}

String _validateProviderId(String providerId) {
  final normalized = providerId.trim();
  if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(normalized)) {
    throw const FormatException('Invalid remote STT provider ID.');
  }
  return normalized;
}

TtsProviderKind? _ttsKind(String value) {
  for (final kind in TtsProviderKind.values) {
    if (kind.name == value) return kind;
  }
  return null;
}
