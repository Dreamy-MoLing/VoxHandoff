import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/direct_chat.dart';

class DirectChatTransportException implements Exception {
  const DirectChatTransportException(this.code, this.safeMessage);
  final String code;
  final String safeMessage;
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
  HttpClientRequest? _active;
  bool _closed = false;

  @override
  Future<void> test(DirectLlmConfiguration configuration, String apiKey) async {
    _validate(configuration, apiKey);
    try {
      final request = await _client
          .getUrl(configuration.origin.resolve('/v1/models'))
          .timeout(timeout);
      _active = request;
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const DirectChatTransportException(
          'llm_connection_rejected',
          'The LLM API rejected its connection test.',
        );
      }
    } on DirectChatTransportException {
      rethrow;
    } on Object {
      throw const DirectChatTransportException(
        'llm_connection_failed',
        'The LLM API could not be reached securely.',
      );
    } finally {
      _active = null;
    }
  }

  @override
  Stream<String> streamCompletion({
    required DirectLlmConfiguration configuration,
    required String apiKey,
    required List<DirectChatMessage> messages,
  }) async* {
    _validate(configuration, apiKey);
    try {
      final request = await _client
          .postUrl(configuration.origin.resolve('/v1/chat/completions'))
          .timeout(timeout);
      _active = request;
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.add(
        utf8.encode(
          jsonEncode({
            'model': configuration.model,
            'stream': true,
            'messages': [
              if (configuration.systemPrompt.trim().isNotEmpty)
                {
                  'role': 'system',
                  'content': configuration.systemPrompt.trim(),
                },
              for (final message in messages)
                if (message.role != DirectChatRole.system)
                  {'role': message.role.name, 'content': message.text},
            ],
          }),
        ),
      );
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw const DirectChatTransportException(
          'llm_request_rejected',
          'The LLM API rejected the message.',
        );
      }
      var total = 0;
      await for (final line
          in response
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(timeout)) {
        total += line.length;
        if (total > 4 * 1024 * 1024) {
          throw const DirectChatTransportException(
            'llm_stream_too_large',
            'The LLM response exceeded the safe size limit.',
          );
        }
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          return;
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
    } on DirectChatTransportException {
      rethrow;
    } on Object {
      throw const DirectChatTransportException(
        'llm_stream_failed',
        'The LLM response stopped before completion.',
      );
    } finally {
      _active = null;
    }
  }

  @override
  Future<void> cancel() async {
    final request = _active;
    _active = null;
    request?.abort();
  }

  @override
  Future<void> close() async {
    _closed = true;
    await cancel();
    _client.close(force: true);
  }

  void _validate(DirectLlmConfiguration configuration, String apiKey) {
    if (_closed) throw StateError('The LLM transport is closed.');
    if (!configuration.isSafe || apiKey.trim().isEmpty) {
      throw const DirectChatTransportException(
        'llm_configuration_invalid',
        'The LLM configuration is incomplete or unsafe.',
      );
    }
  }
}
