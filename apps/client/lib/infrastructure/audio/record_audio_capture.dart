import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import '../../domain/voice.dart';

/// The native Android PCM bridge used instead of the `record` Android path.
abstract interface class AndroidAudioRecordBridge {
  Stream<AndroidAudioFrame> get frames;

  Future<void> start(AudioCaptureConfig config);
  Future<void> stop();
  Future<void> cancel();
  Future<void> close();
}

class AndroidAudioFrame {
  const AndroidAudioFrame({required this.pcm, required this.level});

  factory AndroidAudioFrame.fromPlatform(Object? event) {
    if (event is! Map) {
      throw const FormatException('Android audio event is not a map.');
    }
    final rawPcm = event['pcm'];
    final pcm = switch (rawPcm) {
      Uint8List value => value,
      List value => Uint8List.fromList(
        value.cast<num>().map((v) => v.toInt()).toList(),
      ),
      _ => throw const FormatException('Android audio event has no PCM bytes.'),
    };
    final rawLevel = event['level'];
    if (rawLevel is! num || !rawLevel.isFinite) {
      throw const FormatException('Android audio event has no valid level.');
    }
    return AndroidAudioFrame(pcm: pcm, level: rawLevel.toDouble().clamp(0, 1));
  }

  final Uint8List pcm;
  final double level;
}

class AndroidAudioRecordChannel implements AndroidAudioRecordBridge {
  AndroidAudioRecordChannel({
    MethodChannel? controlChannel,
    EventChannel? eventChannel,
  }) : _controlChannel =
           controlChannel ?? const MethodChannel(controlChannelName),
       _eventChannel = eventChannel ?? const EventChannel(eventChannelName);

  static const controlChannelName = 'agent_talk/android_audio_capture';
  static const eventChannelName = 'agent_talk/android_audio_capture_events';

  final MethodChannel _controlChannel;
  final EventChannel _eventChannel;
  Stream<AndroidAudioFrame>? _frames;

  @override
  Stream<AndroidAudioFrame> get frames => _frames ??= _eventChannel
      .receiveBroadcastStream()
      .map(AndroidAudioFrame.fromPlatform);

  @override
  Future<void> start(AudioCaptureConfig config) async {
    await _controlChannel.invokeMethod<void>('start', {
      'sampleRate': config.sampleRate,
      'channels': config.channels,
      if (config.microphoneId != null) 'microphoneId': config.microphoneId,
    });
  }

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> cancel() => _invoke('cancel');

  @override
  Future<void> close() => _invoke('dispose');

  Future<void> _invoke(String method) async {
    await _controlChannel.invokeMethod<void>(method);
  }
}

/// Five-platform PCM capture.
///
/// Android uses the app's native AudioRecord through a platform channel. The
/// other platforms continue to use the existing in-memory `record` stream.
class RecordAudioCapture
    implements AudioCapturePort, AudioInputDeviceEnumerator {
  RecordAudioCapture({
    AudioRecorder? recorder,
    AndroidAudioRecordBridge? androidBridge,
  }) : _providedRecorder = recorder,
       _androidBridge =
           androidBridge ??
           (Platform.isAndroid ? AndroidAudioRecordChannel() : null);

  final AudioRecorder? _providedRecorder;
  final AndroidAudioRecordBridge? _androidBridge;
  AudioRecorder? _recorder;
  AudioCaptureSession? _active;
  bool _closed = false;

  AudioRecorder get _desktopRecorder =>
      _recorder ??= _providedRecorder ?? AudioRecorder();

  @override
  Future<List<AudioInputDevice>> listInputDevices() async {
    if (_closed) return const [];
    try {
      final devices = await _desktopRecorder.listInputDevices();
      return devices
          .where((device) => device.id.trim().isNotEmpty)
          .map((device) => AudioInputDevice(id: device.id, label: device.label))
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  @override
  Future<AudioCaptureSession> start(AudioCaptureConfig config) async {
    if (_closed) {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.recording,
          code: 'recording_adapter_closed',
          safeMessage: 'The microphone adapter is unavailable.',
          retryable: false,
        ),
      );
    }
    if (_active != null) {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.recording,
          code: 'recording_session_conflict',
          safeMessage: 'Another recording is already active.',
          retryable: true,
        ),
      );
    }

    final androidBridge = _androidBridge;
    if (androidBridge != null) {
      if (config.sampleRate != 16000 || config.channels != 1) {
        throw const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.recording,
            code: 'recording_pcm_unsupported',
            safeMessage: 'Android recording requires 16 kHz mono PCM audio.',
            retryable: false,
          ),
        );
      }
      final session = _AndroidAudioCaptureSession(
        bridge: androidBridge,
        config: config,
        onClosed: () => _active = null,
      );
      _active = session;
      try {
        await session.start();
        return session;
      } on Object {
        _active = null;
        await session.cancel();
        rethrow;
      }
    }

    try {
      final recorder = _desktopRecorder;
      if (!await recorder.hasPermission()) {
        throw const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.recording,
            code: 'microphone_permission_denied',
            safeMessage:
                'Microphone access was denied. Enable it in system settings to record.',
            retryable: true,
          ),
        );
      }
      if (!await recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
        throw const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.recording,
            code: 'recording_pcm_unsupported',
            safeMessage: 'This device cannot provide the required PCM audio.',
            retryable: false,
          ),
        );
      }
      final recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: config.sampleRate,
        numChannels: config.channels,
        streamBufferSize: config.sampleRate * config.channels * 2 ~/ 10,
        device: config.microphoneId == null
            ? null
            : InputDevice(id: config.microphoneId!, label: ''),
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      );
      final stream = await recorder.startStream(recordConfig);
      final session = _RecordAudioCaptureSession(
        recorder: recorder,
        audioChunks: stream,
        onClosed: () => _active = null,
      );
      _active = session;
      return session;
    } on VoicePortException {
      rethrow;
    } on Object {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.recording,
          code: 'recording_device_unavailable',
          safeMessage: 'The microphone could not start on this device.',
          retryable: true,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _active?.cancel();
    } finally {
      await _androidBridge?.close();
      await (_recorder ?? _providedRecorder)?.dispose();
    }
  }
}

