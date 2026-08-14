import 'dart:async';

import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/audio/record_audio_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android channel streams PCM frames and maps stop lifecycle', () async {
    const control = MethodChannel(AndroidAudioRecordChannel.controlChannelName);
    const events = EventChannel(AndroidAudioRecordChannel.eventChannelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    MockStreamHandlerEventSink? eventSink;
    var eventListening = false;

    messenger.setMockMethodCallHandler(control, (call) async {
      calls.add(call);
      if (call.method == 'start') {
        expect(eventListening, isTrue);
      }
      return null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          eventListening = true;
          eventSink = sink;
        },
        onCancel: (_) {},
      ),
    );

    final capture = RecordAudioCapture(
      androidBridge: AndroidAudioRecordChannel(
        controlChannel: control,
        eventChannel: events,
      ),
    );
    addTearDown(capture.close);

    final session = await capture.start(const AudioCaptureConfig());
    final chunkFuture = session.audioChunks.first;
    final levelFuture = session.levels.first;
    await Future<void>.delayed(Duration.zero);
    eventSink!.success({
      'pcm': Uint8List.fromList([1, 0, 2, 0]),
      'level': 0.25,
    });

    expect(await chunkFuture, orderedEquals([1, 0, 2, 0]));
    expect(await levelFuture, 0.25);
    await session.stop();

    expect(calls.map((call) => call.method), ['start', 'stop']);
    expect(calls.first.arguments, {'sampleRate': 16000, 'channels': 1});
  });

  test('Android channel rejects a non-16 kHz mono capture request', () async {
    final capture = RecordAudioCapture(androidBridge: _NoopAndroidBridge());
    addTearDown(capture.close);

    await expectLater(
      capture.start(const AudioCaptureConfig(channels: 2)),
      throwsA(
        isA<VoicePortException>().having(
          (error) => error.failure.code,
          'code',
          'recording_pcm_unsupported',
        ),
      ),
    );
  });

  test(
    'Android capture can stop while the native frame stream is quiet',
    () async {
      final bridge = _QuietAndroidBridge();
      final capture = RecordAudioCapture(androidBridge: bridge);
      addTearDown(capture.close);

      final session = await capture.start(const AudioCaptureConfig());
      final audioSubscription = session.audioChunks.listen((_) {});
      final levelSubscription = session.levels.listen((_) {});

      await session.stop();
      await audioSubscription.cancel();
      await levelSubscription.cancel();

      expect(bridge.starts, 1);
      expect(bridge.stops, 1);
      expect(bridge.cancels, 0);
    },
  );
}

class _NoopAndroidBridge implements AndroidAudioRecordBridge {
  @override
  Stream<AndroidAudioFrame> get frames =>
      const Stream<AndroidAudioFrame>.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> start(AudioCaptureConfig config) async {}

  @override
  Future<void> stop() async {}
}

class _QuietAndroidBridge implements AndroidAudioRecordBridge {
  final _framesController = StreamController<AndroidAudioFrame>.broadcast();
  int starts = 0;
  int stops = 0;
  int cancels = 0;

  @override
  Stream<AndroidAudioFrame> get frames => _framesController.stream;

  @override
  Future<void> cancel() async {
    cancels += 1;
  }

  @override
  Future<void> close() async {
    await _framesController.close();
  }

  @override
  Future<void> start(AudioCaptureConfig config) async {
    starts += 1;
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }
}
