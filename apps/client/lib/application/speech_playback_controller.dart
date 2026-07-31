import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speech.dart';
import '../domain/voice.dart';
import 'voice_provider_settings_controller.dart';

final ttsPortProvider = Provider<TtsPort>((ref) {
  final configuration = ref.watch(
    voiceProviderSettingsProvider.select((value) => value.settings.tts),
  );
  final port = ref.watch(voicePortFactoryProvider).createTts(configuration);
  ref.onDispose(() => unawaited(port.close()));
  return port;
});

final audioPlaybackPortProvider = Provider<AudioPlaybackPort>(
  (_) => const _UnavailableAudioPlaybackPort(),
);

final speechEnabledProvider = Provider<bool>((ref) {
  final configuration = ref.watch(
    voiceProviderSettingsProvider.select((value) => value.settings.tts),
  );
  return ref.watch(voicePortFactoryProvider).isTtsEnabled(configuration);
});

final speechPlaybackProvider =
    NotifierProvider<SpeechPlaybackController, SpeechPlaybackState>(
      SpeechPlaybackController.new,
    );

class SpeechPlaybackController extends Notifier<SpeechPlaybackState>
    implements SpeechStopPort {
  int _generation = 0;
  StreamSubscription<double>? _levelSubscription;

  @override
  SpeechPlaybackState build() {
    final playback = ref.read(audioPlaybackPortProvider);
    final tts = ref.read(ttsPortProvider);
    ref.onDispose(() {
      _generation += 1;
      unawaited(_levelSubscription?.cancel());
      unawaited(_disposeResources(playback, tts));
    });
    return const SpeechPlaybackState();
  }

  Future<void> warmUp() async {
    if (!ref.read(speechEnabledProvider)) return;
    state = const SpeechPlaybackState(phase: SpeechPhase.warming);
    try {
      await ref.read(ttsPortProvider).warmUp();
      state = const SpeechPlaybackState(phase: SpeechPhase.idle);
    } on Object catch (error) {
      state = SpeechPlaybackState(
        phase: SpeechPhase.failed,
        failure: _safeSpeechFailure(error, VoiceFailureStage.tts),
      );
    }
  }

  /// Accepts only a durable final reply whose request terminal is completed.
  /// Callers retain the complete reply independently of this short speech.
  Future<void> speakCompletedReply({
    required String conversationId,
    required String requestId,
    required BigInt messageRevision,
    required String fullReply,
  }) async {
    if (!ref.read(speechEnabledProvider)) return;
    final summary = createDeterministicSpeechSummary(fullReply);
    final pieces = splitSpeechSegments(summary);
    if (pieces.isEmpty) return;
    final segments = [
      for (var index = 0; index < pieces.length; index += 1)
        SpeechSegment(
          conversationId: conversationId,
          requestId: requestId,
          messageRevision: messageRevision,
          index: index,
          text: pieces[index],
        ),
    ];
    final generation = ++_generation;
    try {
      await _cancelSpeechResources();
    } on Object catch (error) {
      state = SpeechPlaybackState(
        phase: SpeechPhase.failed,
        segment: segments.first,
        spokenText: summary,
        failure: _safeSpeechFailure(error, VoiceFailureStage.playback),
      );
      return;
    }
    if (generation != _generation) return;
    unawaited(_drain(generation, segments, summary));
  }

  Future<void> _drain(
    int generation,
    List<SpeechSegment> segments,
    String summary,
  ) async {
    final tts = ref.read(ttsPortProvider);
    final playback = ref.read(audioPlaybackPortProvider);
    try {
      state = SpeechPlaybackState(
        phase: SpeechPhase.synthesizing,
        segment: segments.first,
        spokenText: summary,
      );
      Future<SynthesizedSpeech> current = tts.synthesize(segments.first);
      for (var index = 0; index < segments.length; index += 1) {
        final audio = await current;
        if (generation != _generation) return;
        final Future<SynthesizedSpeech>? next = index + 1 < segments.length
            ? tts.synthesize(segments[index + 1])
            : null;
        if (next != null) {
          unawaited(next.then<void>((_) {}, onError: (_) {}));
        }
        state = SpeechPlaybackState(
          phase: SpeechPhase.playing,
          segment: audio.segment,
          spokenText: summary,
        );
        await _levelSubscription?.cancel();
        _levelSubscription = playback.levels.listen((level) {
          if (generation != _generation ||
              state.phase != SpeechPhase.playing ||
              state.segment?.identity != audio.segment.identity) {
            return;
          }
          state = SpeechPlaybackState(
            phase: SpeechPhase.playing,
            segment: audio.segment,
            spokenText: summary,
            playbackLevel: level.clamp(0, 1),
          );
        });
        await playback.play(audio);
        await _levelSubscription?.cancel();
        _levelSubscription = null;
        if (generation != _generation) return;
        if (next != null) current = next;
      }
      state = SpeechPlaybackState(phase: SpeechPhase.idle, spokenText: summary);
    } on Object catch (error) {
      if (generation != _generation) return;
      await _levelSubscription?.cancel();
      _levelSubscription = null;
      final fallback = state.phase == SpeechPhase.playing
          ? VoiceFailureStage.playback
          : VoiceFailureStage.tts;
      state = SpeechPlaybackState(
        phase: SpeechPhase.failed,
        segment: state.segment ?? segments.first,
        spokenText: summary,
        failure: _safeSpeechFailure(error, fallback),
      );
    }
  }

  @override
  Future<void> stopSpeech() async {
    _generation += 1;
    final stopwatch = Stopwatch()..start();
    VoiceStageFailure? failure;
    try {
      await _cancelSpeechResources().timeout(const Duration(milliseconds: 300));
    } on Object catch (error) {
      failure = _safeSpeechFailure(error, VoiceFailureStage.playback);
    }
    stopwatch.stop();
    state = SpeechPlaybackState(
      phase: SpeechPhase.stopped,
      failure: failure,
      stopDuration: stopwatch.elapsed,
    );
  }

  Future<void> _cancelSpeechResources() async {
    await _levelSubscription?.cancel();
    _levelSubscription = null;
    await Future.wait([
      ref.read(ttsPortProvider).cancel(),
      ref.read(audioPlaybackPortProvider).stopSpeech(),
    ]);
  }
}

