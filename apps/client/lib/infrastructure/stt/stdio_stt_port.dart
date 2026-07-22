import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/voice.dart';

const _protocol = <String, int>{'major': 1, 'minor': 0};
const _maxLineCharacters = 1048576;

typedef SttSidecarLauncher = Future<Process> Function();

/// Local STT adapter for the versioned JSONL sidecar.
///
/// Production callers must supply a launcher for a bundled, canonical
/// executable. User text and PATH-derived commands are intentionally absent
/// from this boundary.
class StdioSttPort implements SttPort {
  StdioSttPort({required this._launch});

  final SttSidecarLauncher _launch;
  Process? _process;
  StreamSubscription<String>? _stdout;
  StreamSubscription<List<int>>? _stderr;
  final Map<String, Completer<Map<String, Object?>>> _pending = {};
  final Map<String, StreamController<TranscriptUpdate>> _updates = {};
  int _requestSequence = 0;
  bool _closed = false;

  @override
  Future<void> warmUp() async {
    await _request('warmup');
  }

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) async {
    if (_updates.containsKey(sessionId)) {
      throw _failure('stt_session_conflict', 'Another STT session is active.');
    }
    final controller = StreamController<TranscriptUpdate>.broadcast();
    _updates[sessionId] = controller;
    try {
      await _request('start', {
        'session_id': sessionId,
        'sample_rate': audio.sampleRate,
        'channels': audio.channels,
        'language': ?language,
      });
      return _StdioSttSession(owner: this, sessionId: sessionId);
    } on Object {
      _updates.remove(sessionId);
      await controller.close();
      rethrow;
    }
  }

  Stream<TranscriptUpdate> _sessionUpdates(String sessionId) =>
      _updates[sessionId]!.stream;

  Future<void> _push(String sessionId, int sequence, Uint8List audio) async {
    if (audio.isEmpty) return;
    await _request('push', {
      'session_id': sessionId,
      'sequence': sequence,
      'audio_base64': base64Encode(audio),
    });
  }

  Future<FinalTranscript> _finish(String sessionId) async {
    try {
      final result = await _request('end', {'session_id': sessionId});
      return FinalTranscript(
        text: _requiredString(result, 'text'),
        language: result['language'] is String
            ? result['language']! as String
            : null,
        confidence: result['confidence'] is num
            ? (result['confidence']! as num).toDouble()
            : null,
        audioDuration: Duration(
          milliseconds: _requiredInt(result, 'audio_duration_ms'),
        ),
        transcriptionDuration: Duration(
          milliseconds: _requiredInt(result, 'duration_ms'),
        ),
      );
    } finally {
      await _removeSession(sessionId);
    }
  }

  Future<void> _cancel(String sessionId) async {
    try {
      await _request('cancel', {'session_id': sessionId});
    } on VoicePortException catch (error) {
      if (error.failure.code != 'stt_session_unknown') rethrow;
    } finally {
      await _removeSession(sessionId);
    }
  }

  Future<Map<String, Object?>> _request(
    String method, [
    Map<String, Object?> params = const {},
  ]) async {
    if (_closed) {
      throw _failure('stt_adapter_closed', 'The local STT service is closed.');
    }
    await _ensureProcess();
    final id = 'stt-${++_requestSequence}';
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    try {
      _process!.stdin.writeln(
        jsonEncode({
          'protocol': _protocol,
          'id': id,
          'method': method,
          'params': params,
        }),
      );
      await _process!.stdin.flush();
    } on Object {
      _pending.remove(id);
      throw _failure(
        'stt_sidecar_unavailable',
        'The local STT service became unavailable.',
      );
    }
    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pending.remove(id);
        throw _failure(
          'stt_sidecar_timeout',
          'The local STT service timed out.',
        );
      },
    );
  }

  Future<void> _ensureProcess() async {
    if (_process != null) return;
    try {
      final process = await _launch();
      _process = process;
      _stdout = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_acceptLine, onError: (_) => _sidecarLost());
      // Drain stderr to prevent deadlock. Its content is deliberately not
      // surfaced or logged because native backends may include private paths.
      _stderr = process.stderr.listen((_) {});
      unawaited(process.exitCode.then((_) => _sidecarLost()));
    } on Object {
      _process = null;
      throw _failure(
        'stt_sidecar_unavailable',
        'The bundled local STT service could not start.',
      );
    }
  }

  void _acceptLine(String line) {
    if (line.length > _maxLineCharacters) {
      _sidecarLost();
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on Object {
      _sidecarLost();
      return;
    }
    if (decoded is! Map<String, Object?> || !_validProtocol(decoded)) {
      _sidecarLost();
      return;
    }
    final event = decoded['event'];
    if (event is String) {
      _acceptEvent(decoded, event);
      return;
    }
    final id = decoded['id'];
    if (id is! String) return;
    final completer = _pending.remove(id);
    if (completer == null) return;
    final error = decoded['error'];
    if (error is Map<String, Object?>) {
      completer.completeError(
        _failure(
          error['code'] is String
              ? error['code']! as String
              : 'stt_sidecar_failure',
          error['message'] is String
              ? error['message']! as String
              : 'The local STT service failed.',
        ),
      );
      return;
    }
    final result = decoded['result'];
    if (result is Map<String, Object?>) {
      completer.complete(result);
    } else {
      completer.completeError(
        _failure('stt_protocol_invalid', 'The local STT response was invalid.'),
      );
    }
  }

  void _acceptEvent(Map<String, Object?> value, String event) {
    final sessionId = value['session_id'];
    final sequence = value['sequence'];
    if (sessionId is! String || sequence is! int) return;
    final controller = _updates[sessionId];
    if (controller == null) return;
    if (event == 'transcript.provisional' && value['text'] is String) {
      controller.add(
        TranscriptUpdate(text: value['text']! as String, sequence: sequence),
      );
    }
  }

  Future<void> _removeSession(String sessionId) async {
    final controller = _updates.remove(sessionId);
    await controller?.close();
  }

  void _sidecarLost() {
    if (_process == null) return;
    _process = null;
    final error = _failure(
      'stt_sidecar_lost',
      'The local STT service stopped unexpectedly.',
    );
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
    for (final controller in _updates.values) {
      controller.addError(error);
      unawaited(controller.close());
    }
    _updates.clear();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final process = _process;
    if (process != null) _sidecarLost();
    process?.kill();
    await process?.stdin.close();
    await _stdout?.cancel();
    await _stderr?.cancel();
  }
}

