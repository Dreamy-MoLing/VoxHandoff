import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speech.dart';
import '../domain/voice.dart';
import '../domain/voice_provider_settings.dart';
import '../infrastructure/security/device_key_vault.dart';
import '../infrastructure/security/voice_provider_settings_store.dart';

final voiceProviderSettingsStoreProvider = Provider<VoiceProviderSettingsStore>(
  (_) => VoiceProviderSettingsStore(_EphemeralSecureValueStore()),
);

final voicePortFactoryProvider = Provider<VoicePortFactory>(
  (_) => const _UnconfiguredVoicePortFactory(),
);

final voiceProviderSettingsProvider =
    NotifierProvider<
      VoiceProviderSettingsController,
      VoiceProviderSettingsState
    >(VoiceProviderSettingsController.new);

class VoiceProviderSettingsState {
  const VoiceProviderSettingsState({
    required this.settings,
    this.restored = false,
    this.sttTest = const VoiceProviderTestStatus(),
    this.ttsTest = const VoiceProviderTestStatus(),
  });

  final VoiceProviderSettings settings;
  final bool restored;
  final VoiceProviderTestStatus sttTest;
  final VoiceProviderTestStatus ttsTest;

  VoiceProviderSettingsState copyWith({
    VoiceProviderSettings? settings,
    bool? restored,
    VoiceProviderTestStatus? sttTest,
    VoiceProviderTestStatus? ttsTest,
  }) => VoiceProviderSettingsState(
    settings: settings ?? this.settings,
    restored: restored ?? this.restored,
    sttTest: sttTest ?? this.sttTest,
    ttsTest: ttsTest ?? this.ttsTest,
  );
}

class VoiceProviderSettingsController
    extends Notifier<VoiceProviderSettingsState> {
  @override
  VoiceProviderSettingsState build() {
    unawaited(_restore());
    return VoiceProviderSettingsState(settings: _defaults());
  }

  Future<void> _restore() async {
    VoiceProviderSettings? saved;
    try {
      saved = await ref.read(voiceProviderSettingsStoreProvider).read();
    } on Object {
      state = state.copyWith(restored: true);
      return;
    }
    if (saved == null || state.restored) {
      state = state.copyWith(restored: true);
      return;
    }
    state = VoiceProviderSettingsState(settings: saved, restored: true);
  }

  Future<void> saveStt(SttProviderConfiguration configuration) async {
    if (!configuration.isSafe) {
      state = state.copyWith(
        sttTest: const VoiceProviderTestStatus(
          phase: VoiceProviderTestPhase.failed,
          safeMessage: 'Use a supported local STT configuration.',
        ),
      );
      return;
    }
    final settings = state.settings.copyWith(stt: configuration);
    await ref.read(voiceProviderSettingsStoreProvider).save(settings);
    state = state.copyWith(
      settings: settings,
      restored: true,
      sttTest: const VoiceProviderTestStatus(),
    );
  }

  Future<void> saveTts(TtsProviderConfiguration configuration) async {
    if (!configuration.isSafe) {
      state = state.copyWith(
        ttsTest: const VoiceProviderTestStatus(
          phase: VoiceProviderTestPhase.failed,
          safeMessage: 'Use an exact local Piper or GPT-SoVITS origin.',
        ),
      );
      return;
    }
    final settings = state.settings.copyWith(tts: configuration);
    await ref.read(voiceProviderSettingsStoreProvider).save(settings);
    state = state.copyWith(
      settings: settings,
      restored: true,
      ttsTest: const VoiceProviderTestStatus(),
    );
  }

  Future<void> saveMicrophoneId(String? microphoneId) async {
    final normalized = microphoneId?.trim();
    if (normalized != null && normalized.isEmpty) {
      return saveMicrophoneId(null);
    }
    if (normalized != null && normalized.length > 512) return;
    final settings = state.settings.copyWith(
      microphoneId: normalized,
      clearMicrophoneId: normalized == null,
    );
    await ref.read(voiceProviderSettingsStoreProvider).save(settings);
    state = state.copyWith(settings: settings, restored: true);
  }

  Future<void> testStt() =>
      _test(isStt: true, configuration: state.settings.stt);

  Future<void> testTts() =>
      _test(isStt: false, configuration: state.settings.tts);

  Future<void> _test({
    required bool isStt,
    required Object configuration,
  }) async {
    final testing = const VoiceProviderTestStatus(
      phase: VoiceProviderTestPhase.testing,
    );
    state = isStt
        ? state.copyWith(sttTest: testing)
        : state.copyWith(ttsTest: testing);
    final factory = ref.read(voicePortFactoryProvider);
    try {
      if (isStt) {
        final port = factory.createStt(
          configuration as SttProviderConfiguration,
        );
        try {
          await port.warmUp();
        } finally {
          await port.close();
        }
      } else {
        final port = factory.createTts(
          configuration as TtsProviderConfiguration,
        );
        try {
          await port.warmUp();
        } finally {
          await port.close();
        }
      }
      final ready = const VoiceProviderTestStatus(
        phase: VoiceProviderTestPhase.ready,
      );
      state = isStt
          ? state.copyWith(sttTest: ready)
          : state.copyWith(ttsTest: ready);
    } on Object catch (error) {
      final failure = _safeFailure(
        error,
        isStt ? VoiceFailureStage.stt : VoiceFailureStage.tts,
      );
      final failed = VoiceProviderTestStatus(
        phase: VoiceProviderTestPhase.failed,
        safeMessage: failure.safeMessage,
      );
      state = isStt
          ? state.copyWith(sttTest: failed)
          : state.copyWith(ttsTest: failed);
    }
  }
}

