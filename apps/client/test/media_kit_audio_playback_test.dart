import 'dart:async';
import 'dart:typed_data';

import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/audio/media_kit_audio_playback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts a bounded RMS envelope from the actual PCM16 WAV bytes', () {
    final wav = _pcm16Wav([
      ...List<int>.filled(800, 0),
      ...List<int>.filled(800, 16384),
    ]);

    final envelope = extractPcm16WavEnvelope(wav);

    expect(envelope, hasLength(2));
    expect(envelope.first, 0);
    expect(envelope.last, closeTo(1, 0.01));
  });

  test('rejects unsupported or malformed audio without inventing a level', () {
    expect(extractPcm16WavEnvelope(Uint8List.fromList([1, 2, 3])), isEmpty);
    final wav = _pcm16Wav([100], audioFormat: 3);
    expect(extractPcm16WavEnvelope(wav), isEmpty);
  });

  test('bounds envelope analysis for oversized audio', () {
    final oversized = Uint8List(maxAnalyzedPcmBytes + 1);

    expect(extractPcm16WavEnvelope(oversized), isEmpty);
  });

  test('extracts the playback envelope outside the caller isolate', () async {
    final wav = _pcm16Wav([
      ...List<int>.filled(800, 0),
      ...List<int>.filled(800, 16384),
    ]);

    final envelope = await extractPcm16WavEnvelopeOffMainIsolate(wav);

    expect(envelope, hasLength(2));
    expect(envelope.last, closeTo(1, 0.01));
  });

  test('playback timeout stops the driver and resets the level', () async {
    final driver = _FakeMediaKitDriver();
    final playback = MediaKitAudioPlayback.withDriver(
      driver,
      completionTimeout: const Duration(milliseconds: 1),
    );
    addTearDown(playback.close);
    final levels = <double>[];
    final subscription = playback.levels.listen(levels.add);
    addTearDown(subscription.cancel);

    await expectLater(
      playback.play(
        SynthesizedSpeech(
          segment: SpeechSegment(
            conversationId: 'conversation-1',
            requestId: 'request-1',
            messageRevision: BigInt.one,
            index: 0,
            text: 'Safe speech.',
          ),
          bytes: _pcm16Wav(List<int>.filled(800, 8192)),
          mimeType: 'audio/wav',
          synthesisDuration: Duration.zero,
        ),
      ),
      throwsA(
        isA<VoicePortException>().having(
          (error) => error.failure.code,
          'failure code',
          'media_kit_playback_failed',
        ),
      ),
    );

    expect(driver.stops, 1);
    expect(levels, isNotEmpty);
    expect(levels.last, 0);
  });

  test(
    'stop during pending open stops stale media after open completes',
    () async {
      final openGate = Completer<void>();
      final driver = _FakeMediaKitDriver(openGate: openGate);
      final playback = MediaKitAudioPlayback.withDriver(driver);
      addTearDown(playback.close);
      final playing = playback.play(
        SynthesizedSpeech(
          segment: SpeechSegment(
            conversationId: 'conversation-1',
            requestId: 'request-stale-open',
            messageRevision: BigInt.one,
            index: 0,
            text: 'Safe speech.',
          ),
          bytes: _pcm16Wav(List<int>.filled(800, 8192)),
          mimeType: 'audio/wav',
          synthesisDuration: Duration.zero,
        ),
      );
      await driver.openStarted.future;

      await playback.stopSpeech();
      openGate.complete();
      await playing;

      expect(driver.stops, 2);
      expect(driver.listeners, 0);
    },
  );

  test(
    'completion stream errors fail safely and release the listener',
    () async {
      final driver = _FakeMediaKitDriver();
      final playback = MediaKitAudioPlayback.withDriver(driver);
      addTearDown(playback.close);
      final playing = playback.play(
        SynthesizedSpeech(
          segment: SpeechSegment(
            conversationId: 'conversation-1',
            requestId: 'request-stream-error',
            messageRevision: BigInt.one,
            index: 0,
            text: 'Safe speech.',
          ),
          bytes: _pcm16Wav(List<int>.filled(800, 8192)),
          mimeType: 'audio/wav',
          synthesisDuration: Duration.zero,
        ),
      );
      await driver.openStarted.future;
      driver.emitCompletionError();

      await expectLater(playing, throwsA(isA<VoicePortException>()));
      expect(driver.stops, 1);
      expect(driver.listeners, 0);
    },
  );
}

class _FakeMediaKitDriver implements MediaKitPlayerDriver {
  _FakeMediaKitDriver({this.openGate}) {
    _completed = StreamController<bool>.broadcast(
      onListen: () => listeners += 1,
      onCancel: () => listeners -= 1,
    );
  }

  final Completer<void>? openGate;
  late final StreamController<bool> _completed;
  final Completer<void> openStarted = Completer<void>();
  int stops = 0;
  int listeners = 0;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Future<void> open(Uint8List bytes, String mimeType) async {
    if (!openStarted.isCompleted) openStarted.complete();
    await openGate?.future;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  void emitCompletionError() {
    _completed.addError(StateError('synthetic completion failure'));
  }

  @override
  Future<void> dispose() => _completed.close();
}

Uint8List _pcm16Wav(List<int> samples, {int audioFormat = 1}) {
  const sampleRate = 16000;
  const channels = 1;
  const bitsPerSample = 16;
  final pcmLength = samples.length * 2;
  final bytes = Uint8List(44 + pcmLength);
  final data = ByteData.sublistView(bytes);
  _ascii(bytes, 0, 'RIFF');
  data.setUint32(4, 36 + pcmLength, Endian.little);
  _ascii(bytes, 8, 'WAVE');
  _ascii(bytes, 12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, audioFormat, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  _ascii(bytes, 36, 'data');
  data.setUint32(40, pcmLength, Endian.little);
  for (var index = 0; index < samples.length; index += 1) {
    data.setInt16(44 + index * 2, samples[index], Endian.little);
  }
  return bytes;
}

void _ascii(Uint8List target, int offset, String value) {
  target.setRange(offset, offset + value.length, value.codeUnits);
}
