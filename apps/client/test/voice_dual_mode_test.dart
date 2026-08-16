import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/voice_provider_settings_controller.dart';
import 'package:agent_talk_client/application/voice_session_controller.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/interaction_mode.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> enableCallMode(ProviderContainer container) async {
    await container
        .read(voiceProviderSettingsProvider.notifier)
        .saveInteractionMode(InteractionMode.call);
  }

  test(
    'call mode stops into a lightweight preview and keeps the draft editable',
    () async {
      final capture = _FakeDualCapture();
      final stt = _FakeDualStt();
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(capture),
          sttPortProvider.overrideWithValue(stt),
        ],
      );
      addTearDown(container.dispose);
      await enableCallMode(container);

      await container.read(voiceSessionProvider.notifier).startRecording();
      capture.session.audioController.close();
      await container.read(voiceSessionProvider.notifier).stopRecording();

      final state = container.read(voiceSessionProvider);
      expect(state.phase, VoiceInputPhase.awaitingCallConfirm);
      expect(state.interactionMode, InteractionMode.call);
      expect(state.finalTranscript, '检查 packages/core 的测试。');
      expect(
        container.read(clientSessionProvider).draftText,
        '检查 packages/core 的测试。',
      );
      expect(container.read(clientSessionProvider).draftPhase, DraftPhase.editing);
      expect(state.canConfirmCallSend, isTrue);
      expect(state.canDiscardCallConfirm, isTrue);
      await container.read(voiceSessionProvider.notifier).discardTranscript();
    },
  );

  test('command mode keeps the explicit awaitingConfirmation flow', () async {
    final capture = _FakeDualCapture();
    final stt = _FakeDualStt();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);

    await container.read(voiceSessionProvider.notifier).startRecording();
    capture.session.audioController.close();
    await container.read(voiceSessionProvider.notifier).stopRecording();

    final state = container.read(voiceSessionProvider);
    expect(state.phase, VoiceInputPhase.awaitingConfirmation);
    expect(state.interactionMode, InteractionMode.command);
    expect(state.canConfirmCallSend, isFalse);
    await container.read(voiceSessionProvider.notifier).discardTranscript();
  });

  test('a mid-session mode switch applies to this recording', () async {
    final capture = _FakeDualCapture();
    final stt = _FakeDualStt();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);
    final voice = container.read(voiceSessionProvider.notifier);

    await voice.startRecording();
    voice.setInteractionMode(InteractionMode.call);
    capture.session.audioController.close();
    await voice.stopRecording();

    expect(
      container.read(voiceSessionProvider).phase,
      VoiceInputPhase.awaitingCallConfirm,
    );
    await voice.discardTranscript();
  });

  test(
    'sensitive work-type wording downgrades call mode to command confirmation',
    () async {
      for (final transcript in ['请删除这个文件', '批准发布上线', '完成 sudo 操作']) {
        final capture = _FakeDualCapture(transcript: transcript);
        final stt = _FakeDualStt(transcript: transcript);
        final container = ProviderContainer(
          overrides: [
            audioCapturePortProvider.overrideWithValue(capture),
            sttPortProvider.overrideWithValue(stt),
          ],
        );
        addTearDown(container.dispose);
        await enableCallMode(container);

        await container.read(voiceSessionProvider.notifier).startRecording();
        capture.session.audioController.close();
        await container.read(voiceSessionProvider.notifier).stopRecording();

        final state = container.read(voiceSessionProvider);
        expect(
          state.phase,
          VoiceInputPhase.awaitingConfirmation,
          reason: transcript,
        );
        expect(state.canConfirmCallSend, isFalse, reason: transcript);
        await container.read(voiceSessionProvider.notifier).discardTranscript();
      }
    },
  );

  test(
    'call preview confirms through the registered send handler only once',
    () async {
      final capture = _FakeDualCapture();
      final stt = _FakeDualStt();
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(capture),
          sttPortProvider.overrideWithValue(stt),
        ],
      );
      addTearDown(container.dispose);
      final sent = <String>[];
      container.read(voiceCallSendHandlerProvider.notifier).register((
        text,
      ) async {
        sent.add(text);
      });
      await enableCallMode(container);

      await container.read(voiceSessionProvider.notifier).startRecording();
      capture.session.audioController.close();
      await container.read(voiceSessionProvider.notifier).stopRecording();
      await container.read(voiceSessionProvider.notifier).confirmCallSend();

      expect(sent, ['检查 packages/core 的测试。']);
      final state = container.read(voiceSessionProvider);
      expect(state.phase, VoiceInputPhase.idle);
      expect(state.finalTranscript, isNull);
    },
  );

  test('call preview without a wired send handler fails safe, keeping text', () async {
    final capture = _FakeDualCapture();
    final stt = _FakeDualStt();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);
    await enableCallMode(container);

    await container.read(voiceSessionProvider.notifier).startRecording();
    capture.session.audioController.close();
    await container.read(voiceSessionProvider.notifier).stopRecording();
    await container.read(voiceSessionProvider.notifier).confirmCallSend();

    final state = container.read(voiceSessionProvider);
    expect(state.phase, VoiceInputPhase.failed);
    expect(state.failure?.code, 'call_send_unavailable');
    expect(state.finalTranscript, '检查 packages/core 的测试。');
    expect(
      container.read(clientSessionProvider).draftText,
      '检查 packages/core 的测试。',
    );
  });

  test('call preview discard removes the editable draft and echoes idle', () async {
    final capture = _FakeDualCapture();
    final stt = _FakeDualStt();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);
    await enableCallMode(container);

    await container.read(voiceSessionProvider.notifier).startRecording();
    capture.session.audioController.close();
    await container.read(voiceSessionProvider.notifier).stopRecording();
    await container.read(voiceSessionProvider.notifier).discardTranscript();

    final state = container.read(voiceSessionProvider);
    expect(state.phase, VoiceInputPhase.idle);
    expect(state.sessionId, isNull);
    expect(container.read(clientSessionProvider).draftText, isEmpty);
  });

  test('call preview auto-discards after the configured timeout', () async {
    final capture = _FakeDualCapture();
    final stt = _FakeDualStt();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);
    final voice = container.read(voiceSessionProvider.notifier);
    voice.callConfirmTimeout = const Duration(milliseconds: 30);
    await enableCallMode(container);

    await voice.startRecording();
    capture.session.audioController.close();
    await voice.stopRecording();
    expect(
      container.read(voiceSessionProvider).phase,
      VoiceInputPhase.awaitingCallConfirm,
    );

    await _eventually(
      () => container.read(voiceSessionProvider).phase == VoiceInputPhase.idle,
    );
    expect(
      container.read(clientSessionProvider).draftText,
      isEmpty,
    );
  });

  test('setting the persisted default seeds the next recording', () async {
    final capture = _FakeDualCapture();
    final stt = _FakeDualStt();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);
    await enableCallMode(container);

    await container.read(voiceSessionProvider.notifier).startRecording();
    await container.read(voiceSessionProvider.notifier).cancelRecording();

    expect(
      container.read(voiceSessionProvider).interactionMode,
      InteractionMode.call,
    );
  });
}

