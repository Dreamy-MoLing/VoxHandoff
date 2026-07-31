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
}

DirectLlmConfiguration _configuration(String value) => DirectLlmConfiguration(
  id: 'fixture',
  origin: Uri.parse(value),
  model: 'fixture-model',
);
