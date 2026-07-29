import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../../domain/speech.dart';
import '../../domain/voice.dart';

@visibleForTesting
const maxAnalyzedPcmBytes = 4 * 1024 * 1024;

@visibleForTesting
const maxAnalyzedPcmDuration = Duration(minutes: 2);

class MediaKitAudioPlayback implements AudioPlaybackPort {
  MediaKitAudioPlayback({Player? player, Duration? completionTimeout})
    : _driver = _MediaKitPlayerDriver(player ?? Player()),
      _completionTimeout = completionTimeout ?? const Duration(minutes: 2);

  @visibleForTesting
  MediaKitAudioPlayback.withDriver(this._driver, {Duration? completionTimeout})
    : _completionTimeout = completionTimeout ?? const Duration(minutes: 2);

  final MediaKitPlayerDriver _driver;
  final Duration _completionTimeout;
  final StreamController<double> _levels = StreamController<double>.broadcast();
  int _generation = 0;
  bool _closed = false;
  Timer? _levelTimer;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<void> play(SynthesizedSpeech speech) async {
    if (_closed) throw StateError('The audio player is closed.');
    final generation = ++_generation;
    final completed = Completer<void>();
    Object? completionError;
    StackTrace? completionStackTrace;
    late final StreamSubscription<bool> completionSubscription;
    completionSubscription = _driver.completed.listen(
      (value) {
        if (value && !completed.isCompleted) completed.complete();
      },
      onError: (Object error, StackTrace stackTrace) {
        completionError = error;
        completionStackTrace = stackTrace;
        if (!completed.isCompleted) completed.complete();
      },
      onDone: () {
        if (!completed.isCompleted) {
          completionError = StateError(
            'The media completion stream ended early.',
          );
          completionStackTrace = StackTrace.current;
          completed.complete();
        }
      },
    );
    try {
      await _driver.open(speech.bytes, speech.mimeType);
      if (generation != _generation) {
        await _stopDriverQuietly();
        return;
      }
      unawaited(_startEnvelope(speech.bytes, generation));
      await completed.future.timeout(_completionTimeout);
      final streamError = completionError;
      if (streamError != null) {
        Error.throwWithStackTrace(
          streamError,
          completionStackTrace ?? StackTrace.current,
        );
      }
      if (generation == _generation) _stopEnvelope();
    } on Object {
      if (generation != _generation) {
        await _stopDriverQuietly();
        return;
      }
      _stopEnvelope();
      await _stopDriverQuietly();
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.playback,
          code: 'media_kit_playback_failed',
          safeMessage:
              'Speech playback failed. The complete reply is still available.',
          retryable: true,
        ),
      );
    } finally {
      await completionSubscription.cancel();
    }
  }

  @override
  Future<void> stopSpeech() async {
    _generation += 1;
    _stopEnvelope();
    try {
      await _driver.stop();
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
    _stopEnvelope();
    try {
      await _driver.dispose();
    } finally {
      await _levels.close();
    }
  }

  Future<void> _startEnvelope(Uint8List bytes, int generation) async {
    _stopEnvelope();
    final envelope = await extractPcm16WavEnvelopeOffMainIsolate(bytes);
    if (_closed || generation != _generation || envelope.isEmpty) return;
    var index = 0;
    _levels.add(envelope[index]);
    _levelTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_closed || generation != _generation) {
        _stopEnvelope();
        return;
      }
      index += 1;
      if (index >= envelope.length) {
        _stopEnvelope();
        return;
      }
      _levels.add(envelope[index]);
    });
  }

  void _stopEnvelope() {
    _levelTimer?.cancel();
    _levelTimer = null;
    if (!_levels.isClosed) _levels.add(0);
  }

  Future<void> _stopDriverQuietly() async {
    try {
      await _driver.stop().timeout(const Duration(milliseconds: 300));
    } on Object {
      // Preserve the original bounded playback result.
    }
  }
}

@visibleForTesting
abstract interface class MediaKitPlayerDriver {
  Stream<bool> get completed;
  Future<void> open(Uint8List bytes, String mimeType);
  Future<void> stop();
  Future<void> dispose();
}

