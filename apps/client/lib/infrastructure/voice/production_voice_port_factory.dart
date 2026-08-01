import 'dart:io';

import '../../domain/speech.dart';
import '../../domain/voice.dart';
import '../../domain/voice_provider_settings.dart';
import '../stt/bundled_stt_launcher.dart';
import '../stt/stdio_stt_port.dart';
import '../stt/unavailable_stt_port.dart';
import '../tts/gpt_sovits_tts_port.dart';
import '../tts/piper_http_tts_port.dart';

class ProductionVoicePortFactory implements VoicePortFactory {
  const ProductionVoicePortFactory();

  @override
  SttPort createStt(SttProviderConfiguration configuration) {
    if (configuration.kind == SttProviderKind.disabled) {
      return const UnavailableSttPort(
        safeMessage: 'Speech recognition is disabled in Voice settings.',
      );
    }
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      return StdioSttPort(
        launch: bundledSttLauncher(modelPath: configuration.modelPath),
      );
    }
    return const UnavailableSttPort(
      safeMessage:
          'Local faster-whisper runs only in the desktop bundle. Configure a consented remote provider on mobile.',
    );
  }

  @override
  TtsPort createTts(TtsProviderConfiguration configuration) {
    try {
      return switch (configuration.kind) {
        TtsProviderKind.disabled => const _UnavailableTtsPort(),
        TtsProviderKind.piperHttp => PiperHttpTtsPort(
          config: PiperHttpTtsConfig(
            baseUri: configuration.origin!,
            voice: configuration.voice,
            speaker: configuration.speaker,
            speakerId: configuration.speakerId,
            lengthScale: configuration.lengthScale,
          ),
        ),
        TtsProviderKind.gptSoVits => GptSoVitsTtsPort(
          config: GptSoVitsConfig(
            baseUri: configuration.origin!,
            referenceAudioPath: configuration.referenceAudioPath!,
            promptText: configuration.promptText!,
            textLanguage: configuration.textLanguage,
            promptLanguage: configuration.promptLanguage,
          ),
        ),
      };
    } on Object {
      return const _UnavailableTtsPort();
    }
  }

  @override
  bool isTtsEnabled(TtsProviderConfiguration configuration) =>
      configuration.kind != TtsProviderKind.disabled;
}

class _UnavailableTtsPort implements TtsPort {
  const _UnavailableTtsPort();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() async {}

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) => Future.error(
    const VoicePortException(
      VoiceStageFailure(
        stage: VoiceFailureStage.configuration,
        code: 'tts_not_configured',
        safeMessage: 'Speech synthesis is not configured.',
        retryable: false,
      ),
    ),
  );

  @override
  Future<void> warmUp() => Future.error(
    const VoicePortException(
      VoiceStageFailure(
        stage: VoiceFailureStage.configuration,
        code: 'tts_not_configured',
        safeMessage: 'Speech synthesis is not configured.',
        retryable: false,
      ),
    ),
  );
}
