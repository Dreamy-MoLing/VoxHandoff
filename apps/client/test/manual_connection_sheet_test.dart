import 'dart:async';

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
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/manual_connection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(FingerprintProbe probe, TofuTrustStore trustStore) {
    final memory = _MemorySecureStore();
    return ProviderScope(
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
      child: MaterialApp(
        theme: buildAgentTalkMobileDarkTheme(),
        home: const Scaffold(body: ManualConnectionSheet()),
      ),
    );
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String origin = 'https://hermes.example.test',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'HTTPS Hermes 地址'),
      origin,
    );
    await tester.enterText(
      find.widgetWithText(TextField, '模型'),
      'hermes-model',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'API key'),
      'secret-key',
    );
    await tester.tap(find.byKey(const Key('manual-connect-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('首次未知指纹：弹出裸 TOFU 确认对话框，无"永久忽略"选项', (tester) async {
    final probe = _ScriptedProbe(['sha256:first']);
    final trustStore = _MemoryTrustStore();
    await tester.pumpWidget(buildApp(probe, trustStore));

    await fillForm(tester);

    expect(find.text('首次连接：接受服务器指纹？'), findsOneWidget);
    expect(find.text('sha256:first'), findsOneWidget);
    expect(find.text('接受此指纹并连接'), findsOneWidget);
    expect(find.text('永久忽略'), findsNothing);

    await tester.tap(find.byKey(const Key('tofu-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-connect-info')), findsOneWidget);
    expect(await trustStore.records(), isEmpty);
  });

  testWidgets('显式接受后连接成功，并记录该主机+该指纹的信任', (tester) async {
    final probe = _ScriptedProbe(['sha256:stable', 'sha256:stable']);
    final trustStore = _MemoryTrustStore();
    await tester.pumpWidget(buildApp(probe, trustStore));

    await fillForm(tester);

    expect(find.text('首次连接：接受服务器指纹？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tofu-accept')));
    await tester.pumpAndSettle();

    expect(find.text('已保存手动连接并信任服务器；链接将沿用现有主链路行为。'), findsOneWidget);
    final records = await trustStore.records();
    expect(records, hasLength(1));
    expect(records.first.origin, 'https://hermes.example.test:443');
    expect(records.first.fingerprint, 'sha256:stable');
  });

  testWidgets('探测失败不弹对话框，直接显示失败原因且不信任', (tester) async {
    const probe = _FailingProbe(
      FingerprintProbeException(
        'probe_unreachable',
        '无法连接目标服务器，未建立任何信任。请检查地址与网络后重试。',
      ),
    );
    final trustStore = _MemoryTrustStore();
    await tester.pumpWidget(buildApp(probe, trustStore));

    await fillForm(tester);

    expect(find.text('首次连接：接受服务器指纹？'), findsNothing);
    expect(find.text('无法连接目标服务器，未建立任何信任。请检查地址与网络后重试。'), findsOneWidget);
    expect(await trustStore.records(), isEmpty);
  });
}

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

class _MemoryTrustStore extends SecureTofuTrustStore {
  _MemoryTrustStore() : super(_MemorySecureStore());
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
