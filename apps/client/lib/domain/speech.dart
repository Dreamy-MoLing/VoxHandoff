import 'dart:typed_data';

import 'voice.dart';

enum SpeechPhase { idle, warming, synthesizing, playing, stopped, failed }

class SpeechSegment {
  const SpeechSegment({
    required this.conversationId,
    required this.requestId,
    required this.messageRevision,
    required this.index,
    required this.text,
  });

  final String conversationId;
  final String requestId;
  final BigInt messageRevision;
  final int index;
  final String text;

  String get identity => '$conversationId:$requestId:$messageRevision:$index';
}

class SynthesizedSpeech {
  const SynthesizedSpeech({
    required this.segment,
    required this.bytes,
    required this.mimeType,
    required this.synthesisDuration,
  });

  final SpeechSegment segment;
  final Uint8List bytes;
  final String mimeType;
  final Duration synthesisDuration;
}

class SpeechPlaybackState {
  const SpeechPlaybackState({
    this.phase = SpeechPhase.idle,
    this.segment,
    this.spokenText,
    this.failure,
    this.stopDuration,
  });

  final SpeechPhase phase;
  final SpeechSegment? segment;
  final String? spokenText;
  final VoiceStageFailure? failure;
  final Duration? stopDuration;
}

abstract interface class TtsPort {
  Future<void> warmUp();
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment);
  Future<void> cancel();
  Future<void> close();
}

abstract interface class AudioPlaybackPort implements SpeechStopPort {
  Future<void> play(SynthesizedSpeech speech);
  Future<void> close();
}
