import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sentence_segmenter.dart';
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
  final SentenceSegmenter _streamingSegmenter = SentenceSegmenter();
  final List<_StreamingSpeechJob> _streamingQueue = [];
  Future<void>? _streamingDrainFuture;
  Future<void>? _streamingReady;
  int? _streamingGeneration;
  int _streamingSegmentIndex = 0;
  bool _streamingTurnActive = false;
  bool _streamingFinishing = false;
  String _streamingConversationId = 'streaming';
  String _streamingRequestId = 'streaming';
  BigInt _streamingMessageRevision = BigInt.zero;
  String _streamingText = '';
  VoiceStageFailure? _streamingFailure;

  @override
  SpeechPlaybackState build() {
    final playback = ref.read(audioPlaybackPortProvider);
    final tts = ref.read(ttsPortProvider);
    ref.onDispose(() {
      _generation += 1;
      _clearStreamingTurn();
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

  /// Starts a new Call Mode speech turn without taking ownership of chat
  /// transport or the complete assistant reply.
  ///
  /// Identity arguments are optional for callers that already have them. The
  /// no-argument form remains useful for the coordinator's initial wiring and
  /// still binds every segment to this controller generation.
  Future<void> beginStreamingTurn({
    String? conversationId,
    String? requestId,
    BigInt? messageRevision,
  }) async {
    if (!ref.read(speechEnabledProvider)) return;

    final generation = ++_generation;
    _clearStreamingTurn();
    _streamingGeneration = generation;
    _streamingSegmentIndex = 0;
    _streamingTurnActive = true;
    _streamingConversationId = conversationId ?? 'streaming';
    _streamingRequestId = requestId ?? 'streaming-$generation';
    _streamingMessageRevision = messageRevision ?? BigInt.from(generation);
    _streamingText = '';
    _streamingFailure = null;
    state = SpeechPlaybackState(
      phase: SpeechPhase.speakingStreaming,
      generation: generation,
    );

    final reset = _cancelSpeechResources().timeout(
      const Duration(milliseconds: 300),
    );
    _streamingReady = reset.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _recordStreamingFailure(error, VoiceFailureStage.playback);
      },
    );
    await _streamingReady;
    if (generation != _generation || !_streamingTurnActive) return;
    _publishStreamingState();
  }

  /// Feeds only assistant text deltas. Tool progress and reasoning events
  /// must be filtered by the caller before reaching this method.
  void feedStreamingDelta(String delta) {
    if (!ref.read(speechEnabledProvider) ||
        !_streamingTurnActive ||
        delta.isEmpty) {
      return;
    }
    final generation = _streamingGeneration;
    if (generation == null || generation != _generation) return;

    _streamingText += delta;
    final stableSentences = _streamingSegmenter.feed(delta);
    for (final sentence in stableSentences) {
      _enqueueStreamingSentence(sentence, generation);
    }
    _publishStreamingState();
    _ensureStreamingDrain();
  }

  /// Flushes the last incomplete sentence and waits for this turn's queue.
  Future<void> finishStreamingTurn() async {
    if (!ref.read(speechEnabledProvider)) return;
    final generation = _streamingGeneration;
    if (generation == null) return;

    if (_streamingTurnActive) {
      _streamingFinishing = true;
      for (final sentence in _streamingSegmenter.flush()) {
        _enqueueStreamingSentence(sentence, generation, allowFinishing: true);
      }
      _streamingTurnActive = false;
      _publishStreamingState();
      _ensureStreamingDrain();
    }

    final drain = _streamingDrainFuture;
    if (drain != null) await drain;
    if (generation != _generation) return;

    // A drain can finish between the first read and the await above. Ensure
    // that a queued current-generation item is never left behind.
    if (_streamingQueue.isNotEmpty) {
      _ensureStreamingDrain();
      final retry = _streamingDrainFuture;
      if (retry != null) await retry;
    }
    if (generation != _generation || _streamingQueue.isNotEmpty) return;

    _streamingFinishing = false;
    state = SpeechPlaybackState(
      phase: SpeechPhase.idle,
      segment: state.segment,
      spokenText: _streamingText.isEmpty ? null : _streamingText,
      generation: generation,
      failure: _streamingFailure,
    );
  }

  /// Barge-in entry point. Recording starts invoke it without waiting for TTS
  /// cleanup; unavailable TTS and playback ports remain no-ops.
  Future<void> interruptSpeech() async {
    // 无 TTS 时打断为空操作；不可用端口由 stopSpeech 安全收敛。
    await stopSpeech();
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
    _clearStreamingTurn();
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

  void _enqueueStreamingSentence(
    String text,
    int generation, {
    bool allowFinishing = false,
  }) {
    if (generation != _generation ||
        (!_streamingTurnActive && (!allowFinishing || !_streamingFinishing))) {
      return;
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _streamingQueue.add(
      _StreamingSpeechJob(
        generation: generation,
        segment: SpeechSegment(
          conversationId: _streamingConversationId,
          requestId: _streamingRequestId,
          messageRevision: _streamingMessageRevision,
          index: _streamingSegmentIndex++,
          text: trimmed,
        ),
      ),
    );
  }

  void _ensureStreamingDrain() {
    final generation = _streamingGeneration;
    if (_streamingDrainFuture != null || generation == null) return;
    final ready = _streamingReady ?? Future<void>.value();
    final future = _drainStreaming(generation, ready);
    _streamingDrainFuture = future;
    unawaited(
      future.then<void>(
        (_) => _onStreamingDrainComplete(future),
        onError: (Object error, StackTrace stackTrace) {
          if (generation == _generation) {
            _recordStreamingFailure(error, VoiceFailureStage.tts);
          }
          _onStreamingDrainComplete(future);
        },
      ),
    );
  }

  void _onStreamingDrainComplete(Future<void> future) {
    if (identical(_streamingDrainFuture, future)) {
      _streamingDrainFuture = null;
    }
    if (_streamingGeneration == _generation && _streamingQueue.isNotEmpty) {
      _ensureStreamingDrain();
    }
  }

  Future<void> _drainStreaming(int generation, Future<void> ready) async {
    try {
      await ready;
      if (generation != _generation) return;
      while (_streamingQueue.isNotEmpty) {
        if (generation != _generation) return;
        final job = _streamingQueue.removeAt(0);
        if (job.generation != generation ||
            (!_streamingTurnActive && !_streamingFinishing)) {
          continue;
        }

        final tts = ref.read(ttsPortProvider);
        final playback = ref.read(audioPlaybackPortProvider);
        var phase = SpeechPhase.speakingStreaming;
        _publishStreamingState(phase: phase, segment: job.segment);
        try {
          final audio = await tts.synthesize(job.segment);
          if (generation != _generation) return;

          phase = SpeechPhase.playing;
          _publishStreamingState(phase: phase, segment: audio.segment);
          await _levelSubscription?.cancel();
          _levelSubscription = playback.levels.listen((level) {
            if (generation != _generation ||
                state.phase != SpeechPhase.playing ||
                state.segment?.identity != audio.segment.identity) {
              return;
            }
            _publishStreamingState(
              phase: SpeechPhase.playing,
              segment: audio.segment,
              playbackLevel: level.clamp(0, 1),
            );
          });
          await playback.play(audio);
          if (generation != _generation) return;
        } on Object catch (error) {
          if (generation != _generation) return;
          _recordStreamingFailure(
            error,
            phase == SpeechPhase.playing
                ? VoiceFailureStage.playback
                : VoiceFailureStage.tts,
          );
          // The failed sentence is deliberately discarded. The remaining
          // queue belongs to the same text stream and must continue.
        } finally {
          await _levelSubscription?.cancel();
          _levelSubscription = null;
        }
      }

      if (generation != _generation) return;
      if (_streamingFinishing) {
        _streamingFinishing = false;
        state = SpeechPlaybackState(
          phase: SpeechPhase.idle,
          segment: state.segment,
          spokenText: _streamingText.isEmpty ? null : _streamingText,
          generation: generation,
          failure: _streamingFailure,
        );
      } else if (_streamingTurnActive) {
        _publishStreamingState();
      }
    } on Object catch (error) {
      if (generation == _generation) {
        _recordStreamingFailure(error, VoiceFailureStage.tts);
      }
    }
  }

  void _publishStreamingState({
    SpeechPhase phase = SpeechPhase.speakingStreaming,
    SpeechSegment? segment,
    double playbackLevel = 0,
  }) {
    final generation = _streamingGeneration;
    if (generation == null || generation != _generation) return;
    state = SpeechPlaybackState(
      phase: phase,
      segment: segment ?? state.segment,
      spokenText: _streamingText.isEmpty ? null : _streamingText,
      pendingSentence: _streamingSegmenter.pending,
      generation: generation,
      playbackLevel: playbackLevel,
      failure: _streamingFailure,
    );
  }

  void _recordStreamingFailure(Object error, VoiceFailureStage fallback) {
    _streamingFailure = _safeSpeechFailure(error, fallback);
    if (_streamingGeneration == _generation &&
        (_streamingTurnActive || _streamingFinishing)) {
      _publishStreamingState();
    }
  }

  void _clearStreamingTurn() {
    _streamingSegmenter.flush();
    _streamingQueue.clear();
    _streamingReady = null;
    _streamingGeneration = null;
    _streamingSegmentIndex = 0;
    _streamingTurnActive = false;
    _streamingFinishing = false;
    _streamingConversationId = 'streaming';
    _streamingRequestId = 'streaming';
    _streamingMessageRevision = BigInt.zero;
    _streamingText = '';
    _streamingFailure = null;
  }

  @override
  Future<void> stopSpeech() async {
    _generation += 1;
    _clearStreamingTurn();
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

class _StreamingSpeechJob {
  const _StreamingSpeechJob({required this.generation, required this.segment});

  final int generation;
  final SpeechSegment segment;
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
