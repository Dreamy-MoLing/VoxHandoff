import 'dart:convert';

import '../../domain/voice_provider_settings.dart';
import 'device_key_vault.dart';

class VoiceProviderSettingsStore {
  VoiceProviderSettingsStore(this._store);

  static const _key = 'voxhandoff.v1.voice-provider-settings';
  final SecureValueStore _store;

  Future<void> save(VoiceProviderSettings settings) => _store.write(
    _key,
    jsonEncode({
      'version': 2,
      'assistant_id': settings.assistantId,
      'assistant_revision': settings.assistantRevision,
      if (settings.microphoneId != null) 'microphone_id': settings.microphoneId,
      'stt': {
        'kind': settings.stt.kind.name,
        'language': settings.stt.language,
        if (settings.stt.modelPath.isNotEmpty)
          'model_path': settings.stt.modelPath,
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
      },
    }),
  );

  Future<VoiceProviderSettings?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> ||
          (decoded['version'] != 1 && decoded['version'] != 2)) {
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
  );
  return config.isSafe ? config : null;
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
          value['prompt_text'] is! String) {
        return null;
      }
      final origin = Uri.tryParse(value['origin']! as String);
      return origin == null
          ? null
          : TtsProviderConfiguration.gptSoVits(
              origin: origin,
              referenceAudioPath: value['reference_audio_path']! as String,
              promptText: value['prompt_text']! as String,
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

TtsProviderKind? _ttsKind(String value) {
  for (final kind in TtsProviderKind.values) {
    if (kind.name == value) return kind;
  }
  return null;
}
