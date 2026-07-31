import 'dart:async';
import 'dart:convert';

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
}

DirectLlmConfiguration _configuration(String value) => DirectLlmConfiguration(
  id: 'fixture',
  origin: Uri.parse(value),
  model: 'fixture-model',
);
