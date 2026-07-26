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
}

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

class _BlockingTts implements TtsPort {
  Completer<SynthesizedSpeech>? active;
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
    active = Completer<SynthesizedSpeech>();
    return active!.future;
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
