import 'dart:async';
import 'dart:io';

import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/infrastructure/chat/openai_compatible_chat_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enabled = Platform.environment['VOXHANDOFF_LIVE_OPENROUTER'] == '1';
  final apiKey = Platform.environment['OPENROUTER_API_KEY'];
  final model =
      Platform.environment['VOXHANDOFF_LIVE_OPENROUTER_MODEL'] ??
      'inclusionai/ling-3.0-flash:free';
  final configuration = DirectLlmConfiguration(
    id: 'm5-openrouter-smoke',
    origin: Uri.parse('https://openrouter.ai/api/v1'),
    model: model,
  );

  test(
    'live OpenRouter streams ten confirmed-text rounds and accepts cancel',
    () async {
      expect(apiKey, isNotNull, reason: 'OPENROUTER_API_KEY must be supplied');
      final transport = OpenAiCompatibleChatTransport(
        timeout: const Duration(seconds: 60),
      );
      addTearDown(transport.close);

      await transport.test(configuration, apiKey!);
      for (var round = 1; round <= 10; round++) {
        final reply = await transport
            .streamCompletion(
              configuration: configuration,
              apiKey: apiKey,
              messages: [
                _message('m5-round-$round', 'Reply with $round only.'),
              ],
            )
            .join();
        expect(reply.trim(), isNotEmpty, reason: 'round $round had no text');
      }

      final receivedFirstChunk = Completer<void>();
      final subscription = transport
          .streamCompletion(
            configuration: configuration,
            apiKey: apiKey,
            messages: [
              _message(
                'm5-cancel',
                'Write a long numbered list about voice chat reliability.',
              ),
            ],
          )
          .listen(
            (_) {
              if (!receivedFirstChunk.isCompleted) {
                receivedFirstChunk.complete();
              }
            },
            onError: (_, _) {
              if (!receivedFirstChunk.isCompleted) {
                receivedFirstChunk.complete();
              }
            },
          );
      await Future.any<void>([
        receivedFirstChunk.future,
        Future<void>.delayed(const Duration(seconds: 30)),
      ]);
      await transport.cancel();
      await subscription.cancel();
    },
    skip: !enabled
        ? 'Set VOXHANDOFF_LIVE_OPENROUTER=1 to run live smoke.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('offline direct-LLM test remains a safe explicit failure', () async {
    final transport = OpenAiCompatibleChatTransport(
      timeout: const Duration(seconds: 2),
    );
    addTearDown(transport.close);
    await expectLater(
      transport.test(
        DirectLlmConfiguration(
          id: 'offline-fixture',
          origin: Uri.parse('https://127.0.0.1:9'),
          model: 'fixture',
        ),
        'not-a-secret',
      ),
      throwsA(
        isA<DirectChatTransportException>().having(
          (error) => error.code,
          'code',
          'llm_connection_failed',
        ),
      ),
    );
  });
}

DirectChatMessage _message(String id, String text) => DirectChatMessage(
  id: id,
  role: DirectChatRole.user,
  text: text,
  createdAt: DateTime.utc(2026, 7, 31),
);
