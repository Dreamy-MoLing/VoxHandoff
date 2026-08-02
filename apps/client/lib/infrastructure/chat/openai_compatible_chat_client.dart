import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/direct_chat.dart';

/// Builds a versioned OpenAI-compatible endpoint without accepting a
/// per-request URL.  A root base gains `/v1`; a versioned base (such as
/// `https://openrouter.ai/api/v1`) keeps its explicit prefix.
Uri openAiCompatibleEndpoint(
  DirectLlmConfiguration configuration,
  List<String> resource,
) {
  if (!configuration.isSafe ||
      resource.isEmpty ||
      resource.any(
        (segment) =>
            segment.isEmpty ||
            !RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(segment) ||
            segment == '.' ||
            segment == '..',
      )) {
    throw ArgumentError.value(
      configuration,
      'configuration',
      'Unsafe API base',
    );
  }
  final base = configuration.origin.pathSegments;
  final suffix = base.isNotEmpty && base.last == 'v1'
      ? resource
      : <String>['v1', ...resource];
  return configuration.origin.replace(pathSegments: [...base, ...suffix]);
}

class DirectChatTransportException implements Exception {
  const DirectChatTransportException(
    this.code,
    this.safeMessage, {
    this.stage = DirectChatFailureStage.connection,
    this.statusCode,
  });

  final String code;
  final String safeMessage;
  final DirectChatFailureStage stage;
  final int? statusCode;

  @override
  String toString() =>
      'DirectChatTransportException(stage: ${stage.name}, code: $code, '
      'statusCode: ${statusCode ?? 'none'})';
}

abstract interface class DirectChatTransport {
  Future<void> test(DirectLlmConfiguration configuration, String apiKey);
  Stream<String> streamCompletion({
    required DirectLlmConfiguration configuration,
    required String apiKey,
    required List<DirectChatMessage> messages,
  });
  Future<void> cancel();
  Future<void> close();
}

/// Minimal Chat Completions client. It intentionally accepts only the stable
/// `choices[].delta.content` SSE shape and never surfaces upstream bodies.
class OpenAiCompatibleChatTransport implements DirectChatTransport {
  OpenAiCompatibleChatTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;
  HttpClientRequest? _activeChatRequest;
  HttpClientRequest? _activeTestRequest;
  bool _closed = false;

