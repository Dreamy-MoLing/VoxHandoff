import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/speech.dart';
import '../../domain/voice.dart';

/// Configuration for the official Piper local HTTP server.
///
/// Piper's public HTTP API exposes `/info` for a readiness probe and
/// `/synthesize` for a WAV response. This adapter intentionally accepts only
/// an exact loopback HTTP origin: a Piper service is a user-installed local
/// component, not a generic remote TTS proxy.
class PiperHttpTtsConfig {
  PiperHttpTtsConfig({
    required this.baseUri,
    this.voice,
    this.speaker,
    this.speakerId,
    this.lengthScale = 1,
    this.timeout = const Duration(seconds: 30),
  }) {
    if (!_isExactLoopbackHttp(baseUri) ||
        (voice?.trim().isEmpty ?? false) ||
        (speaker?.trim().isEmpty ?? false) ||
        (speakerId != null && speakerId! < 0) ||
        !lengthScale.isFinite ||
        lengthScale <= 0 ||
        timeout <= Duration.zero) {
      throw const FormatException('The Piper HTTP configuration is unsafe.');
    }
  }

  final Uri baseUri;
  final String? voice;
  final String? speaker;
  final int? speakerId;
  final double lengthScale;
  final Duration timeout;
}

/// Stable capability fields advertised by Piper's official `/info` response.
class PiperVoiceInfo {
  const PiperVoiceInfo({
    required this.name,
    required this.language,
    required this.speakerCount,
  });

  final String name;
  final String language;
  final int speakerCount;
}

class PiperHttpTtsPort implements TtsPort {
  PiperHttpTtsPort({required this.config, HttpClient? client})
    : _client = client ?? HttpClient();

  final PiperHttpTtsConfig config;
  final HttpClient _client;
  final Set<HttpClientRequest> _activeRequests = {};
  var _generation = 0;
  var _closed = false;
  PiperVoiceInfo? _capability;

  PiperVoiceInfo? get capability => _capability;

  /// Confirms that the selected server exposes Piper's information endpoint.
  /// No text is sent during this probe.
  @override
  Future<void> warmUp() async {
    _requireOpen();
    try {
      final request = await _client
          .getUrl(config.baseUri.resolve('/info'))
          .timeout(config.timeout);
      request.followRedirects = false;
      final response = await request.close().timeout(config.timeout);
      final body = await _readBounded(response).timeout(config.timeout);
      final capability = _parseVoiceInfo(body);
      if (response.statusCode != HttpStatus.ok || capability == null) {
        throw const HttpException('Piper information endpoint rejected probe.');
      }
      _capability = capability;
    } on VoicePortException {
      rethrow;
    } on Object {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.configuration,
          code: 'piper_connection_failed',
          safeMessage: 'The local Piper service could not be reached.',
          retryable: true,
        ),
      );
    }
  }

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) async {
    _requireOpen();
    final generation = _generation;
    final stopwatch = Stopwatch()..start();
    HttpClientRequest? activeRequest;
    try {
      final request = await _client
          .postUrl(config.baseUri.resolve('/synthesize'))
          .timeout(config.timeout);
      activeRequest = request;
      _activeRequests.add(request);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'text': segment.text,
            if (config.voice != null) 'voice': config.voice,
            if (config.speaker != null) 'speaker': config.speaker,
            if (config.speakerId != null) 'speaker_id': config.speakerId,
            'length_scale': config.lengthScale,
          }),
        ),
      );
      if (generation != _generation) return _cancelled();
      final response = await request.close().timeout(config.timeout);
      if (generation != _generation) return _cancelled();
      if (response.statusCode != HttpStatus.ok) {
        await _discardBounded(response).timeout(config.timeout);
        throw const HttpException('Piper rejected synthesis.');
      }
      final bytes = await _readBounded(response).timeout(config.timeout);
      if (generation != _generation) return _cancelled();
      if (!_isWav(bytes)) {
        throw const HttpException('Piper returned invalid WAV.');
      }
      stopwatch.stop();
      return SynthesizedSpeech(
        segment: segment,
        bytes: bytes,
        mimeType: 'audio/wav',
        synthesisDuration: stopwatch.elapsed,
      );
    } on VoicePortException {
      rethrow;
    } on Object {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.tts,
          code: 'piper_synthesis_failed',
          safeMessage:
              'Speech synthesis failed. The complete reply is still available.',
          retryable: true,
        ),
      );
    } finally {
      if (activeRequest != null) _activeRequests.remove(activeRequest);
    }
  }

  @override
  Future<void> cancel() async {
    _generation += 1;
    for (final request in _activeRequests.toList(growable: false)) {
      request.abort();
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await cancel();
    _client.close(force: true);
  }

  void _requireOpen() {
    if (_closed) throw StateError('The Piper adapter is closed.');
  }

  Never _cancelled() => throw const VoicePortException(
    VoiceStageFailure(
      stage: VoiceFailureStage.tts,
      code: 'tts_cancelled',
      safeMessage: 'Speech synthesis was cancelled.',
      retryable: true,
    ),
  );
}

Future<Uint8List> _readBounded(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    if (builder.length + chunk.length > 16 * 1024 * 1024) {
      throw const HttpException('Piper response exceeded limit.');
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Future<void> _discardBounded(HttpClientResponse response) async {
  var bytes = 0;
  await for (final chunk in response) {
    bytes += chunk.length;
    if (bytes > 16 * 1024 * 1024) {
      throw const HttpException('Piper response exceeded limit.');
    }
  }
}

PiperVoiceInfo? _parseVoiceInfo(Uint8List bytes) {
  try {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, Object?>) return null;
    final voice = decoded['voice'];
    if (voice is! Map<String, Object?> ||
        voice['name'] is! String ||
        voice['language'] is! String ||
        voice['num_speakers'] is! int) {
      return null;
    }
    final name = (voice['name']! as String).trim();
    final language = (voice['language']! as String).trim();
    final speakerCount = voice['num_speakers']! as int;
    if (name.isEmpty || language.isEmpty || speakerCount < 1) return null;
    return PiperVoiceInfo(
      name: name,
      language: language,
      speakerCount: speakerCount,
    );
  } on Object {
    return null;
  }
}

bool _isWav(Uint8List bytes) =>
    bytes.length >= 44 &&
    bytes[0] == 0x52 &&
    bytes[1] == 0x49 &&
    bytes[2] == 0x46 &&
    bytes[3] == 0x46 &&
    bytes[8] == 0x57 &&
    bytes[9] == 0x41 &&
    bytes[10] == 0x56 &&
    bytes[11] == 0x45;

bool _isExactLoopbackHttp(Uri uri) {
  final host = uri.host.toLowerCase();
  return uri.scheme == 'http' &&
      (host == 'localhost' || host == '127.0.0.1' || host == '::1') &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
}
