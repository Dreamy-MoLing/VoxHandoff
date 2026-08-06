import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/infrastructure/chat/openai_compatible_chat_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('root OpenAI-compatible base receives the v1 prefix', () {
    final endpoint = openAiCompatibleEndpoint(
      _configuration('https://llm.example.test'),
      const ['chat', 'completions'],
    );
    expect(endpoint.toString(), 'https://llm.example.test/v1/chat/completions');
  });

  test('OpenRouter api/v1 base keeps its explicit prefix', () {
    final endpoint = openAiCompatibleEndpoint(
      _configuration('https://openrouter.ai/api/v1'),
      const ['models'],
    );
    expect(endpoint.toString(), 'https://openrouter.ai/api/v1/models');
  });

  test('configuration rejects unsafe API base path components', () {
    expect(_configuration('https://llm.example.test/api/v1').isSafe, isTrue);
    expect(
      _configuration('https://llm.example.test/api/%2F/v1').isSafe,
      isFalse,
    );
    expect(
      _configuration('https://llm.example.test/api/v1?next=x').isSafe,
      isFalse,
    );
    expect(
      _configuration('https://user@llm.example.test/api/v1').isSafe,
      isFalse,
    );
  });

  test(
    'endpoint builder does not accept a caller-controlled traversal path',
    () {
      expect(
        () => openAiCompatibleEndpoint(
          _configuration('https://llm.example.test'),
          const ['..'],
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'caps continuous no-newline bytes before decoding or line buffering',
    () async {
      final controller = StreamController<List<int>>();
      final values = controller.stream
          .transform(const ResponseByteLimitTransformer(8))
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      final result = values.toList();
      controller
        ..add(utf8.encode('data: '))
        ..add(utf8.encode('abcdefghi'))
        ..close();

      await expectLater(
        result,
        throwsA(
          isA<DirectChatTransportException>().having(
            (error) => error.code,
            'code',
            'llm_stream_too_large',
          ),
        ),
      );
    },
  );

  test('caps a single oversized SSE line by wire bytes', () async {
    final oversizedLine = utf8.encode('data: ${'x' * 32}\n\n');
    await expectLater(
      Stream<List<int>>.value(oversizedLine)
          .transform(const ResponseByteLimitTransformer(16))
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList(),
      throwsA(
        isA<DirectChatTransportException>().having(
          (error) => error.code,
          'code',
          'llm_stream_too_large',
        ),
      ),
    );
  });

  test('preserves normal fragmented SSE bytes', () async {
    final values =
        await Stream<List<int>>.fromIterable([
              utf8.encode('data: {"choices":[{"delta":{"content":"hel'),
              utf8.encode('lo"}}]}\n\n'),
            ])
            .transform(const ResponseByteLimitTransformer(1024))
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .toList();
    expect(values, ['data: {"choices":[{"delta":{"content":"hello"}}]}', '']);
  });

  test('allows cancellation without retaining later chunks', () async {
    final controller = StreamController<List<int>>();
    final subscription = controller.stream
        .transform(const ResponseByteLimitTransformer(1024))
        .listen((_) {});
    controller.add(utf8.encode('data: partial'));
    await subscription.cancel();
    expect(() => controller.add(utf8.encode('data: ignored')), returnsNormally);
    await controller.close();
  });

  test('does not suppress timeout after byte limiting', () async {
    final source = StreamController<List<int>>();
    final closeTimer = Timer(const Duration(milliseconds: 100), source.close);
    try {
      await expectLater(
        source.stream
            .transform(const ResponseByteLimitTransformer(1024))
            .timeout(const Duration(milliseconds: 1))
            .toList(),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      closeTimer.cancel();
      await source.close();
    }
  });

  test(
    'bounds and redacts an oversized non-2xx /models response on loopback',
    () async {
      final fixture = _OversizedNon2xxFixture(
        expectedPath: '/v1/models',
        statusCode: HttpStatus.serviceUnavailable,
      );
      await fixture.start();
      addTearDown(fixture.close);
      final transport = OpenAiCompatibleChatTransport(
        timeout: const Duration(seconds: 2),
      );
      addTearDown(transport.close);

      await expectLater(
        transport.test(_loopbackConfiguration(fixture), 'fixture-key'),
        throwsA(
          isA<DirectChatTransportException>()
              .having(
                (error) => error.code,
                'stable code',
                'llm_stream_too_large',
              )
              .having(
                (error) => error.stage,
                'stage',
                DirectChatFailureStage.protocol,
              )
              .having((error) => error.statusCode, 'status', 503)
              .having(
                (error) => error.safeMessage,
                'safe message',
                'The LLM response exceeded the safe size limit.',
              )
              .having(
                (error) => error.safeMessage,
                'upstream body redaction',
                isNot(contains(_OversizedNon2xxFixture.upstreamSentinel)),
              ),
        ),
      );
      await fixture.finished;

      expect(fixture.method, 'GET');
      expect(fixture.path, '/v1/models');
      expect(fixture.statusCode, 503);
      expect(
        fixture.bodyBytesWritten,
        lessThanOrEqualTo(
          _OversizedNon2xxFixture.maximumBodyBytes +
              _OversizedNon2xxFixture.chunkSize,
        ),
      );
    },
  );

  test(
    'bounds an oversized non-2xx chat response and keeps failure text safe',
    () async {
      final fixture = _OversizedNon2xxFixture(
        expectedPath: '/v1/chat/completions',
        statusCode: HttpStatus.badGateway,
      );
      await fixture.start();
      addTearDown(fixture.close);
      final transport = OpenAiCompatibleChatTransport(
        timeout: const Duration(seconds: 2),
      );
      addTearDown(transport.close);

      await expectLater(
        transport
            .streamCompletion(
              configuration: _loopbackConfiguration(fixture),
              apiKey: 'fixture-key',
              messages: [
                DirectChatMessage(
                  id: 'message-1',
                  role: DirectChatRole.user,
                  text: 'hello',
                  createdAt: DateTime.utc(2026, 8, 2),
                ),
              ],
            )
            .toList(),
        throwsA(
          isA<DirectChatTransportException>()
              .having(
                (error) => error.code,
                'stable code',
                'llm_stream_too_large',
              )
              .having(
                (error) => error.stage,
                'stage',
                DirectChatFailureStage.protocol,
              )
              .having((error) => error.statusCode, 'status', 502)
              .having(
                (error) => error.safeMessage,
                'safe message',
                'The LLM response exceeded the safe size limit.',
              )
              .having(
                (error) => error.safeMessage,
                'upstream body redaction',
                isNot(contains(_OversizedNon2xxFixture.upstreamSentinel)),
              ),
        ),
      );
      await fixture.finished;

      expect(fixture.method, 'POST');
      expect(fixture.path, '/v1/chat/completions');
      expect(fixture.statusCode, 502);
      expect(
        fixture.bodyBytesWritten,
        lessThanOrEqualTo(
          _OversizedNon2xxFixture.maximumBodyBytes +
              _OversizedNon2xxFixture.chunkSize,
        ),
      );
    },
  );
}

DirectLlmConfiguration _configuration(String value) => DirectLlmConfiguration(
  id: 'fixture',
  origin: Uri.parse(value),
  model: 'fixture-model',
);

DirectLlmConfiguration _loopbackConfiguration(
  _OversizedNon2xxFixture fixture,
) => _LoopbackHttpConfiguration(Uri.parse('http://127.0.0.1:${fixture.port}'));

class _LoopbackHttpConfiguration extends DirectLlmConfiguration {
  const _LoopbackHttpConfiguration(Uri origin)
    : super(id: 'loopback-fixture', origin: origin, model: 'fixture-model');

  // Production Direct profiles remain HTTPS-only. This test-only override
  // lets the transport exercise a real loopback HTTP server in isolation.
  @override
  bool get isSafe => true;
}

class _OversizedNon2xxFixture {
  _OversizedNon2xxFixture({
    required this.expectedPath,
    required this.statusCode,
  });

  static const maximumBodyBytes = 4 * 1024 * 1024;
  static const chunkSize = 64 * 1024;
  static const extraChunks = 8;
  static const upstreamSentinel = 'fixture-upstream-body-must-not-surface';

  final String expectedPath;
  final int statusCode;
  final _finished = Completer<void>();
  late final HttpServer _server;
  String? method;
  String? receivedPath;
  var bodyBytesWritten = 0;

  int get port => _server.port;
  int get totalBodyBytes => maximumBodyBytes + extraChunks * chunkSize;
  String? get path => receivedPath;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server.forEach(_serve));
  }

  Future<void> _serve(HttpRequest request) async {
    method = request.method;
    receivedPath = request.uri.path;
    if (receivedPath != expectedPath) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      if (!_finished.isCompleted) _finished.complete();
      return;
    }
    final response = request.response;
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.text;
    final chunksToWrite = maximumBodyBytes ~/ chunkSize + 1;
    response.headers.contentLength = chunksToWrite * chunkSize;
    final chunk = List<int>.filled(chunkSize, 0x78);
    final firstChunk = utf8.encode(upstreamSentinel);
    for (var index = 0; index < firstChunk.length; index++) {
      chunk[index] = firstChunk[index];
    }
    try {
      // Write only up to one chunk past the client's bounded limit, then end
      // the response on our side. Do not depend on the client closing the
      // connection to stop the loop: a client that merely stops reading can
      // block flush() once the socket buffer fills.
      for (var index = 0; index < chunksToWrite; index++) {
        response.add(chunk);
        bodyBytesWritten += chunk.length;
        await response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await response.close();
    } on Object {
      // The client is expected to close the response after the bounded reader
      // observes the first byte beyond the limit.
      try {
        await response.close();
      } on Object {
        // Ignore the expected peer-close error in this fixture.
      }
    } finally {
      if (!_finished.isCompleted) _finished.complete();
    }
  }

  Future<void> get finished => _finished.future.timeout(
    const Duration(seconds: 2),
    onTimeout: () => throw TimeoutException('loopback fixture did not finish'),
  );

  Future<void> close() async {
    await _server.close(force: true);
    if (!_finished.isCompleted) _finished.complete();
  }
}
