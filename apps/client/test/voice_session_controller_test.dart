import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/voice_session_controller.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recording stops speech, streams audio, and leaves final editable',
    () async {
      final capture = _FakeCapturePort();
      final stt = _FakeSttPort();
      final speech = _FakeSpeechStop();
      final store = _FakeTranscriptStore();
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(capture),
          sttPortProvider.overrideWithValue(stt),
          speechStopPortProvider.overrideWithValue(speech),
          localTranscriptStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);

      await container.read(voiceSessionProvider.notifier).startRecording();
      expect(
        container.read(voiceSessionProvider).phase,
        VoiceInputPhase.recording,
      );
      expect(speech.stops, 1);

      stt.session.updatesController.add(
        const TranscriptUpdate(text: '检查核心', sequence: 1),
      );
      capture.session.audioController.add(Uint8List.fromList([1, 0, 2, 0]));
      capture.session.levelController.add(0.6);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(voiceSessionProvider).provisionalTranscript,
        '检查核心',
      );

      final stopping = container
          .read(voiceSessionProvider.notifier)
          .stopRecording();
      await Future<void>.delayed(Duration.zero);
      capture.session.audioController.close();
      await stopping;

      final voice = container.read(voiceSessionProvider);
      final draft = container.read(clientSessionProvider);
      expect(voice.phase, VoiceInputPhase.awaitingConfirmation);
      expect(voice.originalTranscript, '检查 packages/core 的测试。');
      expect(draft.draftText, '检查 packages/core 的测试。');
      expect(draft.draftPhase, DraftPhase.editing);
      expect(stt.session.pushed, hasLength(1));
      expect(store.saved, hasLength(1));
    },
  );

  test(
    'recording cancel discards local media without touching the draft',
    () async {
      final capture = _FakeCapturePort();
      final stt = _FakeSttPort();
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(capture),
          sttPortProvider.overrideWithValue(stt),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(clientSessionProvider.notifier)
          .editDraft('keep this draft');

      await container.read(voiceSessionProvider.notifier).startRecording();
      await container.read(voiceSessionProvider.notifier).cancelRecording();

      expect(
        container.read(voiceSessionProvider).phase,
        VoiceInputPhase.cancelled,
      );
      expect(
        container.read(clientSessionProvider).draftText,
        'keep this draft',
      );
      expect(capture.session.cancelled, 1);
      expect(stt.session.cancelled, 1);
      expect(stt.session.finished, 0);
    },
  );

  test(
    'permission denial is a recording failure and never starts STT audio',
    () async {
      final capture = _FakeCapturePort(
        startFailure: const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.recording,
            code: 'recording_permission_denied',
            safeMessage: 'Microphone permission was denied.',
            retryable: false,
          ),
        ),
      );
      final stt = _FakeSttPort();
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(capture),
          sttPortProvider.overrideWithValue(stt),
        ],
      );
      addTearDown(container.dispose);

      await container.read(voiceSessionProvider.notifier).startRecording();

      final voice = container.read(voiceSessionProvider);
      expect(voice.phase, VoiceInputPhase.failed);
      expect(voice.failure?.stage, VoiceFailureStage.recording);
      expect(voice.failure?.code, 'recording_permission_denied');
      expect(stt.session.cancelled, 1);
      expect(container.read(clientSessionProvider).draftText, isEmpty);
    },
  );

  test(
    'STT failure leaves prior text and submission state independent',
    () async {
      final capture = _FakeCapturePort();
      final stt = _FakeSttPort();
      stt.session.finishFailure = const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.stt,
          code: 'stt_no_audio',
          safeMessage: 'No speech was detected in the recording.',
          retryable: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(capture),
          sttPortProvider.overrideWithValue(stt),
        ],
      );
      addTearDown(container.dispose);
      container.read(clientSessionProvider.notifier).editDraft('existing text');

      await container.read(voiceSessionProvider.notifier).startRecording();
      final stopping = container
          .read(voiceSessionProvider.notifier)
          .stopRecording();
      capture.session.audioController.close();
      await stopping;

      expect(
        container.read(voiceSessionProvider).failure?.code,
        'stt_no_audio',
      );
      expect(container.read(clientSessionProvider).draftText, 'existing text');
    },
  );

  test(
    'confirmed or uncertain draft cannot be overwritten by recording',
    () async {
      final container = ProviderContainer(
        overrides: [
          audioCapturePortProvider.overrideWithValue(_FakeCapturePort()),
          sttPortProvider.overrideWithValue(_FakeSttPort()),
        ],
      );
      addTearDown(container.dispose);
      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('confirmed command');
      draft.confirmDraft();

      await container.read(voiceSessionProvider.notifier).startRecording();

      expect(
        container.read(voiceSessionProvider).failure?.code,
        'voice_draft_not_editable',
      );
      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.confirmed,
      );
    },
  );
}

class _FakeCapturePort implements AudioCapturePort {
  _FakeCapturePort({this.startFailure});

  final Object? startFailure;
  final session = _FakeCaptureSession();

  @override
  Future<AudioCaptureSession> start(AudioCaptureConfig config) async {
    if (startFailure case final failure?) throw failure;
    return session;
  }

  @override
  Future<void> close() async {}
}

class _FakeCaptureSession implements AudioCaptureSession {
  final audioController = StreamController<Uint8List>();
  final levelController = StreamController<double>();
  int stopped = 0;
  int cancelled = 0;

  @override
  Stream<Uint8List> get audioChunks => audioController.stream;

  @override
  Stream<double> get levels => levelController.stream;

  @override
  Future<void> cancel() async {
    cancelled += 1;
  }

  @override
  Future<void> stop() async {
    stopped += 1;
  }
}

class _FakeSttPort implements SttPort {
  final session = _FakeSttSession();

  @override
  Future<void> close() async {}

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) async => session;

  @override
  Future<void> warmUp() async {}
}

class _FakeSttSession implements SttSessionPort {
  final updatesController = StreamController<TranscriptUpdate>.broadcast();
  final List<Uint8List> pushed = [];
  int finished = 0;
  int cancelled = 0;
  Object? finishFailure;

  @override
  Stream<TranscriptUpdate> get updates => updatesController.stream;

  @override
  Future<void> cancel() async {
    cancelled += 1;
  }

  @override
  Future<FinalTranscript> finish() async {
    finished += 1;
    if (finishFailure case final failure?) throw failure;
    return const FinalTranscript(
      text: '检查 packages/core 的测试。',
      language: 'zh',
      confidence: 0.99,
      audioDuration: Duration(seconds: 2),
      transcriptionDuration: Duration(milliseconds: 700),
    );
  }

  @override
  Future<void> push(Uint8List audio) async {
    pushed.add(audio);
  }
}

class _FakeSpeechStop implements SpeechStopPort {
  int stops = 0;

  @override
  Future<void> stopSpeech() async {
    stops += 1;
  }
}

class _FakeTranscriptStore implements LocalTranscriptStore {
  final List<StoredTranscript> saved = [];

  @override
  Future<void> delete(String transcriptId) async {}

  @override
  Future<void> pruneBefore(DateTime cutoff) async {}

  @override
  Future<void> save(StoredTranscript transcript) async {
    saved.add(transcript);
  }
}