class _StdioSttSession implements SttSessionPort {
  _StdioSttSession({required this._owner, required this.sessionId});

  final StdioSttPort _owner;
  final String sessionId;
  int _sequence = 0;
  bool _closed = false;

  @override
  Stream<TranscriptUpdate> get updates => _owner._sessionUpdates(sessionId);

  @override
  Future<void> push(Uint8List audio) {
    if (_closed) return Future.value();
    return _owner._push(sessionId, ++_sequence, audio);
  }

  @override
  Future<FinalTranscript> finish() {
    if (_closed) {
      throw StateError('The STT session is already closed.');
    }
    _closed = true;
    return _owner._finish(sessionId);
  }

  @override
  Future<void> cancel() async {
    if (_closed) return;
    _closed = true;
    await _owner._cancel(sessionId);
  }
}

bool _validProtocol(Map<String, Object?> value) {
  final protocol = value['protocol'];
  return protocol is Map<String, Object?> &&
      protocol['major'] == 1 &&
      protocol['minor'] == 0;
}

String _requiredString(Map<String, Object?> value, String name) {
  final field = value[name];
  if (field is String) return field;
  throw _failure('stt_protocol_invalid', 'The local STT response was invalid.');
}

int _requiredInt(Map<String, Object?> value, String name) {
  final field = value[name];
  if (field is int && field >= 0) return field;
  throw _failure('stt_protocol_invalid', 'The local STT response was invalid.');
}

VoicePortException _failure(String code, String message) => VoicePortException(
  VoiceStageFailure(
    stage: VoiceFailureStage.stt,
    code: code,
    safeMessage: message,
    retryable: true,
  ),
);