class _MediaKitPlayerDriver implements MediaKitPlayerDriver {
  _MediaKitPlayerDriver(this._player);

  final Player _player;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Future<void> open(Uint8List bytes, String mimeType) async {
    final media = await Media.memory(bytes, type: mimeType);
    await _player.open(media);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

@visibleForTesting
Future<List<double>> extractPcm16WavEnvelopeOffMainIsolate(
  Uint8List bytes, {
  Duration bucket = const Duration(milliseconds: 50),
}) async {
  if (bytes.length > maxAnalyzedPcmBytes) return const [];
  final transferable = TransferableTypedData.fromList([bytes]);
  return Isolate.run(() {
    final isolatedBytes = transferable.materialize().asUint8List();
    return extractPcm16WavEnvelope(isolatedBytes, bucket: bucket);
  });
}

@visibleForTesting
List<double> extractPcm16WavEnvelope(
  Uint8List bytes, {
  Duration bucket = const Duration(milliseconds: 50),
}) {
  if (bytes.length > maxAnalyzedPcmBytes) return const [];
  if (bytes.length < 44 ||
      _ascii(bytes, 0, 4) != 'RIFF' ||
      _ascii(bytes, 8, 4) != 'WAVE') {
    return const [];
  }
  final data = ByteData.sublistView(bytes);
  int? channels;
  int? sampleRate;
  int? bitsPerSample;
  int? audioFormat;
  int? pcmOffset;
  int? pcmLength;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _ascii(bytes, offset, 4);
    final length = data.getUint32(offset + 4, Endian.little);
    final payloadOffset = offset + 8;
    if (length > bytes.length - payloadOffset) return const [];
    if (id == 'fmt ' && length >= 16) {
      audioFormat = data.getUint16(payloadOffset, Endian.little);
      channels = data.getUint16(payloadOffset + 2, Endian.little);
      sampleRate = data.getUint32(payloadOffset + 4, Endian.little);
      bitsPerSample = data.getUint16(payloadOffset + 14, Endian.little);
    } else if (id == 'data') {
      pcmOffset = payloadOffset;
      pcmLength = length;
    }
    offset = payloadOffset + length + (length.isOdd ? 1 : 0);
  }
  if (audioFormat != 1 ||
      channels == null ||
      channels <= 0 ||
      sampleRate == null ||
      sampleRate <= 0 ||
      bitsPerSample != 16 ||
      pcmOffset == null ||
      pcmLength == null) {
    return const [];
  }

  final bytesPerFrame = channels * 2;
  final frameCount = pcmLength ~/ bytesPerFrame;
  if (frameCount == 0) return const [];
  final maxAnalyzedFrames =
      (sampleRate * maxAnalyzedPcmDuration.inMicroseconds) ~/
      Duration.microsecondsPerSecond;
  if (frameCount > maxAnalyzedFrames) return const [];
  final framesPerBucket = math.max(
    1,
    (sampleRate * bucket.inMicroseconds) ~/ Duration.microsecondsPerSecond,
  );
  final envelope = <double>[];
  for (var firstFrame = 0; firstFrame < frameCount;) {
    final lastFrame = math.min(frameCount, firstFrame + framesPerBucket);
    var squareSum = 0.0;
    var sampleCount = 0;
    for (var frame = firstFrame; frame < lastFrame; frame += 1) {
      final frameOffset = pcmOffset + frame * bytesPerFrame;
      for (var channel = 0; channel < channels; channel += 1) {
        final sample = data.getInt16(frameOffset + channel * 2, Endian.little);
        final normalized = sample / 32768;
        squareSum += normalized * normalized;
        sampleCount += 1;
      }
    }
    final rms = math.sqrt(squareSum / sampleCount);
    envelope.add((rms * 2.2).clamp(0, 1));
    firstFrame = lastFrame;
  }
  return List.unmodifiable(envelope);
}

String _ascii(Uint8List bytes, int offset, int length) {
  if (offset < 0 || length < 0 || offset + length > bytes.length) return '';
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}