class _FakeDualCapture implements AudioCapturePort {
  _FakeDualCapture({this.transcript});

  final String? transcript;
  final session = _FakeDualCaptureSession();

  @override
  Future<AudioCaptureSession> start(AudioCaptureConfig config) async => session;

  @override
  Future<void> close() async {}
}

class _FakeDualCaptureSession implements AudioCaptureSession {
  final audioController = StreamController<Uint8List>();
  final levelController = StreamController<double>();

  @override
  Stream<Uint8List> get audioChunks => audioController.stream;

  @override
  Stream<double> get levels => levelController.stream;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> stop() async {}
}

class _FakeDualStt implements SttPort {
  _FakeDualStt({this.transcript});

  final String? transcript;

  @override
  Future<void> close() async {}

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) async => _FakeDualSttSession(transcript: transcript);

  @override
  Future<void> warmUp() async {}
}

class _FakeDualSttSession implements SttSessionPort {
  _FakeDualSttSession({this.transcript});

  final String? transcript;

  @override
  Stream<TranscriptUpdate> get updates => const Stream.empty();

  @override
  Future<void> push(Uint8List audio) async {}

  @override
  Future<FinalTranscript> finish() async => FinalTranscript(
    text: transcript ?? '检查 packages/core 的测试。',
    language: 'zh',
    confidence: 0.99,
    audioDuration: const Duration(seconds: 2),
    transcriptionDuration: const Duration(milliseconds: 700),
  );

  @override
  Future<void> cancel() async {}
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 200; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition did not become true.');
}