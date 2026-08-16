import 'interaction_mode.dart';
import 'speech.dart';
import 'voice.dart';

enum SttProviderKind { bundledFasterWhisper, remoteHttps, disabled }

class RemoteSttProviderConfiguration {
  const RemoteSttProviderConfiguration({
    required this.providerId,
    required this.origin,
    required this.tlsPolicy,
    required this.retentionPolicy,
    required this.streaming,
    required this.revision,
    this.consentedAt,
  });

  final String providerId;
  final Uri origin;
  final String tlsPolicy;
  final String retentionPolicy;
  final bool streaming;
  final String revision;
  final DateTime? consentedAt;

  bool get isSafe {
    final normalizedProviderId = providerId.trim();
    final normalizedTlsPolicy = tlsPolicy.trim();
    final normalizedRetentionPolicy = retentionPolicy.trim();
    final normalizedRevision = revision.trim();
    return normalizedProviderId.isNotEmpty &&
        normalizedProviderId.length <= 128 &&
        RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(normalizedProviderId) &&
        origin.scheme == 'https' &&
        origin.host.isNotEmpty &&
        origin.userInfo.isEmpty &&
        (origin.path.isEmpty || origin.path == '/') &&
        !origin.hasQuery &&
        !origin.hasFragment &&
        normalizedTlsPolicy.isNotEmpty &&
        normalizedTlsPolicy.length <= 256 &&
        normalizedRetentionPolicy.isNotEmpty &&
        normalizedRetentionPolicy.length <= 256 &&
        normalizedRevision.isNotEmpty &&
        normalizedRevision.length <= 128 &&
        consentedAt != null;
  }

  RemoteSttProviderConfiguration copyWith({
    String? providerId,
    Uri? origin,
    String? tlsPolicy,
    String? retentionPolicy,
    bool? streaming,
    String? revision,
    DateTime? consentedAt,
    bool clearConsent = false,
  }) => RemoteSttProviderConfiguration(
    providerId: providerId ?? this.providerId,
    origin: origin ?? this.origin,
    tlsPolicy: tlsPolicy ?? this.tlsPolicy,
    retentionPolicy: retentionPolicy ?? this.retentionPolicy,
    streaming: streaming ?? this.streaming,
    revision: revision ?? this.revision,
    consentedAt: clearConsent ? null : consentedAt ?? this.consentedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is RemoteSttProviderConfiguration &&
      other.providerId == providerId &&
      other.origin == origin &&
      other.tlsPolicy == tlsPolicy &&
      other.retentionPolicy == retentionPolicy &&
      other.streaming == streaming &&
      other.revision == revision &&
      other.consentedAt == consentedAt;

  @override
  int get hashCode => Object.hash(
    providerId,
    origin,
    tlsPolicy,
    retentionPolicy,
    streaming,
    revision,
    consentedAt,
  );
}

class SttProviderConfiguration {
  const SttProviderConfiguration({
    this.kind = SttProviderKind.bundledFasterWhisper,
    this.language = 'zh',
    this.modelPath = '',
    this.remote,
  });

  const SttProviderConfiguration.remote({
    required this.remote,
    this.language = 'zh',
  }) : kind = SttProviderKind.remoteHttps,
       modelPath = '';

  final SttProviderKind kind;
  final String language;
  final String modelPath;
  final RemoteSttProviderConfiguration? remote;

  bool get isSafe {
    if (language.trim().isEmpty || language.length > 32) return false;
    return switch (kind) {
      SttProviderKind.disabled => true,
      SttProviderKind.bundledFasterWhisper =>
        remote == null && modelPath.trim().isNotEmpty,
      SttProviderKind.remoteHttps => remote?.isSafe ?? false,
    };
  }

  SttProviderConfiguration copyWith({
    SttProviderKind? kind,
    String? language,
    String? modelPath,
    RemoteSttProviderConfiguration? remote,
    bool clearRemote = false,
  }) => SttProviderConfiguration(
    kind: kind ?? this.kind,
    language: language ?? this.language,
    modelPath: modelPath ?? this.modelPath,
    remote: clearRemote ? null : remote ?? this.remote,
  );

  @override
  bool operator ==(Object other) =>
      other is SttProviderConfiguration &&
      other.kind == kind &&
      other.language == language &&
      other.modelPath == modelPath &&
      other.remote == remote;

  @override
  int get hashCode => Object.hash(kind, language, modelPath, remote);
}

const minSpeechRate = 0.5;
const maxSpeechRate = 2.0;

bool isSupportedSpeechRate(double value) =>
    value.isFinite && value >= minSpeechRate && value <= maxSpeechRate;

double piperLengthScaleForSpeechRate(double speechRate) {
  if (!isSupportedSpeechRate(speechRate)) {
    throw ArgumentError.value(speechRate, 'speechRate');
  }
  return 1 / speechRate;
}

double speechRateForPiperLengthScale(double lengthScale) {
  if (!lengthScale.isFinite || lengthScale <= 0) {
    throw ArgumentError.value(lengthScale, 'lengthScale');
  }
  return 1 / lengthScale;
}

enum TtsProviderKind { disabled, piperHttp, gptSoVits }

class TtsProviderConfiguration {
  const TtsProviderConfiguration.disabled()
    : kind = TtsProviderKind.disabled,
      origin = null,
      voice = null,
      speaker = null,
      speakerId = null,
      lengthScale = 1,
      referenceAudioPath = null,
      promptText = null,
      textLanguage = 'zh',
      promptLanguage = 'zh';

