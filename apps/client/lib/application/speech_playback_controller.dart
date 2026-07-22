import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/speech.dart';
import '../domain/voice.dart';

final ttsPortProvider = Provider<TtsPort>((_) => const _UnavailableTtsPort());

final audioPlaybackPortProvider = Provider<AudioPlaybackPort>(
  (_) => const _UnavailableAudioPlaybackPort(),
);

final speechEnabledProvider = Provider<bool>((_) => false);

final speechPlaybackProvider =
    NotifierProvider<SpeechPlaybackController, SpeechPlaybackState>(
      SpeechPlaybackController.new,
    );

class SpeechPlaybackController extends Notifier<SpeechPlaybackState>
    implements SpeechStopPort {
  int _generation = 0;

  @override
  SpeechPlaybackState build() {
    final playback = ref.read(audioPlaybackPortProvider);
    ref.onDispose(() {
      _generation += 1;
      unawaited(playback.stopSpeech());
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
    final generation = ++_generation;
    await _stopPlaybackOnly();
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
        state = SpeechPlaybackState(
          phase: SpeechPhase.playing,
          segment: audio.segment,
          spokenText: summary,
        );
        await playback.play(audio);
        if (generation != _generation) return;
        if (next != null) current = next;
      }
      state = SpeechPlaybackState(phase: SpeechPhase.idle, spokenText: summary);
    } on Object catch (error) {
      if (generation != _generation) return;
      final fallback = state.phase == SpeechPhase.playing
          ? VoiceFailureStage.playback
          : VoiceFailureStage.tts;
      state = SpeechPlaybackState(
        phase: SpeechPhase.failed,
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
      await _stopPlaybackOnly().timeout(const Duration(milliseconds: 300));
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

  Future<void> _stopPlaybackOnly() =>
      ref.read(audioPlaybackPortProvider).stopSpeech();
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

class _UnavailableTtsPort implements TtsPort {
  const _UnavailableTtsPort();

  @override
  Future<void> warmUp() async {}

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) =>
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.configuration,
          code: 'tts_not_configured',
          safeMessage: 'Speech synthesis is not configured.',
          retryable: false,
        ),
      );

  @override
  Future<void> close() async {}
}

class _UnavailableAudioPlaybackPort implements AudioPlaybackPort {
  const _UnavailableAudioPlaybackPort();

  @override
  Future<void> play(SynthesizedSpeech speech) async {}

  @override
  Future<void> stopSpeech() async {}

  @override
  Future<void> close() async {}
}
