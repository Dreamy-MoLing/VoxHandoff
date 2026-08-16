import 'dart:io';

import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/infrastructure/chat/hermes_chat_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses role/content, tool progress, keepalive, finish and DONE', () {
    final events = parseHermesSseLines([
      ': keepalive',
      'event: message',
      'data: {"choices":[{"delta":{"role":"assistant"}}]}',
      '',
      'data: {"choices":[{"delta":{"content":"你好"}}]}',
      '',
      'event: hermes.tool.progress',
      'data: {"tool":"memory","message":"reading"}',
      '',
      'data: {"choices":[{"delta":{},"finish_reason":"stop"}],"completed":true}',
      '',
      'data: [DONE]',
    ]);

    expect(events.whereType<HermesChatRoleEvent>().single.role, 'assistant');
    expect(events.whereType<HermesChatTextDeltaEvent>().single.text, '你好');
    expect(
      events.whereType<HermesToolProgressEvent>().single.message,
      'reading',
    );
    final terminal = events
        .whereType<HermesChatTerminalEvent>()
        .single
        .terminal;
    expect(terminal.terminal, DirectMessageTerminal.completed);
    expect(terminal.sawDone, isTrue);
    expect(terminal.finishReason, 'stop');
  });

  test('HTTP 200 without finish and DONE is incomplete, not success', () {
    final events = parseHermesSseLines([
      'data: {"choices":[{"delta":{"content":"partial"}}]}',
    ]);
    final terminal = events
        .whereType<HermesChatTerminalEvent>()
        .single
        .terminal;
    expect(terminal.terminal, DirectMessageTerminal.incomplete);
    expect(terminal.sawDone, isFalse);
  });

  test('partial and failed Hermes fields are classified separately', () {
    final partial = parseHermesSseLines([
      'data: {"status":"partial","choices":[{"delta":{"content":"x"},"finish_reason":"stop"}]}',
      'data: [DONE]',
    ]).whereType<HermesChatTerminalEvent>().single.terminal;
    final failed = parseHermesSseLines([
      'event: error',
      'data: {"error":{"code":"provider_failed"}}',
      'data: [DONE]',
    ]).whereType<HermesChatTerminalEvent>().single.terminal;

    expect(partial.terminal, DirectMessageTerminal.incomplete);
    expect(failed.terminal, DirectMessageTerminal.failed);
  });

  test(
    'classifies authentication, profile, rate and service failures',
    () async {
      final fixture = _StatusFixture();
      await fixture.start();
      addTearDown(fixture.close);
      final transport = HermesChatHttpTransport(
        timeout: const Duration(seconds: 2),
      );
      addTearDown(transport.close);

      for (final entry in <int, String>{
        401: 'hermes_auth_required',
        403: 'hermes_forbidden',
        404: 'hermes_not_found',
        429: 'hermes_rate_limited',
        502: 'hermes_bad_gateway',
        503: 'hermes_unavailable',
      }.entries) {
        fixture.status = entry.key;
        await expectLater(
          transport
              .streamCompletion(
                configuration: _loopbackConfiguration(fixture),
                apiKey: 'fixture-key',
                userText: 'hello',
              )
              .toList(),
          throwsA(
            isA<HermesChatTransportException>()
                .having((error) => error.code, 'code', entry.value)
                .having((error) => error.statusCode, 'status', entry.key),
          ),
        );
      }
    },
  );
}

HermesConversationConfiguration _loopbackConfiguration(
  _StatusFixture fixture,
) =>
    _LoopbackHermesConfiguration(Uri.parse('http://127.0.0.1:${fixture.port}'));

class _LoopbackHermesConfiguration extends HermesConversationConfiguration {
  const _LoopbackHermesConfiguration(Uri origin)
    : super(
        providerProfileId: 'fixture-provider',
        origin: origin,
        model: 'fixture-model',
        conversationId: 'fixture-conversation',
        sessionId: 'fixture-session',
        sessionKey: 'fixture-scope',
      );

  @override
  bool get isSafe => true;
}

class _StatusFixture {
  late HttpServer _server;
  var status = 503;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      request.response.statusCode = status;
      await request.response.close();
    });
  }

  Future<void> close() => _server.close(force: true);
}
