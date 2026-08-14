import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/voice.dart';

class RemoteSttDisclosure {
  const RemoteSttDisclosure({
    required this.providerId,
    required this.origin,
    required this.tlsPolicy,
    required this.retentionPolicy,
    required this.streaming,
    required this.revision,
  });

  final String providerId;
  final Uri origin;
  final String tlsPolicy;
  final String retentionPolicy;
  final bool streaming;
  final String revision;

  bool get isSecureOrigin =>
      origin.scheme == 'https' &&
      origin.host.isNotEmpty &&
      origin.userInfo.isEmpty &&
      (origin.path.isEmpty || origin.path == '/') &&
      !origin.hasQuery &&
      !origin.hasFragment;

  @override
  bool operator ==(Object other) =>
      other is RemoteSttDisclosure &&
      other.providerId == providerId &&
      other.origin == origin &&
      other.tlsPolicy == tlsPolicy &&
      other.retentionPolicy == retentionPolicy &&
      other.streaming == streaming &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(
    providerId,
    origin,
    tlsPolicy,
    retentionPolicy,
    streaming,
    revision,
  );
}

class RemoteSttConsent {
  const RemoteSttConsent({required this.disclosure, required this.acceptedAt});

  final RemoteSttDisclosure disclosure;
  final DateTime acceptedAt;
}

class RemoteSttRequest {
  const RemoteSttRequest({
    required this.sessionId,
    required this.audio,
    required this.sampleRate,
    required this.channels,
    required this.language,
  });

  final String sessionId;
  final Uint8List audio;
  final int sampleRate;
  final int channels;
  final String? language;
}

abstract interface class RemoteSttTransport {
  Future<void> warmUp(RemoteSttDisclosure disclosure);

  Future<FinalTranscript> transcribe(
    RemoteSttDisclosure disclosure,
    RemoteSttRequest request,
  );

  Future<void> close();
}

typedef RemoteSttTokenProvider = Future<String> Function(String providerId);

