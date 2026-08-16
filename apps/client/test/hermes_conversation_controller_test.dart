import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/hermes_conversation_controller.dart';
import 'package:agent_talk_client/domain/confirmed_draft.dart';
import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/infrastructure/chat/hermes_chat_client.dart';
import 'package:agent_talk_client/infrastructure/chat/hermes_session_client.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/hermes_conversation_secret_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sends one confirmed turn and persists the completed Hermes reply',
    () async {
      final history = _MemoryHistory();
      final secrets = _MemorySecureStore();
      final transport = _FakeTransport();
      final container = ProviderContainer(
        overrides: [
          hermesConversationHistoryStoreProvider.overrideWithValue(history),
          hermesConversationSecretStoreProvider.overrideWithValue(
            HermesConversationSecretStore(secrets),
          ),
          hermesConversationConfigurationStoreProvider.overrideWithValue(
            HermesConversationConfigurationStore(secrets),
          ),
          hermesConversationTransportProvider.overrideWithValue(transport),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(hermesConversationProvider.notifier);
      await controller.configure(_configuration, 'hermes-key');
      final active = container.read(hermesConversationProvider).configuration!;
      final session = container.read(clientSessionProvider.notifier);
      session.editDraft('明确发送一次');
      session.confirmDraft(
        ConfirmedDraft(
          draftId: 'draft-1',
          draftRevision: container.read(clientSessionProvider).draftRevision,
          confirmedText: '明确发送一次',
          assistantId: 'assistant-1',
          assistantRevision: 1,
          contextSnapshotRevision: active.contextSnapshotRevision,
          contextSnapshotHash: active.contextSnapshotHash,
          target: HermesConversationTargetSnapshot(
            conversationId: active.conversationId,
            providerProfileId: active.providerProfileId,
            credentialRevision: active.credentialRevision,
            configurationRevision: active.configurationRevision,
            normalizedOrigin: active.normalizedOrigin,
            model: active.model,
            sessionId: active.sessionId,
            sessionKey: active.sessionKey,
          ),
        ),
      );
      await controller.sendConfirmedText(
        container.read(clientSessionProvider).confirmedDraft!,
      );

      final state = container.read(hermesConversationProvider);
      expect(state.phase, HermesConversationPhase.ready);
      expect(state.messages.map((message) => message.text), [
        '明确发送一次',
        'Hermes reply',
      ]);
      expect(state.messages.last.terminal, DirectMessageTerminal.completed);
      expect(transport.userTexts, ['明确发送一次']);
      expect(history.messages, hasLength(2));
    },
  );
}

final _configuration = HermesConversationConfiguration(
  providerProfileId: 'requested-provider',
  origin: Uri.parse('https://hermes.example.test'),
  model: 'hermes-model',
  conversationId: 'requested-conversation',
  sessionId: 'requested-session',
  sessionKey: 'requested-scope',
  sessionIdPolicy: HermesSessionIdPolicy.generatedStable,
);

class _FakeTransport implements HermesChatTransport {
  final userTexts = <String>[];

  @override
  Future<HermesConnectionReport> test(
    HermesConversationConfiguration configuration,
    String apiKey,
  ) async => HermesConnectionReport(
    capabilitiesAvailable: true,
    probeTerminal: const HermesChatTerminal(
      terminal: DirectMessageTerminal.completed,
      sawDone: true,
    ),
  );

  @override
  Stream<HermesChatStreamEvent> streamCompletion({
    required HermesConversationConfiguration configuration,
    required String apiKey,
    required String userText,
  }) async* {
    userTexts.add(userText);
    yield const HermesChatTextDeltaEvent('Hermes reply');
    yield const HermesChatTerminalEvent(
      HermesChatTerminal(
        terminal: DirectMessageTerminal.completed,
        sawDone: true,
        finishReason: 'stop',
        serverState: HermesServerTerminalState.completed,
      ),
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> close() async {}
}

class _MemoryHistory implements HermesConversationHistoryStore {
  final messages = <DirectChatMessage>[];

  @override
  Future<List<DirectChatMessage>> list(String conversationId) async =>
      List.unmodifiable(messages);

  @override
  Future<void> replace(
    String conversationId,
    List<DirectChatMessage> next,
  ) async {
    messages
      ..clear()
      ..addAll(next);
  }

  @override
  Future<void> upsert(String conversationId, DirectChatMessage message) async {
    final index = messages.indexWhere(
      (candidate) => candidate.id == message.id,
    );
    if (index == -1) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
  }
}

class _MemorySecureStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
