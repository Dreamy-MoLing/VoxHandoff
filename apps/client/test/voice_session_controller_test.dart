import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/speech_playback_controller.dart';
import 'package:agent_talk_client/application/voice_provider_settings_controller.dart';
import 'package:agent_talk_client/application/voice_session_controller.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/domain/voice_provider_settings.dart';
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
      stt.session.updatesController.add(
        const TranscriptUpdate(text: '检查核心测试', sequence: 3),
      );
      stt.session.updatesController.add(
        const TranscriptUpdate(text: '迟到旧文本', sequence: 2),
      );
      capture.session.audioController.add(Uint8List.fromList([1, 0, 2, 0]));
      capture.session.levelController.add(0.6);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(voiceSessionProvider).provisionalTranscript,
        '检查核心测试',
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

  test('recording interrupts TTS without waiting for speech cleanup', () async {
    final capture = _FakeCapturePort();
    final stt = _FakeSttPort();
    final interruptStarted = Completer<void>();
    final interruptGate = Completer<void>();
    final playback = _SpySpeechPlaybackController(
      interruptStarted: interruptStarted,
      interruptGate: interruptGate,
    );
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
        speechStopPortProvider.overrideWithValue(_FakeSpeechStop()),
        speechPlaybackProvider.overrideWith(() => playback),
      ],
    );
    addTearDown(() {
      if (!interruptGate.isCompleted) interruptGate.complete();
      container.dispose();
    });

    final starting = container
        .read(voiceSessionProvider.notifier)
        .startRecording();
    await interruptStarted.future;
    await _eventually(
      () =>
          container.read(voiceSessionProvider).phase ==
          VoiceInputPhase.recording,
    );
    expect(playback.interruptions, 1);

    interruptGate.complete();
    await starting;
    await container.read(voiceSessionProvider.notifier).cancelRecording();
  });

  test('recording forwards the configured STT language', () async {
    final capture = _FakeCapturePort();
    final stt = _FakeSttPort();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
        voiceProviderSettingsProvider.overrideWith(
          _ConfiguredVoiceProviderSettingsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(voiceSessionProvider.notifier).startRecording();

    expect(stt.requestedLanguage, 'en');
    await container.read(voiceSessionProvider.notifier).cancelRecording();
  });

  test('stop waits for pending audio push before finishing STT', () async {
    final capture = _FakeCapturePort();
    capture.session.closeAudioOnStop = true;
    final stt = _FakeSttPort();
    stt.session.pushCompleter = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);

    await container.read(voiceSessionProvider.notifier).startRecording();
    capture.session.audioController.add(Uint8List.fromList([1, 0, 2, 0]));
    await _eventually(() => stt.session.pushStarted == 1);

    final stopping = container
        .read(voiceSessionProvider.notifier)
        .stopRecording();
    await Future<void>.delayed(Duration.zero);
    expect(stt.session.finished, 0);

    stt.session.pushCompleter!.complete();
    await stopping;

    expect(stt.session.pushed, hasLength(1));
    expect(stt.session.finished, 1);
    expect(
      container.read(voiceSessionProvider).phase,
      VoiceInputPhase.awaitingConfirmation,
    );
  });

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

  test('transcribing cancel reaches STT and rejects the late final', () async {
    final capture = _FakeCapturePort();
    final stt = _FakeSttPort();
    stt.session.finishCompleter = Completer<FinalTranscript>();
    final container = ProviderContainer(
      overrides: [
        audioCapturePortProvider.overrideWithValue(capture),
        sttPortProvider.overrideWithValue(stt),
      ],
    );
    addTearDown(container.dispose);

    await container.read(voiceSessionProvider.notifier).startRecording();
    final stopping = container
        .read(voiceSessionProvider.notifier)
        .stopRecording();
    await capture.session.audioController.close();
    await _eventually(() => stt.session.finished == 1);

    await container.read(voiceSessionProvider.notifier).cancelRecording();
    stt.session.finishCompleter!.complete(
      const FinalTranscript(
        text: '不应进入草稿的迟到结果',
        audioDuration: Duration(seconds: 1),
        transcriptionDuration: Duration(seconds: 1),
      ),
    );
    await stopping;

    expect(stt.session.cancelled, 1);
    expect(container.read(clientSessionProvider).draftText, isEmpty);
    expect(
      container.read(voiceSessionProvider).phase,
      VoiceInputPhase.cancelled,
    );
  });

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

class _ConfiguredVoiceProviderSettingsController
    extends VoiceProviderSettingsController {
  @override
  VoiceProviderSettingsState build() => const VoiceProviderSettingsState(
    settings: VoiceProviderSettings(
      stt: SttProviderConfiguration(
        language: 'en',
        modelPath: '/models/fixture',
      ),
    ),
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
  bool closeAudioOnStop = false;

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
    if (closeAudioOnStop) await audioController.close();
  }
}

class _FakeSttPort implements SttPort {
  final session = _FakeSttSession();
  String? requestedLanguage;

  @override
  Future<void> close() async {}

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) async {
    requestedLanguage = language;
    return session;
  }

  @override
  Future<void> warmUp() async {}
}

class _FakeSttSession implements SttSessionPort {
  final updatesController = StreamController<TranscriptUpdate>.broadcast();
  final List<Uint8List> pushed = [];
  int finished = 0;
  int cancelled = 0;
  int pushStarted = 0;
  Object? finishFailure;
  Completer<FinalTranscript>? finishCompleter;
  Completer<void>? pushCompleter;

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
    if (finishCompleter case final completer?) return completer.future;
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
    pushStarted += 1;
    await pushCompleter?.future;
    pushed.add(audio);
  }
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition did not become true.');
}

class _FakeSpeechStop implements SpeechStopPort {
  int stops = 0;

  @override
  Future<void> stopSpeech() async {
    stops += 1;
  }
}

class _SpySpeechPlaybackController extends SpeechPlaybackController {
  _SpySpeechPlaybackController({
    required this.interruptStarted,
    required this.interruptGate,
  });

  final Completer<void> interruptStarted;
  final Completer<void> interruptGate;
  int interruptions = 0;

  @override
  SpeechPlaybackState build() => const SpeechPlaybackState();

  @override
  Future<void> interruptSpeech() async {
    interruptions += 1;
    if (!interruptStarted.isCompleted) interruptStarted.complete();
    await interruptGate.future;
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
