import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/voice_provider_settings_controller.dart';
import 'package:agent_talk_client/application/voice_session_controller.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/domain/voice_provider_settings.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/voice_provider_settings_store.dart';
import 'package:agent_talk_client/infrastructure/voice/production_voice_port_factory.dart';
import 'package:agent_talk_client/infrastructure/stt/remote_stt_port.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production factory injects consented remote STT on every platform',
    () async {
      final store = _MemorySecureStore();
      await store.write(
        'voxhandoff.v1.remote-stt-token.mobile-stt',
        'fixture-token',
      );
      RemoteSttDisclosure? receivedDisclosure;
      String? receivedToken;
      final factory = ProductionVoicePortFactory(
        secureValueStore: store,
        remoteTransportFactory: (configuration, tokenProvider) {
          receivedDisclosure = RemoteSttDisclosure(
            providerId: configuration.providerId,
            origin: configuration.origin,
            tlsPolicy: configuration.tlsPolicy,
            retentionPolicy: configuration.retentionPolicy,
            streaming: configuration.streaming,
            revision: configuration.revision,
          );
          return _FakeRemoteTransport(
            onWarmUp: () async =>
                receivedToken = await tokenProvider('mobile-stt'),
          );
        },
      );
      final configuration = RemoteSttProviderConfiguration(
        providerId: 'mobile-stt',
        origin: Uri.parse('https://stt.example.test'),
        tlsPolicy: 'system-roots-hostname-verified',
        retentionPolicy: 'fixture-no-retention',
        streaming: false,
        revision: 'v1',
        consentedAt: DateTime.utc(2026, 8, 13),
      );

      final port = factory.createStt(
        SttProviderConfiguration.remote(remote: configuration),
      );
      await port.warmUp();
      await port.close();

      expect(receivedDisclosure?.origin, configuration.origin);
      expect(receivedDisclosure?.retentionPolicy, 'fixture-no-retention');
      expect(receivedToken, 'fixture-token');
    },
  );

  test('production factory forwards the current Gateway trust roots', () async {
    var roots = <int>[1, 2, 3];
    final resolved = <List<int>>[];
    final factory = ProductionVoicePortFactory(
      secureValueStore: _MemorySecureStore(),
      remoteTrustedRootCertificatesProvider: () async {
        resolved.add(List<int>.from(roots));
        return roots;
      },
    );
    final configuration = RemoteSttProviderConfiguration(
      providerId: 'mobile-stt',
      origin: Uri.parse('https://stt.example.test'),
      tlsPolicy: 'system-roots-hostname-verified',
      retentionPolicy: 'fixture-no-retention',
      streaming: false,
      revision: 'v1',
      consentedAt: DateTime.utc(2026, 8, 13),
    );

    final first = factory.createStt(
      SttProviderConfiguration.remote(remote: configuration),
    );
    await expectLater(first.warmUp(), throwsA(isA<FormatException>()));
    await first.close();

    roots = [4, 5, 6];
    final second = factory.createStt(
      SttProviderConfiguration.remote(remote: configuration),
    );
    await expectLater(second.warmUp(), throwsA(isA<FormatException>()));
    await second.close();

    expect(resolved, [
      [1, 2, 3],
      [4, 5, 6],
    ]);
  });

  test(
    'production remote STT completes the editable voice draft flow',
    () async {
      final store = _MemorySecureStore();
      final capture = _FakeCapturePort();
      final transport = _FakeRemoteTransport(
        onTranscribe: () async => const FinalTranscript(
          text: '手机语音终稿。',
          audioDuration: Duration(milliseconds: 240),
          transcriptionDuration: Duration(milliseconds: 12),
        ),
      );
      RemoteSttTransport remoteTransportFactory(
        RemoteSttProviderConfiguration configuration,
        RemoteSttTokenProvider tokenProvider,
      ) => transport;
      final factory = ProductionVoicePortFactory(
        secureValueStore: store,
        remoteTransportFactory: remoteTransportFactory,
      );
      final container = ProviderContainer(
        overrides: [
          voiceProviderSettingsStoreProvider.overrideWithValue(
            VoiceProviderSettingsStore(store),
          ),
          voicePortFactoryProvider.overrideWithValue(factory),
          audioCapturePortProvider.overrideWithValue(capture),
          speechStopPortProvider.overrideWithValue(_FakeSpeechStop()),
        ],
      );
      addTearDown(container.dispose);
      final disclosure = RemoteSttProviderConfiguration(
        providerId: 'mobile-stt',
        origin: Uri.parse('https://stt.example.test'),
        tlsPolicy: 'system-roots-hostname-verified',
        retentionPolicy: 'fixture-no-retention',
        streaming: false,
        revision: 'v1',
        consentedAt: DateTime.utc(2026, 8, 13),
      );
      await container
          .read(voiceProviderSettingsProvider.notifier)
          .saveRemoteStt(disclosure, 'fixture-token');

      final voice = container.read(voiceSessionProvider.notifier);
      await voice.startRecording();
      expect(
        container.read(voiceSessionProvider).phase,
        VoiceInputPhase.recording,
      );
      capture.session.audioController.add(Uint8List.fromList([1, 0, 2, 0]));
      await voice.stopRecording();

      expect(
        container.read(voiceSessionProvider).phase,
        VoiceInputPhase.awaitingConfirmation,
      );
      expect(container.read(clientSessionProvider).draftText, '手机语音终稿。');
      expect(transport.request?.audio, Uint8List.fromList([1, 0, 2, 0]));
      expect(transport.request?.language, 'zh');
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

class _FakeRemoteTransport implements RemoteSttTransport {
  _FakeRemoteTransport({this.onWarmUp, this.onTranscribe});

  final Future<void> Function()? onWarmUp;
  final Future<FinalTranscript> Function()? onTranscribe;
  RemoteSttRequest? request;

  @override
  Future<void> warmUp(RemoteSttDisclosure disclosure) async {
    await onWarmUp?.call();
  }

  @override
  Future<FinalTranscript> transcribe(
    RemoteSttDisclosure disclosure,
    RemoteSttRequest request,
  ) async {
    this.request = request;
    return onTranscribe?.call() ??
        const FinalTranscript(
          text: 'fixture',
          audioDuration: Duration(milliseconds: 1),
          transcriptionDuration: Duration(milliseconds: 1),
        );
  }

  @override
  Future<void> close() async {}
}

class _FakeCapturePort implements AudioCapturePort {
  final session = _FakeCaptureSession();

  @override
  Future<AudioCaptureSession> start(AudioCaptureConfig config) async => session;

  @override
  Future<void> close() async {}
}

class _FakeCaptureSession implements AudioCaptureSession {
  final audioController = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get audioChunks => audioController.stream;

  @override
  Stream<double> get levels => const Stream.empty();

  @override
  Future<void> cancel() async {
    if (!audioController.isClosed) await audioController.close();
  }

  @override
  Future<void> stop() async {
    if (!audioController.isClosed) await audioController.close();
  }
}

class _FakeSpeechStop implements SpeechStopPort {
  @override
  Future<void> stopSpeech() async {}
}
