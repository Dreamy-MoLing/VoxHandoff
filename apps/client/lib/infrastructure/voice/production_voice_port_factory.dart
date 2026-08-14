import 'dart:io';

import '../../domain/speech.dart';
import '../../domain/voice.dart';
import '../../domain/voice_provider_settings.dart';
import '../security/device_key_vault.dart';
import '../security/flutter_secure_value_store.dart';
import '../security/voice_provider_settings_store.dart';
import '../stt/bundled_stt_launcher.dart';
import '../stt/remote_stt_port.dart';
import '../stt/stdio_stt_port.dart';
import '../stt/unavailable_stt_port.dart';
import '../tts/gpt_sovits_tts_port.dart';
import '../tts/piper_http_tts_port.dart';

class ProductionVoicePortFactory implements VoicePortFactory {
  ProductionVoicePortFactory({
    SecureValueStore? secureValueStore,
    List<int>? remoteTrustedRootCertificates,
    this._remoteTransportFactory,
  }) : _secureValueStore = secureValueStore ?? FlutterSecureValueStore(),
       _remoteTrustedRootCertificates = remoteTrustedRootCertificates == null
           ? null
           : List.unmodifiable(remoteTrustedRootCertificates);

  final SecureValueStore _secureValueStore;
  final List<int>? _remoteTrustedRootCertificates;
  final RemoteSttTransport Function(
    RemoteSttProviderConfiguration configuration,
    RemoteSttTokenProvider tokenProvider,
  )?
  _remoteTransportFactory;

  @override
  SttPort createStt(SttProviderConfiguration configuration) {
    if (configuration.kind == SttProviderKind.disabled) {
      return const UnavailableSttPort(
        safeMessage: 'Speech recognition is disabled in Voice settings.',
      );
    }
    if (configuration.kind == SttProviderKind.remoteHttps) {
      final remote = configuration.remote;
      if (remote == null || !remote.isSafe) {
        return const UnavailableSttPort(
          safeMessage:
              'Review and accept the exact HTTPS remote speech provider disclosure.',
        );
      }
      final disclosure = RemoteSttDisclosure(
        providerId: remote.providerId,
        origin: remote.origin,
        tlsPolicy: remote.tlsPolicy,
        retentionPolicy: remote.retentionPolicy,
        streaming: remote.streaming,
        revision: remote.revision,
      );
      final tokenStore = RemoteSttSecretStore(_secureValueStore);
      Future<String> tokenProvider(String providerId) async =>
          await tokenStore.read(providerId) ?? '';
      final transport =
          _remoteTransportFactory?.call(remote, tokenProvider) ??
          JsonHttpRemoteSttTransport(
            tokenProvider: tokenProvider,
            trustedRootCertificates: _remoteTrustedRootCertificates,
          );
      return ConsentedRemoteSttPort(
        disclosure: disclosure,
        consent: RemoteSttConsent(
          disclosure: disclosure,
          acceptedAt: remote.consentedAt!,
        ),
        transport: transport,
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
