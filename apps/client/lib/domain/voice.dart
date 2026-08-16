import 'dart:typed_data';

import 'interaction_mode.dart';

enum VoiceInputPhase {
  idle,
  requestingPermission,
  recording,
  transcribing,
  awaitingConfirmation,
  awaitingCallConfirm,
  cancelled,
  failed,
}

enum VoiceFailureStage {
  recording,
  stt,
  summary,
  tts,
  playback,
  storage,
  configuration,
}

class VoiceStageFailure {
  const VoiceStageFailure({
    required this.stage,
    required this.code,
    required this.safeMessage,
    required this.retryable,
  });

  final VoiceFailureStage stage;
  final String code;
  final String safeMessage;
  final bool retryable;
}

class VoicePortException implements Exception {
  const VoicePortException(this.failure);

  final VoiceStageFailure failure;

  @override
  String toString() =>
      'VoicePortException(stage: ${failure.stage.name}, code: ${failure.code})';
}

class VoiceSessionState {
  const VoiceSessionState({
    this.phase = VoiceInputPhase.idle,
    this.sessionId,
    this.provisionalTranscript = '',
    this.finalTranscript,
    this.originalTranscript,
    this.audioLevel = 0,
    this.failure,
    this.storageWarning,
    this.interactionMode = defaultInteractionMode,
  });

  final VoiceInputPhase phase;
  final String? sessionId;
  final String provisionalTranscript;
  final String? finalTranscript;
  final String? originalTranscript;
  final double audioLevel;
  final VoiceStageFailure? failure;
  final VoiceStageFailure? storageWarning;
  final InteractionMode interactionMode;

  bool get canStart =>
      phase == VoiceInputPhase.idle ||
      phase == VoiceInputPhase.cancelled ||
      phase == VoiceInputPhase.awaitingConfirmation ||
      phase == VoiceInputPhase.failed;

  bool get canStop => phase == VoiceInputPhase.recording;

  bool get canCancel =>
      phase == VoiceInputPhase.requestingPermission ||
      phase == VoiceInputPhase.recording ||
      phase == VoiceInputPhase.transcribing;

  /// The lightweight call-mode echo is awaiting a one-key send or cancel.
  bool get canConfirmCallSend => phase == VoiceInputPhase.awaitingCallConfirm;

  bool get canDiscardCallConfirm =>
      phase == VoiceInputPhase.awaitingCallConfirm;

  VoiceSessionState copyWith({
    VoiceInputPhase? phase,
    String? sessionId,
    String? provisionalTranscript,
    String? finalTranscript,
    String? originalTranscript,
    double? audioLevel,
    VoiceStageFailure? failure,
    VoiceStageFailure? storageWarning,
    InteractionMode? interactionMode,
    bool clearSession = false,
    bool clearTranscript = false,
    bool clearFailure = false,
    bool clearStorageWarning = false,
  }) => VoiceSessionState(
    phase: phase ?? this.phase,
    sessionId: clearSession ? null : sessionId ?? this.sessionId,
    provisionalTranscript: clearTranscript
        ? ''
        : provisionalTranscript ?? this.provisionalTranscript,
    finalTranscript: clearTranscript
        ? null
        : finalTranscript ?? this.finalTranscript,
    originalTranscript: clearTranscript
        ? null
        : originalTranscript ?? this.originalTranscript,
    audioLevel: audioLevel ?? this.audioLevel,
    failure: clearFailure ? null : failure ?? this.failure,
    storageWarning: clearStorageWarning
        ? null
        : storageWarning ?? this.storageWarning,
    interactionMode: interactionMode ?? this.interactionMode,
  );
}

class AudioCaptureConfig {
  const AudioCaptureConfig({
    this.sampleRate = 16000,
    this.channels = 1,
    this.microphoneId,
  });

  final int sampleRate;
  final int channels;
  final String? microphoneId;
}

class AudioInputDevice {
  const AudioInputDevice({required this.id, required this.label});

  final String id;
  final String label;
}

abstract interface class AudioInputDeviceEnumerator {
  Future<List<AudioInputDevice>> listInputDevices();
}

abstract interface class AudioCaptureSession {
  Stream<Uint8List> get audioChunks;
  Stream<double> get levels;
  Future<void> stop();
  Future<void> cancel();
}

abstract interface class AudioCapturePort {
  Future<AudioCaptureSession> start(AudioCaptureConfig config);
  Future<void> close();
}

class TranscriptUpdate {
  const TranscriptUpdate({required this.text, required this.sequence});

  final String text;
  final int sequence;
}

class FinalTranscript {
  const FinalTranscript({
    required this.text,
    required this.audioDuration,
    required this.transcriptionDuration,
    this.language,
    this.confidence,
  });

  final String text;
  final String? language;
  final double? confidence;
  final Duration audioDuration;
  final Duration transcriptionDuration;
}

abstract interface class SttSessionPort {
  Stream<TranscriptUpdate> get updates;
  Future<void> push(Uint8List audio);
  Future<FinalTranscript> finish();
  Future<void> cancel();
}

abstract interface class SttPort {
  Future<void> warmUp();
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  });
  Future<void> close();
}

abstract interface class SpeechStopPort {
  Future<void> stopSpeech();
}

class StoredTranscript {
  const StoredTranscript({
    required this.transcriptId,
    required this.createdAt,
    required this.originalText,
    required this.provider,
    required this.audioDuration,
    required this.transcriptionDuration,
  });

  final String transcriptId;
  final DateTime createdAt;
  final String originalText;
  final String provider;
  final Duration audioDuration;
  final Duration transcriptionDuration;
}

abstract interface class LocalTranscriptStore {
  Future<void> save(StoredTranscript transcript);
  Future<void> delete(String transcriptId);
  Future<void> pruneBefore(DateTime cutoff);
}