/// Concrete versioned HTTPS transport for VoxHandoff-compatible remote STT.
/// Authentication is isolated from Agent/Gateway credentials by a dedicated
/// provider callback. Upstream bodies are bounded and never included in errors.
class JsonHttpRemoteSttTransport implements RemoteSttTransport {
  JsonHttpRemoteSttTransport({
    required this.tokenProvider,
    List<int>? trustedRootCertificates,
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? _httpClientWithTrustedRoots(trustedRootCertificates);

  final RemoteSttTokenProvider tokenProvider;
  final HttpClient _client;
  final Duration timeout;
  bool _closed = false;

  @override
  Future<void> warmUp(RemoteSttDisclosure disclosure) async {
    if (_closed) throw StateError('The remote STT transport is closed.');
    _requireSecureDisclosure(disclosure);
    final request = await _client
        .getUrl(disclosure.origin.resolve('/v1/health'))
        .timeout(timeout);
    request.followRedirects = false;
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      throw _remoteFailure('remote_stt_unavailable');
    }
  }

  @override
  Future<FinalTranscript> transcribe(
    RemoteSttDisclosure disclosure,
    RemoteSttRequest value,
  ) async {
    if (_closed) throw StateError('The remote STT transport is closed.');
    _requireSecureDisclosure(disclosure);
    try {
      final token = await tokenProvider(disclosure.providerId);
      if (token.isEmpty) throw const FormatException('Missing provider token.');
      final stopwatch = Stopwatch()..start();
      final request = await _client
          .postUrl(disclosure.origin.resolve('/v1/transcribe'))
          .timeout(timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.add(
        utf8.encode(
          jsonEncode({
            'protocol': {'major': 1, 'minor': 0},
            'session_id': value.sessionId,
            'audio_format': 'pcm_s16le',
            'sample_rate': value.sampleRate,
            'channels': value.channels,
            'language': ?value.language,
            'audio_base64': base64Encode(value.audio),
          }),
        ),
      );
      final response = await request.close().timeout(timeout);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        if (bytes.length + chunk.length > 1048576) {
          throw const FormatException('Remote STT response exceeded limit.');
        }
        bytes.add(chunk);
      }
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('Remote STT rejected transcription.');
      }
      final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
      if (decoded is! Map<String, Object?> || decoded['text'] is! String) {
        throw const FormatException('Remote STT response was invalid.');
      }
      stopwatch.stop();
      final audioMilliseconds =
          value.audio.length * 1000 ~/ (value.sampleRate * value.channels * 2);
      return FinalTranscript(
        text: decoded['text']! as String,
        language: decoded['language'] is String
            ? decoded['language']! as String
            : null,
        confidence: decoded['confidence'] is num
            ? (decoded['confidence']! as num).toDouble()
            : null,
        audioDuration: Duration(milliseconds: audioMilliseconds),
        transcriptionDuration: stopwatch.elapsed,
      );
    } on VoicePortException {
      rethrow;
    } on Object {
      throw _remoteFailure('remote_stt_transcription_failed');
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
  }
}

void _requireSecureDisclosure(RemoteSttDisclosure disclosure) {
  if (!disclosure.isSecureOrigin) {
    throw const VoicePortException(
      VoiceStageFailure(
        stage: VoiceFailureStage.configuration,
        code: 'remote_stt_origin_unsafe',
        safeMessage: 'The remote speech provider origin is unsafe.',
        retryable: false,
      ),
    );
  }
}

VoicePortException _remoteFailure(String code) => VoicePortException(
  VoiceStageFailure(
    stage: VoiceFailureStage.stt,
    code: code,
    safeMessage: 'Remote speech recognition failed. No Agent request was sent.',
    retryable: true,
  ),
);

HttpClient _httpClientWithTrustedRoots(List<int>? trustedRootCertificates) {
  if (trustedRootCertificates == null) return HttpClient();
  if (trustedRootCertificates.isEmpty) {
    throw const FormatException(
      'The trusted root certificate cannot be empty.',
    );
  }
  // An explicitly imported private CA is the complete trust set for this
  // provider. When no custom CA is supplied, HttpClient keeps the platform
  // roots through its default context.
  final context = SecurityContext(withTrustedRoots: false)
    ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
  try {
    context.setTrustedCertificatesBytes(
      Uint8List.fromList(trustedRootCertificates),
    );
  } on Object {
    throw const FormatException('The trusted root certificate is invalid.');
  }
  return HttpClient(context: context);
}

/// Explicit-consent remote fallback. It is impossible to construct an active
/// adapter when origin, TLS, retention, streaming mode, or provider revision
/// differs from the exact disclosure the user accepted.
class ConsentedRemoteSttPort implements SttPort {
  ConsentedRemoteSttPort({
    required this.disclosure,
    required RemoteSttConsent consent,
    required this._transport,
    this.maxAudio = const Duration(minutes: 2),
  }) {
    if (!disclosure.isSecureOrigin || consent.disclosure != disclosure) {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.configuration,
          code: 'remote_stt_consent_required',
          safeMessage:
              'Review and accept the current remote speech provider disclosure.',
          retryable: false,
        ),
      );
    }
  }

  final RemoteSttDisclosure disclosure;
  final RemoteSttTransport _transport;
  final Duration maxAudio;

  @override
  Future<void> warmUp() => _transport.warmUp(disclosure);

  @override
  Future<SttSessionPort> start({
    required String sessionId,
    required AudioCaptureConfig audio,
    String? language,
  }) async => _BufferedRemoteSttSession(
    disclosure: disclosure,
    transport: _transport,
    sessionId: sessionId,
    config: audio,
    language: language,
    maximumBytes: audio.sampleRate * audio.channels * 2 * maxAudio.inSeconds,
  );

  @override
  Future<void> close() => _transport.close();
}

class _BufferedRemoteSttSession implements SttSessionPort {
  _BufferedRemoteSttSession({
    required this.disclosure,
    required this._transport,
    required this.sessionId,
    required this.config,
    required this.language,
    required this.maximumBytes,
  });

  final RemoteSttDisclosure disclosure;
  final RemoteSttTransport _transport;
  final String sessionId;
  final AudioCaptureConfig config;
  final String? language;
  final int maximumBytes;
  final BytesBuilder _audio = BytesBuilder(copy: false);
  bool _closed = false;

  @override
  Stream<TranscriptUpdate> get updates => const Stream.empty();

  @override
  Future<void> push(Uint8List audio) async {
    if (_closed) return;
    if (_audio.length + audio.length > maximumBytes) {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.stt,
          code: 'remote_stt_audio_too_long',
          safeMessage:
              'The recording is too long for remote speech recognition.',
          retryable: true,
        ),
      );
    }
    _audio.add(audio);
  }

  @override
  Future<FinalTranscript> finish() async {
    if (_closed) throw StateError('The STT session is already closed.');
    _closed = true;
    final bytes = _audio.takeBytes();
    if (bytes.isEmpty) {
      throw const VoicePortException(
        VoiceStageFailure(
          stage: VoiceFailureStage.stt,
          code: 'remote_stt_no_audio',
          safeMessage: 'No speech was recorded.',
          retryable: true,
        ),
      );
    }
    return _transport.transcribe(
      disclosure,
      RemoteSttRequest(
        sessionId: sessionId,
        audio: bytes,
        sampleRate: config.sampleRate,
        channels: config.channels,
        language: language,
      ),
    );
  }

  @override
  Future<void> cancel() async {
    _closed = true;
    _audio.takeBytes();
  }
}