Future<void> _disposeResources(AudioPlaybackPort playback, TtsPort tts) async {
  await playback.stopSpeech().catchError((_) {});
  await tts.cancel().catchError((_) {});
  await playback.close().catchError((_) {});
  await tts.close().catchError((_) {});
}

String createDeterministicSpeechSummary(
  String fullReply, {
  int maxCharacters = 120,
}) {
  var cleaned = fullReply
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'^\s*\|.*\|\s*$', multiLine: true), ' ')
      .replaceAll(
        RegExp(
          r'\b(?:sk-[A-Za-z0-9_-]{12,}|Bearer\s+[A-Za-z0-9._~-]{12,}|(?:api[_-]?key|token|secret)\s*[:=]\s*\S+)',
          caseSensitive: false,
        ),
        '[敏感信息已隐藏]',
      )
      .replaceAll(RegExp(r'(?:[A-Za-z]:\\|/)[^\s，。！？]{28,}'), '[路径已省略]')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'[*_`>~-]'), '')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return '任务已结束，请查看文字结果。';
  final sentences = RegExp(
    r'[^。！？.!?]+[。！？.!?]?',
  ).allMatches(cleaned).map((match) => match.group(0)!).toList();
  cleaned = (sentences.isEmpty ? [cleaned] : sentences)
      .skip(sentences.length > 3 ? sentences.length - 3 : 0)
      .join()
      .trim();
  if (cleaned.length <= maxCharacters) return cleaned;
  return '${cleaned.substring(0, maxCharacters - 1).trimRight()}…';
}

List<String> splitSpeechSegments(String summary, {int maxCharacters = 48}) {
  final result = <String>[];
  for (final match in RegExp(r'[^。！？.!?]+[。！？.!?]?').allMatches(summary)) {
    var sentence = match.group(0)!.trim();
    while (sentence.length > maxCharacters) {
      result.add(sentence.substring(0, maxCharacters));
      sentence = sentence.substring(maxCharacters).trim();
    }
    if (sentence.isNotEmpty) result.add(sentence);
    if (result.length >= 3) break;
  }
  return List.unmodifiable(result.take(3));
}

VoiceStageFailure _safeSpeechFailure(
  Object error,
  VoiceFailureStage fallback,
) => switch (error) {
  VoicePortException() => error.failure,
  _ => VoiceStageFailure(
    stage: fallback,
    code: fallback == VoiceFailureStage.playback
        ? 'speech_playback_failed'
        : 'tts_synthesis_failed',
    safeMessage: fallback == VoiceFailureStage.playback
        ? 'Speech playback failed. The complete reply is still available.'
        : 'Speech synthesis failed. The complete reply is still available.',
    retryable: true,
  ),
};

class _UnavailableAudioPlaybackPort implements AudioPlaybackPort {
  const _UnavailableAudioPlaybackPort();

  @override
  Stream<double> get levels => const Stream.empty();

  @override
  Future<void> play(SynthesizedSpeech speech) async {}

  @override
  Future<void> stopSpeech() async {}

  @override
  Future<void> close() async {}
}
