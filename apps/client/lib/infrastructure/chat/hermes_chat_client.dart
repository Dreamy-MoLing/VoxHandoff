import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../domain/direct_chat.dart';
import '../../domain/hermes_conversation.dart';
import 'openai_compatible_chat_client.dart';

enum HermesChatFailureStage { configuration, connection, protocol, terminal }

class HermesChatTransportException implements Exception {
  const HermesChatTransportException(
    this.code,
    this.safeMessage, {
    this.stage = HermesChatFailureStage.connection,
    this.statusCode,
    this.retryAfter,
  });

  final String code;
  final String safeMessage;
  final HermesChatFailureStage stage;
  final int? statusCode;
  final Duration? retryAfter;

  @override
  String toString() =>
      'HermesChatTransportException(stage: ${stage.name}, code: $code, '
      'statusCode: ${statusCode ?? 'none'})';
}

enum HermesServerTerminalState { completed, partial, failed }

class HermesChatTerminal {
  const HermesChatTerminal({
    required this.terminal,
    required this.sawDone,
    this.finishReason,
    this.serverState,
    this.errorCode,
    this.effectiveSessionId,
  });

  final DirectMessageTerminal terminal;
  final bool sawDone;
  final String? finishReason;
  final HermesServerTerminalState? serverState;
  final String? errorCode;
  final String? effectiveSessionId;

  HermesChatTerminal withTextLength(int textLength) {
    if (textLength > 0 || terminal == DirectMessageTerminal.completed) {
      return this;
    }
    if (terminal == DirectMessageTerminal.incomplete ||
        terminal == DirectMessageTerminal.truncated) {
      return HermesChatTerminal(
        terminal: DirectMessageTerminal.failed,
        sawDone: sawDone,
        finishReason: finishReason,
        serverState: serverState,
        errorCode: errorCode ?? 'hermes_empty_response',
        effectiveSessionId: effectiveSessionId,
      );
    }
    return this;
  }
}

sealed class HermesChatStreamEvent {
  const HermesChatStreamEvent();
}

class HermesChatRoleEvent extends HermesChatStreamEvent {
  const HermesChatRoleEvent(this.role);
  final String role;
}

class HermesChatTextDeltaEvent extends HermesChatStreamEvent {
  const HermesChatTextDeltaEvent(this.text);
  final String text;
}

/// Tool progress is deliberately a separate event. It must never be appended
/// to assistant text or sent to the TTS queue.
class HermesToolProgressEvent extends HermesChatStreamEvent {
  const HermesToolProgressEvent({
    required this.eventName,
    required this.message,
  });
  final String eventName;
  final String message;
}

class HermesChatTerminalEvent extends HermesChatStreamEvent {
  const HermesChatTerminalEvent(this.terminal);
  final HermesChatTerminal terminal;
}

class HermesConnectionReport {
  const HermesConnectionReport({
    this.version,
    required this.capabilitiesAvailable,
    required this.probeTerminal,
  });

  final String? version;
  final bool capabilitiesAvailable;
  final HermesChatTerminal probeTerminal;
}

/// Small SSE state machine for Hermes' OpenAI-compatible stream.
///
/// It accepts role chunks, content deltas, named tool progress events, finish
/// chunks, comments and the `[DONE]` marker. HTTP 200 is intentionally not a
/// terminal success signal; [finish] requires both a valid terminal field and
/// the explicit DONE marker.
class HermesSseParser {
  String? _eventName;
  String? _finishReason;
  HermesServerTerminalState? _serverState;
  bool _sawDone = false;
  String? _errorCode;
  String? _effectiveSessionId;

