import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/speech.dart';
import '../../domain/voice.dart';

class GptSoVitsConfig {
  GptSoVitsConfig({
    required this.baseUri,
    required this.referenceAudioPath,
    required this.promptText,
    this.textLanguage = 'zh',
    this.promptLanguage = 'zh',
    this.timeout = const Duration(seconds: 30),
  }) {
    final loopbackHttp = baseUri.scheme == 'http' && _isLoopback(baseUri.host);
    if (!loopbackHttp ||
        baseUri.host.isEmpty ||
        baseUri.userInfo.isNotEmpty ||
        (baseUri.path.isNotEmpty && baseUri.path != '/') ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        referenceAudioPath.isEmpty) {
      throw const FormatException('The GPT-SoVITS configuration is unsafe.');
    }
  }

  final Uri baseUri;
  final String referenceAudioPath;
  final String promptText;
  final String textLanguage;
  final String promptLanguage;
  final Duration timeout;
}

class GptSoVitsTtsPort implements TtsPort {
  GptSoVitsTtsPort({required this.config, HttpClient? client})
    : _client = client ?? HttpClient();

  final GptSoVitsConfig config;
  final HttpClient _client;
  final Set<HttpClientRequest> _activeRequests = {};
  int _generation = 0;
  bool _closed = false;

  @override
  Future<void> warmUp() async {
    final segment = SpeechSegment(
      conversationId: 'tts-warmup',
      requestId: 'tts-warmup',
      messageRevision: BigInt.one,
      index: 0,
      text: '语音已准备。',
    );
    await synthesize(segment);
  }

  @override
  Future<SynthesizedSpeech> synthesize(SpeechSegment segment) async {
    if (_closed) throw StateError('The TTS adapter is closed.');
    final generation = _generation;
    final stopwatch = Stopwatch()..start();
    HttpClientRequest? activeRequest;
    try {
      final endpoint = config.baseUri.resolve('/tts');
      final request = await _client.postUrl(endpoint).timeout(config.timeout);
      activeRequest = request;
      _activeRequests.add(request);
      if (generation != _generation) {
        request.abort();
        throw const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.tts,
            code: 'tts_cancelled',
            safeMessage: 'Speech synthesis was cancelled.',
            retryable: true,
          ),
        );
      }
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.add(
        utf8.encode(
          jsonEncode({
            'text': segment.text,
            'text_lang': config.textLanguage,
            'ref_audio_path': config.referenceAudioPath,
            'prompt_text': config.promptText,
            'prompt_lang': config.promptLanguage,
            'media_type': 'wav',
            'streaming_mode': false,
          }),
        ),
      );
      final response = await request.close().timeout(config.timeout);
      if (generation != _generation) {
        throw const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.tts,
            code: 'tts_cancelled',
            safeMessage: 'Speech synthesis was cancelled.',
            retryable: true,
          ),
        );
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw const HttpException('GPT-SoVITS rejected synthesis.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(config.timeout)) {
        if (generation != _generation) {
          throw const VoicePortException(
            VoiceStageFailure(
              stage: VoiceFailureStage.tts,
              code: 'tts_cancelled',
              safeMessage: 'Speech synthesis was cancelled.',
              retryable: true,
            ),
          );
        }
        if (builder.length + chunk.length > 16 * 1024 * 1024) {
          throw const HttpException('GPT-SoVITS response exceeded limit.');
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.length < 44) {
        throw const HttpException('GPT-SoVITS returned invalid audio.');
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
          code: 'gpt_sovits_synthesis_failed',
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
      request.abort(
        const VoicePortException(
          VoiceStageFailure(
            stage: VoiceFailureStage.tts,
            code: 'tts_cancelled',
            safeMessage: 'Speech synthesis was cancelled.',
            retryable: true,
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await cancel();
    _client.close(force: true);
  }
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}
