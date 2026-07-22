import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../domain/voice.dart';

/// Five-platform PCM capture backed by the `record` plugin.
///
/// The adapter never writes a recording to disk. A stopped stream is drained
/// before STT finalization so the platform's final PCM buffer is not lost.
class RecordAudioCapture implements AudioCapturePort {
  RecordAudioCapture({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  _RecordAudioCaptureSession? _active;
  bool _closed = false;

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
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: config.sampleRate,
          numChannels: config.channels,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
      final session = _RecordAudioCaptureSession(
        recorder: _recorder,
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
    await _active?.cancel();
    await _recorder.dispose();
  }
}

class _RecordAudioCaptureSession implements AudioCaptureSession {
  _RecordAudioCaptureSession({
    required this._recorder,
    required this.audioChunks,
    required this._onClosed,
  });

  final AudioRecorder _recorder;
  final void Function() _onClosed;

  @override
  final Stream<Uint8List> audioChunks;

  bool _closed = false;

  @override
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 80))
      .map((amplitude) => _normalizedAmplitude(amplitude.current));

  @override
  Future<void> stop() => _finish(discard: false);

  @override
  Future<void> cancel() => _finish(discard: true);

  Future<void> _finish({required bool discard}) async {
    if (_closed) return;
    _closed = true;
    try {
      if (discard) {
        await _recorder.cancel();
      } else {
        await _recorder.stop();
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

double _normalizedAmplitude(double dbfs) {
  if (!dbfs.isFinite || dbfs <= -80) return 0;
  if (dbfs >= 0) return 1;
  return math.pow(10, dbfs / 20).toDouble().clamp(0, 1);
}
