import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/voice.dart';

/// Five-platform PCM capture backed by the `record` plugin.
///
/// Android uses an app-private temporary PCM file because the acceptance phone
/// opened AudioRecord but delivered no bytes through the plugin EventChannel.
/// The file is read into memory and deleted as part of stop/cancel cleanup.
/// Other platforms continue to use the in-memory stream path.
class RecordAudioCapture
    implements AudioCapturePort, AudioInputDeviceEnumerator {
  RecordAudioCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  AudioCaptureSession? _active;
  bool _closed = false;

  @override
  Future<List<AudioInputDevice>> listInputDevices() async {
    if (_closed) return const [];
    try {
      final devices = await _recorder.listInputDevices();
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
    String? temporaryPath;
    try {
      if (!await _recorder.hasPermission()) {
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
      if (!await _recorder.isEncoderSupported(AudioEncoder.pcm16bits)) {
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
        // DEFAULT is device-dependent on Android and was observed as an
        // inactive AUDIO_DEVICE_NONE input on the acceptance phone. Use
        // Android's speech-recognition input path explicitly so the
        // AudioRecord PCM stream is backed by the active microphone source.
        androidConfig: const AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceRecognition,
        ),
        // Keep stream-mode platforms at a bounded 100 ms PCM frame.
        streamBufferSize: config.sampleRate * config.channels * 2 ~/ 10,
        device: config.microphoneId == null
            ? null
            : InputDevice(id: config.microphoneId!, label: ''),
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      );
      late final AudioCaptureSession session;
      if (Platform.isAndroid) {
        final path = await _temporaryPcmPath();
        temporaryPath = path;
        await _recorder.start(recordConfig, path: path);
        session = _FileRecordAudioCaptureSession(
          recorder: _recorder,
          path: path,
          onClosed: () => _active = null,
        );
      } else {
        final stream = await _recorder.startStream(recordConfig);
        session = _RecordAudioCaptureSession(
          recorder: _recorder,
          audioChunks: stream,
          onClosed: () => _active = null,
        );
      }
      _active = session;
      return session;
    } on VoicePortException {
      if (temporaryPath != null) await _deleteTemporaryFile(temporaryPath);
      rethrow;
    } on Object {
      if (temporaryPath != null) await _deleteTemporaryFile(temporaryPath);
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

  Future<String> _temporaryPcmPath() async {
    final directory = await getTemporaryDirectory();
    final suffix = math.Random.secure().nextInt(1 << 32).toRadixString(16);
    return '${directory.path}${Platform.pathSeparator}voxhandoff-recording-$suffix.pcm';
  }

  Future<void> _deleteTemporaryFile(String path) async {
    try {
      await File(path).delete();
    } on Object {
      // Cleanup is best effort after a failed start; no audio or path is
      // included in user-facing errors.
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _active?.cancel();
    await _recorder.dispose();
  }
}

abstract class _RecordAudioCaptureSessionBase implements AudioCaptureSession {
  _RecordAudioCaptureSessionBase({
    required this.recorder,
  });

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

class _FileRecordAudioCaptureSession extends _RecordAudioCaptureSessionBase {
  _FileRecordAudioCaptureSession({
    required super.recorder,
    required this.path,
    required this._onClosed,
  });

  final String path;
  final void Function() _onClosed;
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>();
  bool _closed = false;

  @override
  Stream<Uint8List> get audioChunks => _audioController.stream;

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
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _audioController.add(Uint8List.fromList(bytes));
          }
        }
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
      await _audioController.close();
      try {
        await File(path).delete();
      } on Object {
        // The application-private temporary file is best-effort cleaned up;
        // the product retention policy handles a failed cleanup separately.
      }
      _onClosed();
    }
  }
}

double _normalizedAmplitude(double dbfs) {
  if (!dbfs.isFinite || dbfs <= -80) return 0;
  if (dbfs >= 0) return 1;
  return math.pow(10, dbfs / 20).toDouble().clamp(0, 1);
}
