import 'package:agent_talk_client/application/hermes_conversation_controller.dart';
import 'package:agent_talk_client/application/manual_connection_controller.dart';
import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/infrastructure/chat/hermes_chat_client.dart';
import 'package:agent_talk_client/infrastructure/chat/hermes_session_client.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/flutter_secure_value_store.dart';
import 'package:agent_talk_client/infrastructure/security/hermes_conversation_secret_store.dart';
import 'package:agent_talk_client/infrastructure/security/server_fingerprint_probe.dart';
import 'package:agent_talk_client/infrastructure/security/tofu_trust_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManualConnectionController 裸 TOFU', () {
    test('未知指纹必须显式接受：探测成功后进入 awaitingTofu，不自动信任', () async {
      final probe = _ScriptedProbe(['sha256:first']);
      final trustStore = _memoryStore();
      final container = _container(probe, trustStore);

      final controller = container.read(manualConnectionProvider.notifier);
      await controller.connectHermes(
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        apiKey: 'secret-key',
      );

      final state = container.read(manualConnectionProvider);
      expect(state.phase, ManualConnectionPhase.awaitingTofu);
      expect(state.fingerprint, 'sha256:first');
      expect(await trustStore.records(), isEmpty, reason: '未接受前不得信任');
    });

    test('已信任的指纹直接完成连接，不打断用户', () async {
      final probe = _ScriptedProbe(['sha256:known']);
      final trustStore = _memoryStore();
      await trustStore.record(
        Uri.parse('https://hermes.example.test'),
        'sha256:known',
      );
      final container = _container(probe, trustStore);

      final controller = container.read(manualConnectionProvider.notifier);
      await controller.connectHermes(
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        apiKey: 'secret-key',
      );

      final state = container.read(manualConnectionProvider);
      expect(state.phase, ManualConnectionPhase.connected);
      expect(container.read(hermesConversationProvider).isConfigured, isTrue);
    });

    test('接受前重新探测：指纹变化则 fail closed，不信任、不保存', () async {
      final probe = _ScriptedProbe(['sha256:then', 'sha256:changed']);
      final trustStore = _memoryStore();
      final container = _container(probe, trustStore);

      final controller = container.read(manualConnectionProvider.notifier);
      await controller.connectHermes(
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        apiKey: 'secret-key',
      );
      await controller.acceptTofu();

      final state = container.read(manualConnectionProvider);
      expect(state.phase, ManualConnectionPhase.failed);
      expect(state.failureCode, 'tofu_fingerprint_changed');
      expect(await trustStore.records(), isEmpty);
      expect(container.read(hermesConversationProvider).isConfigured, isFalse);
    });

    test('接受且指纹稳定：记录信任并保存配置', () async {
      final probe = _ScriptedProbe(['sha256:stable', 'sha256:stable']);
      final trustStore = _memoryStore();
      final container = _container(probe, trustStore);

      final controller = container.read(manualConnectionProvider.notifier);
      await controller.connectHermes(
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        apiKey: 'secret-key',
      );
      await controller.acceptTofu();

      final state = container.read(manualConnectionProvider);
      expect(state.phase, ManualConnectionPhase.connected);
      final records = await trustStore.records();
      expect(records, hasLength(1));
      expect(records.first.origin, 'https://hermes.example.test:443');
      expect(records.first.fingerprint, 'sha256:stable');
      expect(
        container.read(hermesConversationProvider).configuration!.model,
        'hermes-model',
      );
    });

    test('取消不读取环境、不保留任何信任或配置', () async {
      final probe = _ScriptedProbe(['sha256:pending']);
      final trustStore = _memoryStore();
      final container = _container(probe, trustStore);

      final controller = container.read(manualConnectionProvider.notifier);
      await controller.connectHermes(
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        apiKey: 'secret-key',
      );
      controller.cancelTofu();

      final state = container.read(manualConnectionProvider);
      expect(state.phase, ManualConnectionPhase.cancelled);
      expect(await trustStore.records(), isEmpty);
    });

    test('探测失败进入 failed，原配置不变', () async {
      const probe = _FailingProbe(
        FingerprintProbeException('probe_unreachable', '无法连接'),
      );
      final trustStore = _memoryStore();
      final container = _container(probe, trustStore);

      final controller = container.read(manualConnectionProvider.notifier);
      await controller.connectHermes(
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        apiKey: 'secret-key',
      );

      final state = container.read(manualConnectionProvider);
      expect(state.phase, ManualConnectionPhase.failed);
      expect(state.failureCode, 'probe_unreachable');
      expect(await trustStore.records(), isEmpty);
    });
  });
}

ProviderContainer _container(
  FingerprintProbe probe,
  TofuTrustStore trustStore,
) {
  final memory = _MemorySecureStore();
  final container = ProviderContainer(
    overrides: [
      fingerprintProbeProvider.overrideWithValue(probe),
      tofuTrustStoreProvider.overrideWithValue(trustStore),
      hermesConversationHistoryStoreProvider.overrideWithValue(
        _MemoryHistory(),
      ),
      hermesConversationSecretStoreProvider.overrideWithValue(
        HermesConversationSecretStore(memory),
      ),
      hermesConversationConfigurationStoreProvider.overrideWithValue(
        HermesConversationConfigurationStore(memory),
      ),
      hermesConversationTransportProvider.overrideWithValue(_FakeTransport()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

SecureTofuTrustStore _memoryStore() =>
    SecureTofuTrustStore(_MemorySecureStore());

class _ScriptedProbe implements FingerprintProbe {
  _ScriptedProbe(this.fingerprints);

  final List<String> fingerprints;
  var index = 0;

  @override
  Future<String> probe(Uri serverOrigin) async {
    if (index >= fingerprints.length) {
      throw const FingerprintProbeException('probe_no_more', '脚本用尽');
    }
    return fingerprints[index++];
  }
}

class _FailingProbe implements FingerprintProbe {
  const _FailingProbe(this.error);

  final FingerprintProbeException error;

  @override
  Future<String> probe(Uri serverOrigin) async => throw error;
}

class _MemoryHistory implements HermesConversationHistoryStore {
  @override
  Future<List<DirectChatMessage>> list(String conversationId) async => [];

  @override
  Future<void> replace(
    String conversationId,
    List<DirectChatMessage> next,
  ) async {}

  @override
  Future<void> upsert(String conversationId, DirectChatMessage message) async {}
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

class _FakeTransport implements HermesChatTransport {
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
