import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/application/speech_playback_controller.dart';
import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('summary removes code, secret-shaped text, paths, and stays short', () {
    final summary = createDeterministicSpeechSummary(
      '开始。```dart\nfinal token = "hidden";\n```'
      'Bearer abcdefghijklmnop。'
      '/this/is/a/very/long/private/workspace/path/file.dart。全部测试通过。',
      maxCharacters: 44,
    );
    expect(summary.length, lessThanOrEqualTo(44));
    expect(summary, isNot(contains('final token')));
    expect(summary, isNot(contains('abcdefghijklmnop')));
    expect(summary, isNot(contains('/this/is')));
  });

  test(
    'completed reply prefetches N+1 and keeps stable segment identity',
    () async {
      final tts = _FakeTts();
      final playback = _BlockingPlayback();
      final container = ProviderContainer(
        overrides: [
          ttsPortProvider.overrideWithValue(tts),
          audioPlaybackPortProvider.overrideWithValue(playback),
          speechEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(speechPlaybackProvider.notifier)
          .speakCompletedReply(
            conversationId: 'conversation-1',
            requestId: 'request-1',
            messageRevision: BigInt.from(7),
            fullReply: '第一段已经完成。第二段测试也通过。第三段请查看文字。',
          );
      await _eventually(() => playback.played.isNotEmpty);
      expect(
        tts.segments.length,
        2,
        reason: 'N+1 is synthesized while N plays',
      );
      expect(tts.segments.first.identity, 'conversation-1:request-1:7:0');
      playback.release();
      await _eventually(
        () => container.read(speechPlaybackProvider).phase == SpeechPhase.idle,
      );
      expect(playback.played.map((item) => item.segment.index), [0, 1, 2]);
    },
  );

  test(
    'stop invalidates stale audio without touching any Agent state',
    () async {
      final tts = _FakeTts();
      final playback = _BlockingPlayback();
      final container = ProviderContainer(
        overrides: [
          ttsPortProvider.overrideWithValue(tts),
          audioPlaybackPortProvider.overrideWithValue(playback),
          speechEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(speechPlaybackProvider.notifier);
      await controller.speakCompletedReply(
        conversationId: 'conversation-1',
        requestId: 'request-2',
        messageRevision: BigInt.one,
        fullReply: '第一段。第二段。',
      );
      await _eventually(() => playback.played.isNotEmpty);
      playback.emitLevel(0.64);
      await _eventually(
        () => container.read(speechPlaybackProvider).playbackLevel == 0.64,
      );
      await controller.stopSpeech();
      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.stopped);
      expect(container.read(speechPlaybackProvider).playbackLevel, 0);
      expect(
        container.read(speechPlaybackProvider).stopDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      expect(playback.stops, greaterThan(0));
    },
  );

  test('stop cancels an in-flight synthesis before it can play', () async {
    final tts = _BlockingTts();
    final playback = _BlockingPlayback();
    final container = ProviderContainer(
      overrides: [
        ttsPortProvider.overrideWithValue(tts),
        audioPlaybackPortProvider.overrideWithValue(playback),
        speechEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(speechPlaybackProvider.notifier);

    await controller.speakCompletedReply(
      conversationId: 'conversation-1',
      requestId: 'request-cancel-synthesis',
      messageRevision: BigInt.two,
      fullReply: '第一段仍在合成。',
    );
    await _eventually(() => tts.active != null);
    await controller.stopSpeech();
    await Future<void>.delayed(Duration.zero);

    expect(tts.cancellations, 2, reason: 'initial reset plus explicit stop');
    expect(playback.played, isEmpty);
    expect(container.read(speechPlaybackProvider).phase, SpeechPhase.stopped);
  });

  test(
    'optional speech reset failure never escapes into reply handling',
    () async {
      final tts = _FakeTts();
      final container = ProviderContainer(
        overrides: [
          ttsPortProvider.overrideWithValue(tts),
          audioPlaybackPortProvider.overrideWithValue(_FailingStopPlayback()),
          speechEnabledProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(speechPlaybackProvider.notifier)
          .speakCompletedReply(
            conversationId: 'conversation-1',
            requestId: 'request-reset-failure',
            messageRevision: BigInt.from(3),
            fullReply: '完整回复必须保持可见。',
          );

      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.failed);
      expect(tts.segments, isEmpty);
    },
  );

  test(
    'streaming queue speaks stable sentences in order and flushes the tail',
    () async {
      final tts = _FakeTts();
      final playback = _ImmediatePlayback();
      final container = _speechContainer(tts, playback);
      addTearDown(container.dispose);
      final controller = container.read(speechPlaybackProvider.notifier);

      await controller.beginStreamingTurn(
        conversationId: 'conversation-stream',
        requestId: 'request-stream',
        messageRevision: BigInt.from(11),
      );
      controller.feedStreamingDelta('第一句。第二');
      controller.feedStreamingDelta('句尚未结束');
      expect(container.read(speechPlaybackProvider).pendingSentence, '第二句尚未结束');
      await controller.finishStreamingTurn();

      expect(tts.segments.map((segment) => segment.text), ['第一句。', '第二句尚未结束']);
      expect(playback.played.map((speech) => speech.segment.text), [
        '第一句。',
        '第二句尚未结束',
      ]);
      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.idle);
      expect(container.read(speechPlaybackProvider).spokenText, '第一句。第二句尚未结束');
    },
  );

  test(
    'streaming TTS failure skips one sentence and keeps the queue alive',
    () async {
      final tts = _FailingStreamingTts();
      final playback = _ImmediatePlayback();
      final container = _speechContainer(tts, playback);
      addTearDown(container.dispose);
      final controller = container.read(speechPlaybackProvider.notifier);

      await controller.beginStreamingTurn();
      controller.feedStreamingDelta('失败句。成功句。');
      await controller.finishStreamingTurn();

      expect(tts.segments.map((segment) => segment.text), ['失败句。', '成功句。']);
      expect(playback.played.map((speech) => speech.segment.text), ['成功句。']);
      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.idle);
      expect(
        container.read(speechPlaybackProvider).failure?.code,
        'fixture_streaming_tts_failed',
      );
      expect(container.read(speechPlaybackProvider).spokenText, '失败句。成功句。');
    },
  );

  test(
    'interruptSpeech stops playback and clears queued streaming sentences',
    () async {
      final tts = _FakeTts();
      final playback = _BlockingPlayback();
      final container = _speechContainer(tts, playback);
      addTearDown(container.dispose);
      final controller = container.read(speechPlaybackProvider.notifier);

      await controller.beginStreamingTurn();
      controller.feedStreamingDelta('正在播放。排队句子。');
      await _eventually(() => playback.played.isNotEmpty);

      await controller.interruptSpeech();

      expect(playback.played.map((speech) => speech.segment.text), ['正在播放。']);
      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.stopped);
      expect(
        container.read(speechPlaybackProvider).stopDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      expect(playback.stops, greaterThan(0));
    },
  );

  test(
    'disabled TTS keeps streaming methods as subtitle-only no-ops',
    () async {
      final tts = _FakeTts();
      final playback = _ImmediatePlayback();
      final container = ProviderContainer(
        overrides: [
          ttsPortProvider.overrideWithValue(tts),
          audioPlaybackPortProvider.overrideWithValue(playback),
          speechEnabledProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(speechPlaybackProvider.notifier);

      await controller.beginStreamingTurn();
      controller.feedStreamingDelta('字幕继续显示。');
      await controller.finishStreamingTurn();

      expect(tts.segments, isEmpty);
      expect(playback.played, isEmpty);
      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.idle);
    },
  );

  test(
    'a new streaming turn invalidates stale synthesis before playback',
    () async {
      final tts = _BlockingTts();
      final playback = _ImmediatePlayback();
      final container = _speechContainer(tts, playback);
      addTearDown(container.dispose);
      final controller = container.read(speechPlaybackProvider.notifier);

      await controller.beginStreamingTurn(requestId: 'old-turn');
      controller.feedStreamingDelta('旧句不应播放。');
      await _eventually(() => tts.active != null);

      await controller.beginStreamingTurn(requestId: 'new-turn');
      final newSynthesis = tts.syntheses + 1;
      controller.feedStreamingDelta('新句可以播放。');
      await _eventually(() => tts.syntheses >= newSynthesis);
      tts.release();
      await controller.finishStreamingTurn();

      expect(playback.played.map((speech) => speech.segment.text), ['新句可以播放。']);
      expect(playback.played.single.segment.requestId, 'new-turn');
    },
  );
}

ProviderContainer _speechContainer(TtsPort tts, AudioPlaybackPort playback) =>
    ProviderContainer(
      overrides: [
        ttsPortProvider.overrideWithValue(tts),
        audioPlaybackPortProvider.overrideWithValue(playback),
        speechEnabledProvider.overrideWithValue(true),
      ],
    );

class _FakeTts implements TtsPort {
  final List<SpeechSegment> segments = [];
  int cancellations = 0;

  @override
  Future<void> cancel() async {
    cancellations += 1;
  }

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) async {
    segments.add(segment);
    return SynthesizedSpeech(
      segment: segment,
      bytes: Uint8List.fromList([82, 73, 70, 70]),
      mimeType: 'audio/wav',
      synthesisDuration: const Duration(milliseconds: 10),
    );
  }

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> close() async {}
}

class _BlockingPlayback implements AudioPlaybackPort {
  final List<SynthesizedSpeech> played = [];
  final StreamController<double> _levels = StreamController<double>.broadcast();
  Completer<void>? _first;
  int stops = 0;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> play(SynthesizedSpeech speech) async {
    played.add(speech);
    if (played.length == 1) {
      _first = Completer<void>();
      await _first!.future;
    }
  }

  void release() {
    if (!(_first?.isCompleted ?? true)) _first!.complete();
  }

  void emitLevel(double level) {
    _levels.add(level);
  }

  @override
  Future<void> stopSpeech() async {
    stops += 1;
    release();
  }

  @override
  Future<void> close() async {}
}

class _ImmediatePlayback implements AudioPlaybackPort {
  final List<SynthesizedSpeech> played = [];

  @override
  Stream<double> get levels => const Stream.empty();

  @override
  Future<void> play(SynthesizedSpeech speech) async {
    played.add(speech);
  }

  @override
  Future<void> stopSpeech() async {}

  @override
  Future<void> close() async {}
}

class _FailingStreamingTts extends _FakeTts {
  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) async {
    segments.add(segment);
    if (segments.length == 1) {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.tts,
          code: 'fixture_streaming_tts_failed',
          safeMessage: 'Synthetic streaming TTS failure.',
          retryable: true,
        ),
      );
    }
    return SynthesizedSpeech(
      segment: segment,
      bytes: Uint8List.fromList([82, 73, 70, 70]),
      mimeType: 'audio/wav',
      synthesisDuration: const Duration(milliseconds: 10),
    );
  }
}

class _BlockingTts implements TtsPort {
  Completer<SynthesizedSpeech>? active;
  SpeechSegment? activeSegment;
  int syntheses = 0;
  int cancellations = 0;

  @override
  Future<void> cancel() async {
    cancellations += 1;
    final request = active;
    if (request != null && !request.isCompleted) {
      request.completeError(
        const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.tts,
            code: 'tts_cancelled',
            safeMessage: 'Speech synthesis was cancelled.',
            retryable: true,
          ),
        ),
      );
    }
  }

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) {
    syntheses += 1;
    activeSegment = segment;
    active = Completer<SynthesizedSpeech>();
    return active!.future;
  }

  void release() {
    final request = active;
    final segment = activeSegment;
    if (request == null || request.isCompleted || segment == null) return;
    request.complete(
      SynthesizedSpeech(
        segment: segment,
        bytes: Uint8List.fromList([82, 73, 70, 70]),
        mimeType: 'audio/wav',
        synthesisDuration: const Duration(milliseconds: 10),
      ),
    );
  }

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> close() async {}
}

class _FailingStopPlayback implements AudioPlaybackPort {
  @override
  Stream<double> get levels => const Stream.empty();

  @override
  Future<void> play(SynthesizedSpeech speech) async {}

  @override
  Future<void> stopSpeech() => Future<void>.error(StateError('fixture stop'));

  @override
  Future<void> close() async {}
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition did not become true.');
}