class _AndroidAudioCaptureSession implements AudioCaptureSession {
  _AndroidAudioCaptureSession({
    required this.bridge,
    required this.config,
    required this.onClosed,
  });

  final AndroidAudioRecordBridge bridge;
  final AudioCaptureConfig config;
  final void Function() onClosed;
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>();
  final StreamController<double> _levelController = StreamController<double>();
  late final StreamSubscription<AndroidAudioFrame> _frameSubscription;
  bool _closing = false;
  bool _discarding = false;
  bool _closed = false;

  Future<void> start() async {
    _frameSubscription = bridge.frames.listen(
      (frame) {
        if (_closed || _discarding) return;
        _audioController.add(frame.pcm);
        _levelController.add(frame.level);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (_closed || _discarding) return;
        final failure = _androidRecordingFailure(
          error,
          fallbackCode: 'recording_stream_failed',
        );
        _audioController.addError(failure, stackTrace);
        _levelController.addError(failure, stackTrace);
      },
      onDone: () {
        if (_closed || _closing) return;
        final failure = const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.recording,
            code: 'recording_stream_closed',
            safeMessage: 'The microphone stream closed unexpectedly.',
            retryable: true,
          ),
        );
        _audioController.addError(failure);
        _levelController.addError(failure);
      },
    );
    try {
      await bridge.start(config);
    } on Object catch (error) {
      await _frameSubscription.cancel();
      _audioController.close();
      _levelController.close();
      onClosed();
      throw _androidRecordingFailure(error);
    }
  }

  @override
  Stream<Uint8List> get audioChunks => _audioController.stream;

  @override
  Stream<double> get levels => _levelController.stream;

  @override
  Future<void> stop() => _finish(discard: false);

  @override
  Future<void> cancel() => _finish(discard: true);

  Future<void> _finish({required bool discard}) async {
    if (_closed) return;
    _closing = true;
    _discarding = discard;
    Object? failure;
    try {
      if (discard) {
        await bridge.cancel();
      } else {
        await bridge.stop();
      }
    } on Object catch (error) {
      failure = _androidRecordingFailure(
        error,
        fallbackCode: 'recording_stop_failed',
      );
    } finally {
      _closed = true;
      await _frameSubscription.cancel();
      await _audioController.close();
      await _levelController.close();
      onClosed();
    }
    if (failure != null) throw failure;
  }
}

abstract class _RecordAudioCaptureSessionBase implements AudioCaptureSession {
  _RecordAudioCaptureSessionBase({required this.recorder});

  final AudioRecorder recorder;

  @override
  Stream<double> get levels => recorder
      .onAmplitudeChanged(const Duration(milliseconds: 80))
      .map((amplitude) => _normalizedAmplitude(amplitude.current));
}

class _RecordAudioCaptureSession extends _RecordAudioCaptureSessionBase {
  _RecordAudioCaptureSession({
    required super.recorder,
    required this.audioChunks,
    required this._onClosed,
  });

  @override
  final Stream<Uint8List> audioChunks;
  final void Function() _onClosed;

  bool _closed = false;

  @override
  Future<void> stop() => _finish(discard: false);

  @override
  Future<void> cancel() => _finish(discard: true);

  Future<void> _finish({required bool discard}) async {
    if (_closed) return;
    _closed = true;
    try {
      if (discard) {
        await recorder.cancel();
      } else {
        await recorder.stop();
      }
    } on Object {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.recording,
          code: 'recording_stop_failed',
          safeMessage: 'The microphone stream could not close cleanly.',
          retryable: true,
        ),
      );
    } finally {
      _onClosed();
    }
  }
}

VoicePortException _androidRecordingFailure(
  Object error, {
  String fallbackCode = 'recording_device_unavailable',
}) {
  if (error is VoicePortException) return error;
  final platformCode = error is PlatformException ? error.code : '';
  final code = switch (platformCode) {
    'permission_denied' => 'microphone_permission_denied',
    'format_unsupported' => 'recording_pcm_unsupported',
    'session_conflict' => 'recording_session_conflict',
    'recording_start_failed' => 'recording_device_unavailable',
    'audio_read_failed' => 'recording_stream_failed',
    'recording_stop_failed' => 'recording_stop_failed',
    _ => fallbackCode,
  };
  final safeMessage = switch (code) {
    'microphone_permission_denied' =>
      'Microphone access was denied. Enable it in system settings to record.',
    'recording_pcm_unsupported' =>
      'This device cannot provide the required PCM audio.',
    'recording_session_conflict' => 'Another recording is already active.',
    'recording_stream_failed' =>
      'The microphone stream failed while recording.',
    'recording_stop_failed' => 'The microphone stream could not close cleanly.',
    _ => 'The microphone could not start on this device.',
  };
  return VoicePortException(
    VoiceStageFailure(
      stage: VoiceFailureStage.recording,
      code: code,
      safeMessage: safeMessage,
      retryable: code != 'recording_pcm_unsupported',
    ),
  );
}

double _normalizedAmplitude(double dbfs) {
  if (!dbfs.isFinite || dbfs <= -80) return 0;
  if (dbfs >= 0) return 1;
  return math.pow(10, dbfs / 20).toDouble().clamp(0, 1);
}