  const TtsProviderConfiguration.piper({
    required this.origin,
    this.voice,
    this.speaker,
    this.speakerId,
    this.lengthScale = 1,
  }) : kind = TtsProviderKind.piperHttp,
       referenceAudioPath = null,
       promptText = null,
       textLanguage = 'zh',
       promptLanguage = 'zh';

  const TtsProviderConfiguration.gptSoVits({
    required this.origin,
    required this.referenceAudioPath,
    required this.promptText,
    this.textLanguage = 'zh',
    this.promptLanguage = 'zh',
  }) : kind = TtsProviderKind.gptSoVits,
       voice = null,
       speaker = null,
       speakerId = null,
       lengthScale = 1;

  final TtsProviderKind kind;
  final Uri? origin;
  final String? voice;
  final String? speaker;
  final int? speakerId;
  final double lengthScale;
  final String? referenceAudioPath;
  final String? promptText;
  final String textLanguage;
  final String promptLanguage;

  bool get isSafe {
    if (kind == TtsProviderKind.disabled) return true;
    final uri = origin;
    if (uri == null ||
        uri.scheme != 'http' ||
        !_isLoopback(uri.host) ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    if (kind == TtsProviderKind.piperHttp) {
      return (voice?.trim().isNotEmpty ?? true) &&
          (speaker?.trim().isNotEmpty ?? true) &&
          (speakerId == null || speakerId! >= 0) &&
          lengthScale.isFinite &&
          lengthScale > 0;
    }
    return _isLocalAbsolutePath(referenceAudioPath) &&
        _isLanguageSafe(textLanguage) &&
        _isLanguageSafe(promptLanguage);
  }

  @override
  bool operator ==(Object other) =>
      other is TtsProviderConfiguration &&
      other.kind == kind &&
      other.origin == origin &&
      other.voice == voice &&
      other.speaker == speaker &&
      other.speakerId == speakerId &&
      other.lengthScale == lengthScale &&
      other.referenceAudioPath == referenceAudioPath &&
      other.promptText == promptText &&
      other.textLanguage == textLanguage &&
      other.promptLanguage == promptLanguage;

  @override
  int get hashCode => Object.hash(
    kind,
    origin,
    voice,
    speaker,
    speakerId,
    lengthScale,
    referenceAudioPath,
    promptText,
    textLanguage,
    promptLanguage,
  );
}

bool _isLanguageSafe(String value) {
  final normalized = value.trim();
  return normalized.isNotEmpty && normalized.length <= 32;
}

bool _isLocalAbsolutePath(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.startsWith('/') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalized);
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

class VoiceProviderSettings {
  const VoiceProviderSettings({
    this.assistantId = 'unbound-assistant',
    this.assistantRevision = 1,
    this.stt = const SttProviderConfiguration(kind: SttProviderKind.disabled),
    this.tts = const TtsProviderConfiguration.disabled(),
    this.microphoneId,
    this.interactionMode = defaultInteractionMode,
  });

  final String assistantId;
  final int assistantRevision;
  final SttProviderConfiguration stt;
  final TtsProviderConfiguration tts;
  final String? microphoneId;
  final InteractionMode interactionMode;

  VoiceProviderSettings copyWith({
    String? assistantId,
    int? assistantRevision,
    SttProviderConfiguration? stt,
    TtsProviderConfiguration? tts,
    String? microphoneId,
    InteractionMode? interactionMode,
    bool clearMicrophoneId = false,
  }) => VoiceProviderSettings(
    assistantId: assistantId ?? this.assistantId,
    assistantRevision: assistantRevision ?? this.assistantRevision,
    stt: stt ?? this.stt,
    tts: tts ?? this.tts,
    microphoneId: clearMicrophoneId ? null : microphoneId ?? this.microphoneId,
    interactionMode: interactionMode ?? this.interactionMode,
  );

  @override
  bool operator ==(Object other) =>
      other is VoiceProviderSettings &&
      other.assistantId == assistantId &&
      other.assistantRevision == assistantRevision &&
      other.stt == stt &&
      other.tts == tts &&
      other.microphoneId == microphoneId &&
      other.interactionMode == interactionMode;

  @override
  int get hashCode => Object.hash(
    assistantId,
    assistantRevision,
    stt,
    tts,
    microphoneId,
    interactionMode,
  );
}

enum VoiceProviderTestPhase { unknown, testing, ready, failed }

class VoiceProviderTestStatus {
  const VoiceProviderTestStatus({
    this.phase = VoiceProviderTestPhase.unknown,
    this.safeMessage,
  });

  final VoiceProviderTestPhase phase;
  final String? safeMessage;
}

/// Keeps application state independent from native/local provider details.
abstract interface class VoicePortFactory {
  SttPort createStt(SttProviderConfiguration configuration);
  TtsPort createTts(TtsProviderConfiguration configuration);
  bool isTtsEnabled(TtsProviderConfiguration configuration);
}