VoiceProviderSettings _defaults() {
  const baseUrl = String.fromEnvironment('VOXHANDOFF_GSV_BASE_URL');
  const referenceAudio = String.fromEnvironment('VOXHANDOFF_GSV_REF_AUDIO');
  const promptText = String.fromEnvironment('VOXHANDOFF_GSV_PROMPT_TEXT');
  final origin = Uri.tryParse(baseUrl);
  if (origin != null && referenceAudio.isNotEmpty) {
    final tts = TtsProviderConfiguration.gptSoVits(
      origin: origin,
      referenceAudioPath: referenceAudio,
      promptText: promptText,
    );
    if (tts.isSafe) return VoiceProviderSettings(tts: tts);
  }
  return const VoiceProviderSettings();
}

VoiceStageFailure _safeFailure(Object error, VoiceFailureStage fallback) =>
    switch (error) {
      VoicePortException() => error.failure,
      _ => VoiceStageFailure(
        stage: fallback,
        code: '${fallback.name}_connection_failed',
        safeMessage: fallback == VoiceFailureStage.stt
            ? 'The local STT service could not be reached.'
            : 'The local TTS service could not be reached.',
        retryable: true,
      ),
    };

class _UnconfiguredVoicePortFactory implements VoicePortFactory {
  const _UnconfiguredVoicePortFactory();

  @override
  SttPort createStt(SttProviderConfiguration configuration) =>
      const _UnavailableSttPort();

  @override
  TtsPort createTts(TtsProviderConfiguration configuration) =>
      const _UnavailableTtsPort();

  @override
  bool isTtsEnabled(TtsProviderConfiguration configuration) => false;
}

class _UnavailableSttPort implements SttPort {
  const _UnavailableSttPort();

  @override
  Future<void> close() async {}

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) => Future.error(_failure);

  @override
  Future<void> warmUp() => Future.error(_failure);

  static const _failure = VoicePortException(
    VoiceStageFailure(
      stage: VoiceFailureStage.configuration,
      code: 'voice_factory_unconfigured',
      safeMessage: 'Voice providers are not configured in this application.',
      retryable: false,
    ),
  );
}

class _UnavailableTtsPort implements TtsPort {
  const _UnavailableTtsPort();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() async {}

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) =>
      Future.error(_failure);

  @override
  Future<void> warmUp() => Future.error(_failure);

  static const _failure = VoicePortException(
    VoiceStageFailure(
      stage: VoiceFailureStage.configuration,
      code: 'voice_factory_unconfigured',
      safeMessage: 'Voice providers are not configured in this application.',
      retryable: false,
    ),
  );
}

class _EphemeralSecureValueStore implements SecureValueStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
