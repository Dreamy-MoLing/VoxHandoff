import 'package:agent_talk_client/application/voice_provider_settings_controller.dart';
import 'package:agent_talk_client/domain/interaction_mode.dart';
import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/domain/voice_provider_settings.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/voice_provider_settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'voice provider settings persist safe Piper fields and test independently',
    () async {
      final store = _MemorySecureStore();
      final factory = _FakeVoicePortFactory();
      final container = ProviderContainer(
        overrides: [
          voiceProviderSettingsStoreProvider.overrideWithValue(
            VoiceProviderSettingsStore(store),
          ),
          voicePortFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      container.read(voiceProviderSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(voiceProviderSettingsProvider.notifier)
          .saveTts(
            TtsProviderConfiguration.piper(
              origin: Uri.parse('http://127.0.0.1:5000'),
              voice: 'en_US-test',
              speaker: 'speaker-a',
              speakerId: 1,
              lengthScale: 1.2,
            ),
          );
      await container.read(voiceProviderSettingsProvider.notifier).testTts();

      final state = container.read(voiceProviderSettingsProvider);
      expect(state.settings.tts.kind, TtsProviderKind.piperHttp);
      expect(state.ttsTest.phase, VoiceProviderTestPhase.ready);
      expect(factory.ttsWarmups, 1);
      expect(store.values.values.single, contains('127.0.0.1'));
      expect(store.values.values.single, isNot(contains('Authorization')));
    },
  );

  test('unsafe TTS origin never reaches the factory or secure store', () async {
    final store = _MemorySecureStore();
    final factory = _FakeVoicePortFactory();
    final container = ProviderContainer(
      overrides: [
        voiceProviderSettingsStoreProvider.overrideWithValue(
          VoiceProviderSettingsStore(store),
        ),
        voicePortFactoryProvider.overrideWithValue(factory),
      ],
    );
    addTearDown(container.dispose);
    container.read(voiceProviderSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    await container
        .read(voiceProviderSettingsProvider.notifier)
        .saveTts(
          TtsProviderConfiguration.piper(
            origin: Uri.parse('http://tts.example.test:5000'),
          ),
        );

    final state = container.read(voiceProviderSettingsProvider);
    expect(state.ttsTest.phase, VoiceProviderTestPhase.failed);
    expect(factory.ttsWarmups, 0);
    expect(store.values, isEmpty);
  });

  test(
    'GPT-SoVITS settings round-trip its supported language fields',
    () async {
      final store = _MemorySecureStore();
      final container = ProviderContainer(
        overrides: [
          voiceProviderSettingsStoreProvider.overrideWithValue(
            VoiceProviderSettingsStore(store),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(voiceProviderSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(voiceProviderSettingsProvider.notifier)
          .saveTts(
            TtsProviderConfiguration.gptSoVits(
              origin: Uri.parse('http://127.0.0.1:9880'),
              referenceAudioPath: '/audio/reference.wav',
              promptText: '你好。',
              textLanguage: 'zh',
              promptLanguage: 'zh',
            ),
          );

      final restored = await VoiceProviderSettingsStore(store).read();
      expect(restored?.tts.kind, TtsProviderKind.gptSoVits);
      expect(restored?.tts.referenceAudioPath, '/audio/reference.wav');
      expect(restored?.tts.textLanguage, 'zh');
      expect(restored?.tts.promptLanguage, 'zh');
    },
  );

  test(
    'local STT model and microphone selection persist independently',
    () async {
      final store = _MemorySecureStore();
      final container = ProviderContainer(
        overrides: [
          voiceProviderSettingsStoreProvider.overrideWithValue(
            VoiceProviderSettingsStore(store),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(voiceProviderSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      final controller = container.read(voiceProviderSettingsProvider.notifier);
      await controller.saveStt(
        const SttProviderConfiguration(
          language: 'en',
          modelPath: '/models/fixture',
        ),
      );
      await controller.saveMicrophoneId('alsa_input.usb-test');

      final restored = await VoiceProviderSettingsStore(store).read();
      expect(restored?.stt.language, 'en');
      expect(restored?.stt.modelPath, '/models/fixture');
      expect(restored?.microphoneId, 'alsa_input.usb-test');
    },
  );

  test(
    'remote STT disclosure and token persist separately and test independently',
    () async {
      final store = _MemorySecureStore();
      final factory = _FakeVoicePortFactory();
      final container = ProviderContainer(
        overrides: [
          voiceProviderSettingsStoreProvider.overrideWithValue(
            VoiceProviderSettingsStore(store),
          ),
          voicePortFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      container.read(voiceProviderSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      final disclosure = RemoteSttProviderConfiguration(
        providerId: 'mobile-stt',
        origin: Uri.parse('https://stt.example.test'),
        tlsPolicy: 'system-roots-hostname-verified',
        retentionPolicy: 'fixture-no-retention',
        streaming: false,
        revision: 'v1',
        consentedAt: DateTime.utc(2026, 8, 13),
      );
      final controller = container.read(voiceProviderSettingsProvider.notifier);
      await controller.saveRemoteStt(disclosure, 'remote-token');
      await controller.testStt();

      final state = container.read(voiceProviderSettingsProvider);
      expect(state.settings.stt.kind, SttProviderKind.remoteHttps);
      expect(state.settings.stt.remote, disclosure);
      expect(state.sttTest.phase, VoiceProviderTestPhase.ready);
      expect(
        await RemoteSttSecretStore(store).read('mobile-stt'),
        'remote-token',
      );
      final settingsRecord = store.values.entries.singleWhere(
        (entry) => entry.key.contains('voice-provider-settings'),
      );
      expect(settingsRecord.value, contains('stt.example.test'));
      expect(settingsRecord.value, isNot(contains('remote-token')));
    },
  );

  test(
    'remote STT reuses the stored token when the form leaves it blank',
    () async {
      final store = _MemorySecureStore();
      final container = ProviderContainer(
        overrides: [
          voiceProviderSettingsStoreProvider.overrideWithValue(
            VoiceProviderSettingsStore(store),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(voiceProviderSettingsProvider);
      await Future<void>.delayed(Duration.zero);

      final disclosure = RemoteSttProviderConfiguration(
        providerId: 'mobile-stt',
        origin: Uri.parse('https://stt.example.test'),
        tlsPolicy: 'system-roots-hostname-verified',
        retentionPolicy: 'fixture-no-retention',
        streaming: false,
        revision: 'v1',
        consentedAt: DateTime.utc(2026, 8, 13),
      );
      final controller = container.read(voiceProviderSettingsProvider.notifier);
      await controller.saveRemoteStt(disclosure, 'remote-token');

      final updated = disclosure.copyWith(
        origin: Uri.parse('https://updated-stt.example.test'),
        consentedAt: DateTime.utc(2026, 8, 14),
      );
      await controller.saveRemoteStt(updated, '');

      expect(
        container.read(voiceProviderSettingsProvider).settings.stt.remote,
        updated,
      );
      expect(
        await RemoteSttSecretStore(store).read('mobile-stt'),
        'remote-token',
      );
    },
  );

  test('remote STT cannot be saved without explicit consent', () async {
    final store = _MemorySecureStore();
    final container = ProviderContainer(
      overrides: [
        voiceProviderSettingsStoreProvider.overrideWithValue(
          VoiceProviderSettingsStore(store),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(voiceProviderSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    await container
        .read(voiceProviderSettingsProvider.notifier)
        .saveRemoteStt(
          RemoteSttProviderConfiguration(
            providerId: 'mobile-stt',
            origin: Uri(scheme: 'https', host: 'stt.example.test'),
            tlsPolicy: 'system-roots-hostname-verified',
            retentionPolicy: 'fixture-no-retention',
            streaming: false,
            revision: 'v1',
          ),
          'remote-token',
        );

    expect(
      container.read(voiceProviderSettingsProvider).sttTest.phase,
      VoiceProviderTestPhase.failed,
    );
    expect(store.values, isEmpty);
  });

  test(
    'speech rate conversion is monotonic and inverse to Piper length scale',
    () {
      expect(piperLengthScaleForSpeechRate(0.5), 2);
      expect(piperLengthScaleForSpeechRate(2), 0.5);
      expect(
        speechRateForPiperLengthScale(piperLengthScaleForSpeechRate(1.25)),
        closeTo(1.25, 0.000001),
      );
      expect(() => piperLengthScaleForSpeechRate(2.01), throwsArgumentError);
    },
  );

  test('interaction mode default persists and restores', () async {
    final store = _MemorySecureStore();
    final container = ProviderContainer(
      overrides: [
        voiceProviderSettingsStoreProvider.overrideWithValue(
          VoiceProviderSettingsStore(store),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(voiceProviderSettingsProvider);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(voiceProviderSettingsProvider).settings.interactionMode,
      InteractionMode.command,
    );

    await container
        .read(voiceProviderSettingsProvider.notifier)
        .saveInteractionMode(InteractionMode.call);

    expect(
      container.read(voiceProviderSettingsProvider).settings.interactionMode,
      InteractionMode.call,
    );
    final restored = await VoiceProviderSettingsStore(store).read();
    expect(restored?.interactionMode, InteractionMode.call);
    expect(store.values.values.single, contains('"interaction_mode":"call"'));
  });

  test(
    'missing interaction mode in a legacy record defaults to command',
    () async {
      final store = _MemorySecureStore();
      await store.write(
        'voxhandoff.v1.voice-provider-settings',
        '{"version":3,"assistant_id":"unbound-assistant",'
            '"assistant_revision":1,'
            '"stt":{"kind":"disabled","language":"zh"},'
            '"tts":{"kind":"disabled"}}',
      );
      final restored = await VoiceProviderSettingsStore(store).read();
      expect(restored?.interactionMode, InteractionMode.command);
    },
  );
}

class _MemorySecureStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _FakeVoicePortFactory implements VoicePortFactory {
  var ttsWarmups = 0;

  @override
  SttPort createStt(SttProviderConfiguration configuration) => _FakeSttPort();

  @override
  TtsPort createTts(TtsProviderConfiguration configuration) =>
      _FakeTtsPort(onWarmUp: () => ttsWarmups += 1);

  @override
  bool isTtsEnabled(TtsProviderConfiguration configuration) =>
      configuration.kind != TtsProviderKind.disabled;
}

class _FakeSttPort implements SttPort {
  @override
  Future<void> close() async {}

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) => throw UnimplementedError();

  @override
  Future<void> warmUp() async {}
}

class _FakeTtsPort implements TtsPort {
  _FakeTtsPort({required this.onWarmUp});

  final void Function() onWarmUp;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() async {}

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) =>
      throw UnimplementedError();

  @override
  Future<void> warmUp() async => onWarmUp();
}