  Iterable<HermesChatStreamEvent> addLine(String line) sync* {
    if (line.startsWith(':')) return;
    if (line.startsWith('event:')) {
      _eventName = line.substring('event:'.length).trim();
      return;
    }
    if (line.isEmpty) {
      _eventName = null;
      return;
    }
    if (!line.startsWith('data:')) return;
    final data = line.substring('data:'.length).trim();
    if (data.isEmpty) return;
    if (data == '[DONE]') {
      _sawDone = true;
      _eventName = null;
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(data);
    } on Object {
      return;
    }
    if (decoded is! Map) return;
    final payload = <String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
    final eventName = _eventName ?? _string(payload['event']);
    _inspectTerminal(payload);
    if (eventName == 'hermes.tool.progress' ||
        eventName == 'tool.progress' ||
        eventName == 'tool.started' ||
        eventName == 'tool.completed' ||
        eventName == 'tool.failed') {
      yield HermesToolProgressEvent(
        eventName: eventName!,
        message: _progressMessage(payload, eventName),
      );
      _eventName = null;
      return;
    }
    if (eventName == 'error' || payload['error'] is Map) {
      _errorCode = 'hermes_stream_error';
      _serverState = HermesServerTerminalState.failed;
      _eventName = null;
      return;
    }
    final choices = payload['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      _eventName = null;
      return;
    }
    final choice = <String, Object?>{
      for (final entry in (choices.first as Map).entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
    final finishReason = _string(choice['finish_reason']);
    if (finishReason != null) _finishReason = finishReason;
    final delta = choice['delta'];
    if (delta is! Map) {
      _eventName = null;
      return;
    }
    final role = _string(delta['role']);
    if (role != null) yield HermesChatRoleEvent(role);
    final content = delta['content'];
    if (content is String && content.isNotEmpty) {
      yield HermesChatTextDeltaEvent(content);
    }
    _eventName = null;
  }

  HermesChatTerminal finish() {
    final reason = _finishReason?.toLowerCase();
    final terminal = switch (reason) {
      'error' || 'failed' => DirectMessageTerminal.failed,
      'cancel' || 'cancelled' => DirectMessageTerminal.cancelled,
      'length' ||
      'max_tokens' ||
      'content_filter' => DirectMessageTerminal.truncated,
      _ when _serverState == HermesServerTerminalState.failed =>
        DirectMessageTerminal.failed,
      _ when !_sawDone => DirectMessageTerminal.incomplete,
      _ when _serverState == HermesServerTerminalState.partial =>
        DirectMessageTerminal.incomplete,
      _ when _serverState == HermesServerTerminalState.completed =>
        DirectMessageTerminal.completed,
      'stop' ||
      'tool_calls' ||
      'function_call' => DirectMessageTerminal.completed,
      _ => DirectMessageTerminal.incomplete,
    };
    return HermesChatTerminal(
      terminal: terminal,
      sawDone: _sawDone,
      finishReason: _finishReason,
      serverState: _serverState,
      errorCode: _errorCode,
      effectiveSessionId: _effectiveSessionId,
    );
  }

  void _inspectTerminal(Map<String, Object?> payload) {
    final hermes = payload['hermes'];
    final hermesMap = hermes is Map
        ? <String, Object?>{
            for (final entry in hermes.entries)
              if (entry.key is String) entry.key! as String: entry.value,
          }
        : const <String, Object?>{};
    final status =
        (_string(payload['status']) ??
                _string(payload['completion_status']) ??
                _string(hermesMap['status']) ??
                _string(hermesMap['completion_status']))
            ?.toLowerCase();
    if (status == 'completed' || status == 'complete' || status == 'success') {
      _serverState = HermesServerTerminalState.completed;
    } else if (status == 'partial' || status == 'incomplete') {
      _serverState = HermesServerTerminalState.partial;
    } else if (status == 'failed' || status == 'error') {
      _serverState = HermesServerTerminalState.failed;
    }
    if (_bool(payload['completed']) == true ||
        _bool(hermesMap['completed']) == true) {
      _serverState = HermesServerTerminalState.completed;
    }
    if (_bool(payload['partial']) == true ||
        _bool(hermesMap['partial']) == true) {
      _serverState = HermesServerTerminalState.partial;
    }
    if (_bool(payload['failed']) == true ||
        _bool(hermesMap['failed']) == true) {
      _serverState = HermesServerTerminalState.failed;
    }
    final topLevelFinish = _string(payload['finish_reason']);
    if (topLevelFinish != null) _finishReason = topLevelFinish;
    final effectiveSessionId =
        _string(payload['effective_session_id']) ??
        _string(payload['resolved_session_id']) ??
        _string(payload['session_id']);
    if (effectiveSessionId != null &&
        _isSessionPathSegment(effectiveSessionId)) {
      _effectiveSessionId = effectiveSessionId;
    }
  }
}

List<HermesChatStreamEvent> parseHermesSseLines(Iterable<String> lines) {
  final parser = HermesSseParser();
  final events = <HermesChatStreamEvent>[];
  for (final line in lines) {
    events.addAll(parser.addLine(line));
  }
  events.add(HermesChatTerminalEvent(parser.finish()));
  return List.unmodifiable(events);
}

abstract interface class HermesChatTransport {
  Future<HermesConnectionReport> test(
    HermesConversationConfiguration configuration,
    String apiKey,
  );

  Stream<HermesChatStreamEvent> streamCompletion({
    required HermesConversationConfiguration configuration,
    required String apiKey,
    required String userText,
  });

  Future<void> cancel();
  Future<void> close();
}

class HermesChatHttpTransport implements HermesChatTransport {
  HermesChatHttpTransport({
    HttpClient? client,
    this.timeout = const Duration(seconds: 45),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;
  HttpClientRequest? _activeChatRequest;
  HttpClientRequest? _activeProbeRequest;
  HttpClientRequest? _activeTestRequest;
  bool _closed = false;

  @override
  Future<HermesConnectionReport> test(
    HermesConversationConfiguration configuration,
    String apiKey,
  ) async {
    _validate(configuration, apiKey, userText: 'connection test');
    Map<String, Object?> health;
    Map<String, Object?> capabilities;
    try {
      health = await _getJson(
        hermesConversationEndpoint(configuration, const ['health']),
        apiKey,
      );
      capabilities = await _getJson(
        hermesConversationEndpoint(configuration, const ['v1', 'capabilities']),
        apiKey,
      );
    } finally {
      _activeTestRequest = null;
    }
    final probeEvents = await _stream(
      configuration: configuration,
      apiKey: apiKey,
      userText: 'Reply with exactly: ready',
      sessionId: _opaqueId('probe-session'),
      sessionKey: _opaqueId('probe-scope'),
      probe: true,
    ).toList();
    final terminal = probeEvents
        .whereType<HermesChatTerminalEvent>()
        .fold<HermesChatTerminalEvent?>(null, (last, event) => event);
    if (terminal == null ||
        terminal.terminal.terminal != DirectMessageTerminal.completed) {
      throw HermesChatTransportException(
        'hermes_connection_probe_failed',
        'Hermes accepted the connection but the read-only probe did not complete.',
        stage: HermesChatFailureStage.terminal,
      );
    }
    final version =
        _string(health['version']) ??
        _string(health['hermes_version']) ??
        _string(capabilities['version']);
    return HermesConnectionReport(
      version: version,
      capabilitiesAvailable: true,
      probeTerminal: terminal.terminal,
    );
  }

  @override
  Stream<HermesChatStreamEvent> streamCompletion({
    required HermesConversationConfiguration configuration,
    required String apiKey,
    required String userText,
  }) => _stream(
    configuration: configuration,
    apiKey: apiKey,
    userText: userText,
    sessionId: configuration.sessionId,
    sessionKey: configuration.sessionKey,
    probe: false,
  );

  Stream<HermesChatStreamEvent> _stream({
    required HermesConversationConfiguration configuration,
    required String apiKey,
    required String userText,
    required String sessionId,
    required String sessionKey,
    required bool probe,
  }) async* {
    _validate(configuration, apiKey, userText: userText);
    final body = utf8.encode(
      jsonEncode({
        'model': configuration.model,
        'stream': true,
        'messages': [
          {'role': 'user', 'content': userText.trim()},
        ],
      }),
    );
    if (body.length > _maximumRequestBytes) {
      throw const HermesChatTransportException(
        'hermes_request_too_large',
        'The Hermes request exceeded the safe size limit.',
        stage: HermesChatFailureStage.protocol,
      );
    }
    HttpClientRequest? request;
    try {
      request = await _client
          .postUrl(
            hermesConversationEndpoint(configuration, const [
              'v1',
              'chat',
              'completions',
            ]),
          )
          .timeout(timeout);
      if (probe) {
        _activeProbeRequest = request;
      } else {
        _activeChatRequest = request;
      }
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set('X-Hermes-Session-Id', sessionId);
      request.headers.set('X-Hermes-Session-Key', sessionKey);
      request.add(body);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _discardResponse(response);
        throw _classifyStatus(
          response.statusCode,
          retryAfter: response.headers.value('retry-after'),
        );
      }
      final parser = HermesSseParser();
      var textLength = 0;
      await for (final line
          in response
              .transform(
                const ResponseByteLimitTransformer(_maximumResponseBytes),
              )
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(timeout)) {
        for (final event in parser.addLine(line)) {
          if (event case HermesChatTextDeltaEvent(:final text)) {
            textLength += text.length;
          }
          yield event;
        }
      }
      final terminal = parser.finish().withTextLength(textLength);
      yield HermesChatTerminalEvent(terminal);
    } on HermesChatTransportException {
      rethrow;
    } on DirectChatTransportException catch (error) {
      throw _fromBoundedError(error);
    } on TimeoutException {
      throw const HermesChatTransportException(
        'hermes_stream_timeout',
        'The Hermes response timed out before completion.',
        stage: HermesChatFailureStage.connection,
      );
    } on Object {
      throw const HermesChatTransportException(
        'hermes_stream_failed',
        'The Hermes response stopped before completion.',
        stage: HermesChatFailureStage.connection,
      );
    } finally {
      if (probe && identical(_activeProbeRequest, request)) {
        _activeProbeRequest = null;
      }
      if (!probe && identical(_activeChatRequest, request)) {
        _activeChatRequest = null;
      }
    }
  }

  Future<Map<String, Object?>> _getJson(Uri endpoint, String apiKey) async {
    HttpClientRequest? request;
    try {
      request = await _client.getUrl(endpoint).timeout(timeout);
      _activeTestRequest = request;
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _discardResponse(response);
        throw _classifyStatus(
          response.statusCode,
          retryAfter: response.headers.value('retry-after'),
        );
      }
      final bytes = await response
          .transform(const ResponseByteLimitTransformer(_maximumProbeBytes))
          .fold<List<int>>(<int>[], (all, chunk) => [...all, ...chunk])
          .timeout(timeout);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        return const <String, Object?>{};
      }
      return <String, Object?>{
        for (final entry in decoded.entries)
          if (entry.key is String) entry.key! as String: entry.value,
      };
    } on HermesChatTransportException {
      rethrow;
    } on DirectChatTransportException catch (error) {
      throw _fromBoundedError(error);
    } on TimeoutException {
      throw const HermesChatTransportException(
        'hermes_connection_timeout',
        'Hermes did not answer its connection check in time.',
        stage: HermesChatFailureStage.connection,
      );
    } on FormatException {
      throw const HermesChatTransportException(
        'hermes_invalid_response',
        'Hermes returned an invalid connection-check response.',
        stage: HermesChatFailureStage.protocol,
      );
    } on Object {
      throw const HermesChatTransportException(
        'hermes_connection_failed',
        'Hermes could not be reached securely.',
        stage: HermesChatFailureStage.connection,
      );
    } finally {
      if (identical(_activeTestRequest, request)) _activeTestRequest = null;
    }
  }

  Future<void> _discardResponse(HttpClientResponse response) async {
    try {
      await response
          .transform(const ResponseByteLimitTransformer(_maximumResponseBytes))
          .timeout(timeout)
          .drain<void>();
    } on DirectChatTransportException catch (error) {
      throw _fromBoundedError(error, statusCode: response.statusCode);
    }
  }

  HermesChatTransportException _classifyStatus(
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

  HermesChatTransportException _fromBoundedError(
    DirectChatTransportException error, {
    int? statusCode,
  }) => HermesChatTransportException(
    error.code == 'llm_stream_too_large'
        ? 'hermes_stream_too_large'
        : 'hermes_response_invalid',
    error.code == 'llm_stream_too_large'
        ? 'The Hermes response exceeded the safe size limit.'
        : 'The Hermes response could not be read safely.',
    stage: HermesChatFailureStage.protocol,
    statusCode: statusCode ?? error.statusCode,
  );

  void _validate(
    HermesConversationConfiguration configuration,
    String apiKey, {
    required String userText,
  }) {
    if (_closed ||
        !configuration.isSafe ||
        apiKey.trim().isEmpty ||
        userText.trim().isEmpty ||
        userText.length > 256 * 1024) {
      throw const HermesChatTransportException(
        'hermes_configuration_invalid',
        'The Hermes configuration or message is incomplete or unsafe.',
        stage: HermesChatFailureStage.configuration,
      );
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
    _activeProbeRequest?.abort();
    _activeProbeRequest = null;
    _activeTestRequest?.abort();
    _activeTestRequest = null;
    _client.close(force: true);
  }
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

bool _isSessionPathSegment(String value) =>
    value.length <= 256 && RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value);

bool? _bool(Object? value) => value is bool ? value : null;

String _progressMessage(Map<String, Object?> payload, String eventName) {
  final value =
      _string(payload['message']) ??
      _string(payload['status']) ??
      _string(payload['tool']) ??
      _string(payload['name']);
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return eventName;
  }
  return normalized.length <= 512 ? normalized : normalized.substring(0, 512);
}

String _opaqueId(String prefix) =>
    '$prefix-${List<int>.generate(16, (_) => Random.secure().nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';

const _maximumRequestBytes = 1 * 1024 * 1024;
const _maximumResponseBytes = 4 * 1024 * 1024;
const _maximumProbeBytes = 256 * 1024;
