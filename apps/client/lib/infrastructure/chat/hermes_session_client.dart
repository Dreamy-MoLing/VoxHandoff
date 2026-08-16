import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/direct_chat.dart';
import '../../domain/hermes_conversation.dart';
import 'hermes_chat_client.dart';
import 'openai_compatible_chat_client.dart';

class HermesSessionBootstrap {
  const HermesSessionBootstrap({required this.sessionId});
  final String sessionId;
}

class HermesSessionRestore {
  const HermesSessionRestore({
    required this.effectiveSessionId,
    required this.messages,
  });

  final String effectiveSessionId;
  final List<DirectChatMessage> messages;
}

/// Durable-session operations are kept separate from the streaming client so
/// a connection check or history restore cannot abort an active chat request.
class HermesSessionClient {
  HermesSessionClient({
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;
  bool _closed = false;

  Future<HermesSessionBootstrap> bootstrap(
    HermesConversationConfiguration configuration,
    String apiKey,
  ) async {
    _validate(configuration, apiKey);
    HttpClientRequest? request;
    try {
      request = await _client
          .postUrl(
            hermesConversationEndpoint(configuration, const [
              'api',
              'sessions',
            ]),
          )
          .timeout(timeout);
      _prepareRequest(request, apiKey, configuration.sessionKey);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'model': configuration.model})));
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _discard(response);
        throw _statusError(
          response.statusCode,
          retryAfter: response.headers.value('retry-after'),
        );
      }
      final payload = await _readJson(response);
      final sessionId = _readSessionId(payload);
      if (sessionId == null) {
        throw const HermesChatTransportException(
          'hermes_session_bootstrap_invalid',
          'Hermes did not return a usable session ID.',
          stage: HermesChatFailureStage.protocol,
        );
      }
      return HermesSessionBootstrap(sessionId: sessionId);
    } on HermesChatTransportException {
      rethrow;
    } on TimeoutException {
      throw const HermesChatTransportException(
        'hermes_session_bootstrap_timeout',
        'Hermes did not create a session in time.',
        stage: HermesChatFailureStage.connection,
      );
    } on FormatException {
      throw const HermesChatTransportException(
        'hermes_session_bootstrap_invalid',
        'Hermes returned an invalid session response.',
        stage: HermesChatFailureStage.protocol,
      );
    } on Object {
      throw const HermesChatTransportException(
        'hermes_session_bootstrap_failed',
        'Hermes could not create a conversation session.',
        stage: HermesChatFailureStage.connection,
      );
    }
  }

  Future<HermesSessionRestore> restore(
    HermesConversationConfiguration configuration,
    String apiKey,
  ) async {
    _validate(configuration, apiKey);
    HttpClientRequest? request;
    try {
      request = await _client
          .getUrl(
            hermesConversationEndpoint(configuration, const [
              'api',
              'sessions',
              // The endpoint builder validates path segments, while this
              // argument is kept explicit to make the session binding clear.
              // The actual ID is appended below.
            ]).replace(
              pathSegments: [
                ...configuration.origin.pathSegments,
                'api',
                'sessions',
                configuration.sessionId,
                'messages',
              ],
            ),
          )
          .timeout(timeout);
      _prepareRequest(request, apiKey, configuration.sessionKey);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _discard(response);
        throw _statusError(
          response.statusCode,
          retryAfter: response.headers.value('retry-after'),
        );
      }
      final payload = await _readJson(response);
      final effectiveSessionId =
          _readSessionId(payload) ?? configuration.sessionId;
      final messages = _readMessages(payload, effectiveSessionId);
      return HermesSessionRestore(
        effectiveSessionId: effectiveSessionId,
        messages: messages,
      );
    } on HermesChatTransportException {
      rethrow;
    } on TimeoutException {
      throw const HermesChatTransportException(
        'hermes_session_restore_timeout',
        'Hermes did not restore this conversation in time.',
        stage: HermesChatFailureStage.connection,
      );
    } on FormatException {
      throw const HermesChatTransportException(
        'hermes_session_restore_invalid',
        'Hermes returned an invalid conversation history.',
        stage: HermesChatFailureStage.protocol,
      );
    } on Object {
      throw const HermesChatTransportException(
        'hermes_session_restore_failed',
        'Hermes could not restore this conversation.',
        stage: HermesChatFailureStage.connection,
      );
    }
  }

  void _prepareRequest(
    HttpClientRequest request,
    String apiKey,
    String sessionKey,
  ) {
    request.followRedirects = false;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.headers.set('X-Hermes-Session-Key', sessionKey);
  }

  Future<Map<String, Object?>> _readJson(HttpClientResponse response) async {
    final bytes = await response
        .transform(const ResponseByteLimitTransformer(_maximumSessionBytes))
        .fold<List<int>>(<int>[], (all, chunk) => [...all, ...chunk])
        .timeout(timeout);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is List) return <String, Object?>{'messages': decoded};
    if (decoded is! Map) throw const FormatException('Expected a JSON object.');
    return <String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
  }

  Future<void> _discard(HttpClientResponse response) async {
    try {
      await response
          .transform(const ResponseByteLimitTransformer(_maximumSessionBytes))
          .timeout(timeout)
          .drain<void>();
    } on DirectChatTransportException {
      throw HermesChatTransportException(
        'hermes_session_response_too_large',
        'The Hermes session response exceeded the safe size limit.',
        stage: HermesChatFailureStage.protocol,
        statusCode: response.statusCode,
      );
    }
  }

  HermesChatTransportException _statusError(
    int statusCode, {
    String? retryAfter,
  }) {
    final (code, message) = switch (statusCode) {
      HttpStatus.unauthorized => (
        'hermes_auth_required',
        'Hermes rejected the API key.',
      ),
      HttpStatus.forbidden => (
        'hermes_forbidden',
        'Hermes refused this profile or session request.',
      ),
      HttpStatus.notFound => (
        'hermes_not_found',
        'The Hermes endpoint or session was not found.',
      ),
      HttpStatus.tooManyRequests => (
        'hermes_rate_limited',
        'Hermes is rate limiting requests.',
      ),
      HttpStatus.badGateway => (
        'hermes_bad_gateway',
        'Hermes reported an upstream gateway failure.',
      ),
      HttpStatus.serviceUnavailable => (
        'hermes_unavailable',
        'Hermes is temporarily unavailable.',
      ),
      _ => ('hermes_request_rejected', 'Hermes rejected the request.'),
    };
    final seconds = int.tryParse(retryAfter ?? '');
    return HermesChatTransportException(
      code,
      message,
      statusCode: statusCode,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  String? _readSessionId(Map<String, Object?> payload) {
    final direct = _safeSessionId(
      _string(payload['effective_session_id']) ??
          _string(payload['resolved_session_id']) ??
          _string(payload['session_id']) ??
          _string(payload['id']),
    );
    if (direct != null) return direct;
    final session = payload['session'];
    if (session is Map) {
      return _safeSessionId(
        _string(session['effective_session_id']) ??
            _string(session['resolved_session_id']) ??
            _string(session['session_id']) ??
            _string(session['id']),
      );
    }
    return null;
  }

  List<DirectChatMessage> _readMessages(
    Map<String, Object?> payload,
    String sessionId,
  ) {
    final raw = payload['messages'] ?? payload['data'];
    if (raw is! List) return const [];
    final messages = <DirectChatMessage>[];
    for (var index = 0; index < raw.length; index++) {
      final value = raw[index];
      if (value is! Map) continue;
      final roleValue = _string(value['role'])?.toLowerCase();
      final role = switch (roleValue) {
        'system' => DirectChatRole.system,
        'user' => DirectChatRole.user,
        'assistant' => DirectChatRole.assistant,
        _ => null,
      };
      final text = _messageText(value['content'] ?? value['text']);
      if (role == null || text == null) continue;
      final id =
          _string(value['id']) ??
          _string(value['message_id']) ??
          'hermes-$sessionId-$index';
      final createdAt =
          _createdAt(value['created_at'] ?? value['timestamp']) ??
          DateTime.utc(1970, 1, 1).add(Duration(microseconds: index));
      final terminal = _messageTerminal(value);
      messages.add(
        DirectChatMessage(
          id: id,
          role: role,
          text: text,
          createdAt: createdAt,
          terminal: terminal,
          provenance: DirectMessageProvenance.native,
        ),
      );
    }
    return List.unmodifiable(messages);
  }

  String? _messageText(Object? raw) {
    if (raw is String) return raw;
    if (raw is List) {
      final parts = <String>[];
      for (final item in raw) {
        if (item is String) {
          parts.add(item);
        } else if (item is Map) {
          final text = _string(item['text']) ?? _string(item['content']);
          if (text != null) parts.add(text);
        }
      }
      return parts.isEmpty ? null : parts.join();
    }
    return null;
  }

  DirectMessageTerminal _messageTerminal(Map value) {
    final valueName = _string(value['terminal'])?.toLowerCase();
    if (valueName != null) {
      for (final candidate in DirectMessageTerminal.values) {
        if (candidate.name == valueName &&
            candidate != DirectMessageTerminal.streaming) {
          return candidate;
        }
      }
    }
    if (value['partial'] == true || value['incomplete'] == true) {
      return DirectMessageTerminal.incomplete;
    }
    if (value['failed'] == true || value['error'] != null) {
      return DirectMessageTerminal.failed;
    }
    return DirectMessageTerminal.completed;
  }

  DateTime? _createdAt(Object? raw) {
    if (raw is String) return DateTime.tryParse(raw)?.toUtc();
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true);
    }
    return null;
  }

  void _validate(HermesConversationConfiguration configuration, String apiKey) {
    if (_closed || !configuration.isSafe || apiKey.trim().isEmpty) {
      throw const HermesChatTransportException(
        'hermes_configuration_invalid',
        'The Hermes configuration is incomplete or unsafe.',
        stage: HermesChatFailureStage.configuration,
      );
    }
  }

  Future<void> close() async {
    _closed = true;
    _client.close(force: true);
  }
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

String? _safeSessionId(String? value) {
  if (value == null ||
      value.length > 256 ||
      !RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value)) {
    return null;
  }
  return value;
}

const _maximumSessionBytes = 1024 * 1024;

abstract interface class HermesConversationHistoryStore {
  Future<List<DirectChatMessage>> list(String conversationId);
  Future<void> replace(String conversationId, List<DirectChatMessage> messages);
  Future<void> upsert(String conversationId, DirectChatMessage message);
}
