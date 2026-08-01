import 'speech.dart';
import 'voice.dart';

enum SttProviderKind { bundledFasterWhisper, disabled }

class SttProviderConfiguration {
  const SttProviderConfiguration({
    this.kind = SttProviderKind.bundledFasterWhisper,
    this.language = 'zh',
    this.modelPath = '',
  });

  final SttProviderKind kind;
  final String language;
  final String modelPath;

  bool get isSafe =>
      language.trim().isNotEmpty &&
      language.length <= 32 &&
      (kind == SttProviderKind.disabled || modelPath.trim().isNotEmpty);

  SttProviderConfiguration copyWith({
    SttProviderKind? kind,
    String? language,
    String? modelPath,
  }) => SttProviderConfiguration(
    kind: kind ?? this.kind,
    language: language ?? this.language,
    modelPath: modelPath ?? this.modelPath,
  );

  @override
  bool operator ==(Object other) =>
      other is SttProviderConfiguration &&
      other.kind == kind &&
      other.language == language &&
      other.modelPath == modelPath;

  @override
  int get hashCode => Object.hash(kind, language, modelPath);
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
      promptText = null;

  const TtsProviderConfiguration.piper({
    required this.origin,
    this.voice,
    this.speaker,
    this.speakerId,
    this.lengthScale = 1,
  }) : kind = TtsProviderKind.piperHttp,
       referenceAudioPath = null,
       promptText = null;

  const TtsProviderConfiguration.gptSoVits({
    required this.origin,
    required this.referenceAudioPath,
    required this.promptText,
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
    return referenceAudioPath?.isNotEmpty == true;
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
      other.promptText == promptText;

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
  );
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
  });

  final String assistantId;
  final int assistantRevision;
  final SttProviderConfiguration stt;
  final TtsProviderConfiguration tts;
  final String? microphoneId;

  VoiceProviderSettings copyWith({
    String? assistantId,
    int? assistantRevision,
    SttProviderConfiguration? stt,
    TtsProviderConfiguration? tts,
    String? microphoneId,
    bool clearMicrophoneId = false,
  }) => VoiceProviderSettings(
    assistantId: assistantId ?? this.assistantId,
    assistantRevision: assistantRevision ?? this.assistantRevision,
    stt: stt ?? this.stt,
    tts: tts ?? this.tts,
    microphoneId: clearMicrophoneId ? null : microphoneId ?? this.microphoneId,
  );

  @override
  bool operator ==(Object other) =>
      other is VoiceProviderSettings &&
      other.assistantId == assistantId &&
      other.assistantRevision == assistantRevision &&
      other.stt == stt &&
      other.tts == tts &&
      other.microphoneId == microphoneId;

  @override
  int get hashCode =>
      Object.hash(assistantId, assistantRevision, stt, tts, microphoneId);
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
