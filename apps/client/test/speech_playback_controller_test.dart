import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/application/speech_playback_controller.dart';
import 'package:agent_talk_client/domain/speech.dart';
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
      await controller.stopSpeech();
      expect(container.read(speechPlaybackProvider).phase, SpeechPhase.stopped);
      expect(
        container.read(speechPlaybackProvider).stopDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 300)),
      );
      expect(playback.stops, greaterThan(0));
    },
  );
}

class _FakeTts implements TtsPort {
  final List<SpeechSegment> segments = [];

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
  Completer<void>? _first;
  int stops = 0;

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

  @override
  Future<void> stopSpeech() async {
    stops += 1;
    release();
  }

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
