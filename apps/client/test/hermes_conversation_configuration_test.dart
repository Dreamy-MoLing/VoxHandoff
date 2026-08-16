import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/hermes_conversation_secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts an HTTPS Hermes origin with an optional profile prefix', () {
    final configuration = _configuration('https://hermes.example.test/p/work');

    expect(configuration.isSafe, isTrue);
    expect(configuration.profileName, 'work');
    expect(
      hermesConversationEndpoint(configuration, const [
        'v1',
        'capabilities',
      ]).toString(),
      'https://hermes.example.test/p/work/v1/capabilities',
    );
  });

  test('rejects query, fragment, credentials, and unapproved paths', () {
    expect(_configuration('http://hermes.example.test').isSafe, isFalse);
    expect(_configuration('https://user@hermes.example.test').isSafe, isFalse);
    expect(
      _configuration('https://hermes.example.test/p/work?x=1').isSafe,
      isFalse,
    );
    expect(
      _configuration('https://hermes.example.test/p/work#fragment').isSafe,
      isFalse,
    );
    expect(
      _configuration('https://hermes.example.test/api/v1').isSafe,
      isFalse,
    );
  });

  test('configuration round-trips without an API key', () {
    final store = _MemorySecureValueStore();
    final configurationStore = HermesConversationConfigurationStore(store);
    final configuration = _configuration('https://hermes.example.test');

    return configurationStore.save(configuration).then((_) async {
      final restored = await configurationStore.read();
      expect(restored, configuration);
      expect(store.values.values.join(), isNot(contains('api-key')));
    });
  });

  test(
    'Hermes API key uses a namespace independent from Direct and STT',
    () async {
      final store = _MemorySecureValueStore();
      final secrets = HermesConversationSecretStore(store);

      await secrets.save('provider-1', ' hermes-secret ');

      expect(await secrets.read('provider-1'), 'hermes-secret');
      expect(
        store.values.keys.single,
        startsWith(HermesConversationSecretStore.prefix),
      );
      expect(store.values.keys.single, isNot(contains('direct-llm')));
      expect(store.values.values.single, 'hermes-secret');
    },
  );
}

HermesConversationConfiguration _configuration(String origin) =>
    HermesConversationConfiguration(
      providerProfileId: 'provider-1',
      origin: Uri.parse(origin),
      model: 'hermes-model',
      conversationId: 'conversation-1',
      sessionId: 'session-1',
      sessionKey: 'memory-1',
    );

class _MemorySecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