  @override
  Future<void> test(DirectLlmConfiguration configuration, String apiKey) async {
    _validate(configuration, apiKey);
    HttpClientRequest? request;
    try {
      request = await _client
          .getUrl(openAiCompatibleEndpoint(configuration, const ['models']))
          .timeout(timeout);
      _activeTestRequest = request;
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      final response = await request.close().timeout(timeout);
      await _discardResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DirectChatTransportException(
          'llm_connection_rejected',
          'The LLM API rejected its connection test.',
          stage: DirectChatFailureStage.connection,
          statusCode: response.statusCode,
        );
      }
    } on DirectChatTransportException {
      rethrow;
    } on Object {
      throw const DirectChatTransportException(
        'llm_connection_failed',
        'The LLM API could not be reached securely.',
        stage: DirectChatFailureStage.connection,
      );
    } finally {
      if (identical(_activeTestRequest, request)) {
        _activeTestRequest = null;
      }
    }
  }

  @override
  Stream<String> streamCompletion({
    required DirectLlmConfiguration configuration,
    required String apiKey,
    required List<DirectChatMessage> messages,
  }) async* {
    _validate(configuration, apiKey);
    final body = utf8.encode(
      jsonEncode({
        'model': configuration.model,
        'stream': true,
        'messages': [
          if (configuration.systemPrompt.trim().isNotEmpty &&
              !messages.any((message) => message.role == DirectChatRole.system))
            {'role': 'system', 'content': configuration.systemPrompt.trim()},
          for (final message in messages)
            {'role': message.role.name, 'content': message.text},
        ],
      }),
    );
    if (body.length > _maximumRequestBytes) {
      throw const DirectChatTransportException(
        'llm_request_too_large',
        'The LLM request exceeded the safe size limit.',
        stage: DirectChatFailureStage.protocol,
      );
    }
    HttpClientRequest? request;
    try {
      request = await _client
          .postUrl(
            openAiCompatibleEndpoint(configuration, const [
              'chat',
              'completions',
            ]),
          )
          .timeout(timeout);
      _activeChatRequest = request;
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.add(body);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _discardResponse(response);
        throw DirectChatTransportException(
          'llm_request_rejected',
          'The LLM API rejected the message.',
          stage: DirectChatFailureStage.connection,
          statusCode: response.statusCode,
        );
      }
      var sawDone = false;
      await for (final line
          in response
              .transform(ResponseByteLimitTransformer(_maximumResponseBytes))
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(timeout)) {
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          sawDone = true;
          break;
        }
        Object? decoded;
        try {
          decoded = jsonDecode(data);
        } on Object {
          continue;
        }
        if (decoded is! Map<String, Object?>) continue;
        final choices = decoded['choices'];
        if (choices is! List ||
            choices.isEmpty ||
            choices.first is! Map<String, Object?>) {
          continue;
        }
        final delta = (choices.first as Map<String, Object?>)['delta'];
        final content = delta is Map<String, Object?> ? delta['content'] : null;
        if (content is String && content.isNotEmpty) yield content;
      }
      if (!sawDone) {
        throw const DirectChatTransportException(
          'llm_stream_incomplete',
          'The LLM response ended before its completion marker.',
          stage: DirectChatFailureStage.protocol,
        );
      }
    } on DirectChatTransportException {
      rethrow;
    } on TimeoutException {
      throw const DirectChatTransportException(
        'llm_stream_timeout',
        'The LLM response timed out before completion.',
        stage: DirectChatFailureStage.connection,
      );
    } on Object {
      throw const DirectChatTransportException(
        'llm_stream_failed',
        'The LLM response stopped before completion.',
        stage: DirectChatFailureStage.connection,
      );
    } finally {
      if (identical(_activeChatRequest, request)) {
        _activeChatRequest = null;
      }
    }
  }

  @override
  Future<void> cancel() async {
    final request = _activeChatRequest;
    _activeChatRequest = null;
    request?.abort();
  }

  @override
  Future<void> close() async {
    _closed = true;
    await cancel();
    _activeTestRequest?.abort();
    _activeTestRequest = null;
    _client.close(force: true);
  }

  Future<void> _discardResponse(HttpClientResponse response) async {
    try {
      await response
          .transform(const ResponseByteLimitTransformer(_maximumResponseBytes))
          .timeout(timeout)
          .drain<void>();
    } on DirectChatTransportException catch (error) {
      throw DirectChatTransportException(
        error.code,
        error.safeMessage,
        stage: error.stage,
        statusCode: response.statusCode,
      );
    }
  }

  void _validate(DirectLlmConfiguration configuration, String apiKey) {
    if (_closed) throw StateError('The LLM transport is closed.');
    if (!configuration.isSafe || apiKey.trim().isEmpty) {
      throw const DirectChatTransportException(
        'llm_configuration_invalid',
        'The LLM configuration is incomplete or unsafe.',
        stage: DirectChatFailureStage.configuration,
      );
    }
  }
}

const _maximumResponseBytes = 4 * 1024 * 1024;
const _maximumRequestBytes = 1 * 1024 * 1024;

/// Counts wire bytes before UTF-8 decoding or line buffering.  This keeps a
/// peer from making [LineSplitter] retain an unbounded no-newline response.
class ResponseByteLimitTransformer
    extends StreamTransformerBase<List<int>, List<int>> {
  const ResponseByteLimitTransformer(this.maximumBytes);

  final int maximumBytes;

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    var total = 0;
    await for (final chunk in stream) {
      total += chunk.length;
      if (total > maximumBytes) {
        throw const DirectChatTransportException(
          'llm_stream_too_large',
          'The LLM response exceeded the safe size limit.',
          stage: DirectChatFailureStage.protocol,
        );
      }
      yield chunk;
    }
  }
}
