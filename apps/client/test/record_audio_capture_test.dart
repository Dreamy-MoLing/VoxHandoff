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

    messenger.setMockMethodCallHandler(control, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, sink) => eventSink = sink,
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
