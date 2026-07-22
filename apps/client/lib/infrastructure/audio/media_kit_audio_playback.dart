import 'dart:async';

import 'package:media_kit/media_kit.dart';

import '../../domain/speech.dart';
import '../../domain/voice.dart';

class MediaKitAudioPlayback implements AudioPlaybackPort {
  MediaKitAudioPlayback({Player? player}) : _player = player ?? Player();

  final Player _player;
  int _generation = 0;
  bool _closed = false;

  @override
  Future<void> play(SynthesizedSpeech speech) async {
    if (_closed) throw StateError('The audio player is closed.');
    final generation = ++_generation;
    try {
      final media = await Media.memory(speech.bytes, type: speech.mimeType);
      if (generation != _generation) return;
      final completed = _player.stream.completed.firstWhere((value) => value);
      await _player.open(media);
      await completed.timeout(const Duration(minutes: 2));
    } on Object {
      if (generation != _generation) return;
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.playback,
          code: 'media_kit_playback_failed',
          safeMessage:
              'Speech playback failed. The complete reply is still available.',
          retryable: true,
        ),
      );
    }
  }

  @override
  Future<void> stopSpeech() async {
    _generation += 1;
    try {
      await _player.stop();
    } on Object {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.playback,
          code: 'media_kit_stop_failed',
          safeMessage: 'Speech playback could not stop cleanly.',
          retryable: true,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _generation += 1;
    await _player.dispose();
  }
}
