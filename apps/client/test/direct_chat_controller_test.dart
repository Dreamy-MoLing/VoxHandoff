import 'dart:async';

import 'package:agent_talk_client/application/direct_chat_controller.dart';
import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/speech_playback_controller.dart';
import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/infrastructure/chat/openai_compatible_chat_client.dart';
import 'package:agent_talk_client/infrastructure/security/direct_llm_secret_store.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'confirmed text streams to direct LLM and persists complete local reply',
    () async {
      final history = _History();
      final transport = _Transport(['你好', '，世界。']);
      final container = _container(history, transport);
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);
      await controller.configure(_config, 'not-logged-key');
      container.read(clientSessionProvider.notifier).editDraft('第一条已确认文本');
      container.read(clientSessionProvider.notifier).confirmDraft();
      await controller.sendConfirmedText('第一条已确认文本');
      final state = container.read(directChatProvider);
      expect(state.phase, DirectChatPhase.ready);
      expect(state.messages.map((message) => message.text), [
        '第一条已确认文本',
        '你好，世界。',
      ]);
      expect(history.messages, hasLength(2));
      expect(transport.messages.single.last.text, '第一条已确认文本');
    },
  );

  test(
    'cancelling direct generation preserves the partial local reply',
    () async {
      final history = _History();
      final transport = _BlockingTransport();
      final container = _container(history, transport);
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);
      await controller.configure(_config, 'not-logged-key');
      container.read(clientSessionProvider.notifier).editDraft('不要重发');
      container.read(clientSessionProvider.notifier).confirmDraft();
      final pending = controller.sendConfirmedText('不要重发');
      await Future<void>.delayed(Duration.zero);
      await controller.cancel();
      await pending;
      expect(
        container.read(directChatProvider).phase,
        DirectChatPhase.cancelled,
      );
      expect(transport.cancelled, isTrue);
      expect(history.messages.last.completed, isTrue);
    },
  );
}

final _config = DirectLlmConfiguration(
  id: 'fixture-provider',
  origin: Uri.parse('https://llm.example.test'),
  model: 'fixture-model',
);

ProviderContainer _container(_History history, DirectChatTransport transport) {
  final store = _Store();
  return ProviderContainer(
    overrides: [
      directChatHistoryStoreProvider.overrideWithValue(history),
      directChatTransportProvider.overrideWithValue(transport),
      directChatSecretStoreProvider.overrideWithValue(
        DirectLlmSecretStore(store),
      ),
      directChatConfigurationStoreProvider.overrideWithValue(
        DirectLlmConfigurationStore(store),
      ),
      speechEnabledProvider.overrideWithValue(false),
      audioPlaybackPortProvider.overrideWithValue(_Playback()),
    ],
  );
}

class _Store implements SecureValueStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _History implements DirectChatHistoryStore {
  final messages = <DirectChatMessage>[];
  @override
  Future<List<DirectChatMessage>> list(String providerId) async =>
      List.of(messages);
  @override
  Future<void> upsert(String providerId, DirectChatMessage message) async {
    final index = messages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (index < 0) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
  }
}

class _Transport implements DirectChatTransport {
  _Transport(this.chunks);
  final List<String> chunks;
  final messages = <List<DirectChatMessage>>[];
  @override
  Future<void> cancel() async {}
  @override
  Future<void> close() async {}
  @override
  Stream<String> streamCompletion({
    required DirectLlmConfiguration configuration,
    required String apiKey,
    required List<DirectChatMessage> messages,
  }) async* {
    this.messages.add(messages);
    yield* Stream.fromIterable(chunks);
  }

  @override
  Future<void> test(
    DirectLlmConfiguration configuration,
    String apiKey,
  ) async {}
}

class _BlockingTransport implements DirectChatTransport {
  bool cancelled = false;
  final _controller = StreamController<String>();
  @override
  Future<void> cancel() async {
    cancelled = true;
    await _controller.close();
  }

  @override
  Future<void> close() => cancel();
  @override
  Stream<String> streamCompletion({
    required DirectLlmConfiguration configuration,
    required String apiKey,
    required List<DirectChatMessage> messages,
  }) => _controller.stream;
  @override
  Future<void> test(
    DirectLlmConfiguration configuration,
    String apiKey,
  ) async {}
}

class _Playback implements AudioPlaybackPort {
  @override
  Stream<double> get levels => const Stream.empty();
  @override
  Future<void> close() async {}
  @override
  Future<void> play(SynthesizedSpeech speech) async {}
  @override
  Future<void> stopSpeech() async {}
}
