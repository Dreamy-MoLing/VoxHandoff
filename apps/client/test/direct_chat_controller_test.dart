import 'dart:async';
import 'dart:convert';

import 'package:agent_talk_client/application/direct_chat_controller.dart';
import 'package:agent_talk_client/application/chat_source_controller.dart';
import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/speech_playback_controller.dart';
import 'package:agent_talk_client/domain/confirmed_draft.dart';
import 'package:agent_talk_client/domain/client_session.dart';
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
      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('第一条已确认文本');
      draft.confirmDraft(_directDraft(container, '第一条已确认文本'));
      await controller.sendConfirmedText(
        container.read(clientSessionProvider).confirmedDraft!,
      );
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
      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('不要重发');
      draft.confirmDraft(_directDraft(container, '不要重发'));
      final pending = controller.sendConfirmedText(
        container.read(clientSessionProvider).confirmedDraft!,
      );
      await Future<void>.delayed(Duration.zero);
      await controller.cancel();
      await pending;
      expect(
        container.read(directChatProvider).phase,
        DirectChatPhase.cancelled,
      );
      expect(transport.cancelled, isTrue);
      expect(history.messages.last.terminal, DirectMessageTerminal.cancelled);
    },
  );

  test('changing origin cannot auto-bind the previous profile key', () async {
    final history = _History();
    final transport = _Transport(const ['reply']);
    final container = _container(history, transport);
    addTearDown(container.dispose);
    final controller = container.read(directChatProvider.notifier);

    await controller.configure(_config, 'key-for-origin-a');
    await controller.configure(
      _config.copyWith(origin: Uri.parse('https://origin-b.example.test')),
      '',
    );
    final draft = container.read(clientSessionProvider.notifier);
    draft.editDraft('must not use origin A key');
    draft.confirmDraft(_directDraft(container, 'must not use origin A key'));

    await controller.sendConfirmedText(
      container.read(clientSessionProvider).confirmedDraft!,
    );

    expect(transport.apiKeys, isEmpty);
    expect(
      container.read(directChatProvider).failure?.code,
      'llm_key_required_for_new_profile',
    );
  });

  test(
    'changing profile cancels the old request before loading new history',
    () async {
      final history = _History();
      final transport = _BlockingTransport();
      final container = _container(history, transport);
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);
      await controller.configure(_config, 'origin-a-key');
      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('old request');
      draft.confirmDraft(_directDraft(container, 'old request'));
      final pending = controller.sendConfirmedText(
        container.read(clientSessionProvider).confirmedDraft!,
      );
      await Future<void>.delayed(Duration.zero);

      await controller.configure(
        _config.copyWith(origin: Uri.parse('https://origin-b.example.test')),
        'origin-b-key',
      );
      await pending;

      expect(transport.cancelled, isTrue);
      expect(
        history.records.values
            .expand((messages) => messages)
            .singleWhere((message) => message.role == DirectChatRole.assistant)
            .terminal,
        DirectMessageTerminal.cancelled,
      );
      expect(
        container.read(directChatProvider).configuration!.origin.toString(),
        'https://origin-b.example.test',
      );
      expect(container.read(directChatProvider).messages, isEmpty);
    },
  );

  test(
    'source switching cancels Direct work and prevents late deltas',
    () async {
      final history = _History();
      final transport = _BlockingTransport();
      final container = _container(history, transport);
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);
      await controller.configure(_config, 'fixture-key');
      await container
          .read(chatSourceProvider.notifier)
          .select(ChatSource.directLlm);
      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('switch source');
      draft.confirmDraft(_directDraft(container, 'switch source'));
      final pending = controller.sendConfirmedText(
        container.read(clientSessionProvider).confirmedDraft!,
      );
      await Future<void>.delayed(Duration.zero);

      await container
          .read(chatSourceProvider.notifier)
          .select(ChatSource.hermes);
      await pending;

      expect(transport.cancelled, isTrue);
      expect(
        history.records.values
            .expand((messages) => messages)
            .singleWhere((message) => message.role == DirectChatRole.assistant)
            .terminal,
        DirectMessageTerminal.cancelled,
      );
    },
  );

  test(
    'maps empty, partial, and oversized failures to distinct terminals',
    () async {
      for (final fixture in [
        (
          code: 'llm_connection_failed',
          text: '',
          terminal: DirectMessageTerminal.failed,
        ),
        (
          code: 'llm_stream_incomplete',
          text: 'partial',
          terminal: DirectMessageTerminal.incomplete,
        ),
        (
          code: 'llm_stream_too_large',
          text: 'partial',
          terminal: DirectMessageTerminal.truncated,
        ),
      ]) {
        final history = _History();
        final container = _container(
          history,
          _FailingTransport(fixture.code, fixture.text),
        );
        final controller = container.read(directChatProvider.notifier);
        await controller.configure(_config, 'fixture-key');
        final draft = container.read(clientSessionProvider.notifier);
        draft.editDraft('terminal fixture');
        draft.confirmDraft(_directDraft(container, 'terminal fixture'));
        await controller.sendConfirmedText(
          container.read(clientSessionProvider).confirmedDraft!,
        );

        expect(
          history.messages.last.terminal,
          fixture.terminal,
          reason: fixture.code,
        );
        container.dispose();
      }
    },
  );

  test('legacy v1 secret and configuration are never auto-activated', () async {
    final history = _History();
    final transport = _Transport(const ['should-not-run']);
    final store = _Store()
      ..values['${DirectLlmSecretStore.legacyPrefix}fixture-provider'] =
          'legacy-key'
      ..values[DirectLlmConfigurationStore.legacyKey] = jsonEncode({
        'version': 1,
        'id': 'fixture-provider',
        'origin': 'https://legacy.example.test',
        'model': 'legacy-model',
        'system_prompt': '',
      });
    final container = ProviderContainer(
      overrides: [
        directChatHistoryStoreProvider.overrideWithValue(history),
        directChatTransportProvider.overrideWithValue(transport),
        directChatSecretStoreProvider.overrideWithValue(
          DirectLlmSecretStore(store),
        ),
        directChatConfigurationStoreProvider.overrideWithValue(
          DirectLlmConfigurationStore(store),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(directChatProvider.notifier);

    await controller.configure(_config, '');

    expect(container.read(directChatProvider).isConfigured, isFalse);
    expect(transport.apiKeys, isEmpty);
    expect(history.messages, isEmpty);
  });

  test(
    'changing origin opens a new history boundary instead of loading old messages',
    () async {
      final history = _History();
      final transport = _Transport(const ['reply']);
      final container = _container(history, transport);
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);

      await controller.configure(_config, 'key-for-origin-a');
      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('origin A message');
      draft.confirmDraft(_directDraft(container, 'origin A message'));
      await controller.sendConfirmedText(
        container.read(clientSessionProvider).confirmedDraft!,
      );
      draft.startNextDraft();

      await controller.configure(
        _config.copyWith(origin: Uri.parse('https://origin-b.example.test')),
        'key-for-origin-b',
      );

      expect(container.read(directChatProvider).messages, isEmpty);
      expect(history.listedIds, hasLength(2));
      expect(history.listedIds.first, isNot(history.listedIds.last));
    },
  );

  test(
    'changing the direct target invalidates an existing confirmation',
    () async {
      final history = _History();
      final container = _container(history, _Transport(const ['reply']));
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);
      final draft = container.read(clientSessionProvider.notifier);

      await controller.configure(_config, 'key-for-origin-a');
      draft.editDraft('target-bound text');
      draft.confirmDraft(_directDraft(container, 'target-bound text'));
      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.confirmed,
      );

      await controller.configure(
        _config.copyWith(origin: Uri.parse('https://origin-b.example.test')),
        'key-for-origin-b',
      );

      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.editing,
      );
      expect(container.read(clientSessionProvider).confirmedDraft, isNull);
    },
  );

  test(
    'keeps provider, credential, configuration, conversation, and assistant revisions distinct',
    () async {
      final history = _History();
      final store = _Store();
      final container = ProviderContainer(
        overrides: [
          directChatHistoryStoreProvider.overrideWithValue(history),
          directChatTransportProvider.overrideWithValue(_Transport(const [])),
          directChatSecretStoreProvider.overrideWithValue(
            DirectLlmSecretStore(store),
          ),
          directChatConfigurationStoreProvider.overrideWithValue(
            DirectLlmConfigurationStore(store),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(directChatProvider.notifier);

      await controller.configure(_config, 'key-a');
      final first = container.read(directChatProvider).configuration!;
      await controller.configure(_config, 'key-b');
      final rotated = container.read(directChatProvider).configuration!;
      expect(rotated.providerProfileId, first.providerProfileId);
      expect(rotated.credentialRevision, first.credentialRevision + 1);
      expect(rotated.configurationRevision, first.configurationRevision);
      expect(rotated.conversationId, first.conversationId);

      await controller.configure(
        _config.copyWith(model: 'new-model', systemPrompt: 'Be concise.'),
        '',
      );
      final changed = container.read(directChatProvider).configuration!;
      expect(changed.providerProfileId, first.providerProfileId);
      expect(changed.credentialRevision, rotated.credentialRevision);
      expect(changed.configurationRevision, rotated.configurationRevision + 1);
      expect(changed.conversationId, isNot(rotated.conversationId));
      expect(changed.assistantId, first.assistantId);
      expect(changed.assistantRevision, first.assistantRevision + 1);
      expect(container.read(directChatProvider).messages, isEmpty);
      expect(
        store.values.keys.where((key) => key.contains('direct-llm-key')),
        hasLength(1),
      );
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

ConfirmedDraft _directDraft(ProviderContainer container, String text) {
  final configuration = container.read(directChatProvider).configuration!;
  final session = container.read(clientSessionProvider);
  return ConfirmedDraft(
    draftId: 'draft-${text.hashCode}',
    draftRevision: session.draftRevision,
    confirmedText: text,
    assistantId: configuration.assistantId,
    assistantRevision: configuration.assistantRevision,
    contextSnapshotRevision: configuration.contextSnapshotRevision,
    contextSnapshotHash: configuration.contextSnapshotHash,
    target: DirectTargetSnapshot(
      conversationId: configuration.conversationId,
      providerProfileId: configuration.profileId,
      credentialRevision: configuration.credentialRevision,
      configurationRevision: configuration.configurationRevision,
      normalizedOrigin: normalizedProviderOrigin(configuration.origin),
      model: configuration.model,
    ),
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
  final records = <String, List<DirectChatMessage>>{};
  final listedIds = <String>[];
  List<DirectChatMessage> get messages =>
      records.values.expand((messages) => messages).toList(growable: false);
  @override
  Future<List<DirectChatMessage>> list(String providerId) async {
    listedIds.add(providerId);
    return List.of(records[providerId] ?? const []);
  }

  @override
  Future<void> upsert(String providerId, DirectChatMessage message) async {
    final messages = records.putIfAbsent(providerId, () => []);
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
  final apiKeys = <String>[];
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
    apiKeys.add(apiKey);
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
    unawaited(_controller.close());
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

class _FailingTransport implements DirectChatTransport {
  _FailingTransport(this.code, this.partial);

  final String code;
  final String partial;

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
    if (partial.isNotEmpty) yield partial;
    throw DirectChatTransportException(code, 'fixture failure');
  }

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
