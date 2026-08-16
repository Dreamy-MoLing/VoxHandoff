import 'dart:convert';
import 'dart:io';

import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/infrastructure/chat/hermes_session_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'bootstraps and restores a session without replaying client history',
    () async {
      final fixture = _SessionFixture();
      await fixture.start();
      addTearDown(fixture.close);
      final client = HermesSessionClient(timeout: const Duration(seconds: 2));
      addTearDown(client.close);
      final configuration = _configuration(fixture);

      final bootstrap = await client.bootstrap(configuration, 'fixture-key');
      expect(bootstrap.sessionId, 'server-session');
      expect(fixture.bootstrapPath, '/api/sessions');
      expect(fixture.authorization, 'Bearer fixture-key');
      expect(fixture.sessionKey, configuration.sessionKey);

      final restored = await client.restore(configuration, 'fixture-key');
      expect(restored.effectiveSessionId, 'resolved-session');
      expect(restored.messages, hasLength(2));
      expect(restored.messages[0].role, DirectChatRole.user);
      expect(restored.messages[0].text, 'server user');
      expect(restored.messages[1].terminal, DirectMessageTerminal.completed);
      expect(fixture.restorePath, '/api/sessions/client-session/messages');
    },
  );
}

_LoopbackHermesConfiguration _configuration(_SessionFixture fixture) =>
    _LoopbackHermesConfiguration(Uri.parse('http://127.0.0.1:${fixture.port}'));

class _LoopbackHermesConfiguration extends HermesConversationConfiguration {
  const _LoopbackHermesConfiguration(Uri origin)
    : super(
        providerProfileId: 'fixture-provider',
        origin: origin,
        model: 'fixture-model',
        conversationId: 'fixture-conversation',
        sessionId: 'client-session',
        sessionKey: 'fixture-scope',
      );

  @override
  bool get isSafe => true;
}

class _SessionFixture {
  late HttpServer _server;
  String? bootstrapPath;
  String? restorePath;
  String? authorization;
  String? sessionKey;

  int get port => _server.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    authorization = request.headers.value(HttpHeaders.authorizationHeader);
    sessionKey = request.headers.value('X-Hermes-Session-Key');
    if (request.method == 'POST') {
      bootstrapPath = request.uri.path;
      await request.drain<void>();
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'session': {'id': 'server-session'},
        }),
      );
      await request.response.close();
      return;
    }
    restorePath = request.uri.path;
    await request.drain<void>();
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'resolved_session_id': 'resolved-session',
        'messages': [
          {
            'id': 'm-user',
            'role': 'user',
            'content': 'server user',
            'created_at': '2026-08-16T00:00:00Z',
          },
          {
            'id': 'm-assistant',
            'role': 'assistant',
            'content': 'server reply',
            'terminal': 'completed',
            'created_at': '2026-08-16T00:00:01Z',
          },
        ],
      }),
    );
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}
