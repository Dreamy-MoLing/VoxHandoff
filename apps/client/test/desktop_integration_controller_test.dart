import 'dart:async';

import 'package:agent_talk_client/application/desktop_integration_controller.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/desktop_capabilities.dart';
import 'package:agent_talk_client/domain/gateway_workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'initial replay is remembered without producing notifications',
    () async {
      final port = _FakeDesktopIntegration();
      final container = ProviderContainer(
        overrides: [desktopIntegrationPortProvider.overrideWithValue(port)],
      );
      addTearDown(container.dispose);
      final controller = container.read(desktopIntegrationProvider.notifier);
      final initial = _workspace([
        _event('approval-old', ClientEventKind.approvalRequired, sequence: 1),
      ]);

      await controller.initialize(
        onVoiceToggle: () async {},
        workspace: initial,
      );
      await controller.observeWorkspace(initial);

      expect(port.attention, isEmpty);
      expect(
        container.read(desktopIntegrationProvider).hotkey.level,
        DesktopCapabilityLevel.available,
      );
    },
  );

  test('new attention facts notify once and ignore duplicate replay', () async {
    final port = _FakeDesktopIntegration();
    final container = ProviderContainer(
      overrides: [desktopIntegrationPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);
    final controller = container.read(desktopIntegrationProvider.notifier);
    await controller.initialize(
      onVoiceToggle: () async {},
      workspace: _workspace(const []),
    );
    final workspace = _workspace([
      _event(
        'clarification-new',
        ClientEventKind.clarificationRequired,
        sequence: 1,
      ),
    ]);

    await controller.observeWorkspace(workspace);
    await controller.observeWorkspace(workspace);

    expect(port.attention, [DesktopAttentionKind.clarification]);
  });

  test(
    'only the latest selected-conversation attention kind is emitted',
    () async {
      final port = _FakeDesktopIntegration();
      final container = ProviderContainer(
        overrides: [desktopIntegrationPortProvider.overrideWithValue(port)],
      );
      addTearDown(container.dispose);
      final controller = container.read(desktopIntegrationProvider.notifier);
      await controller.initialize(
        onVoiceToggle: () async {},
        workspace: _workspace(const []),
      );

      await controller.observeWorkspace(
        _workspace([
          _event(
            'other-approval',
            ClientEventKind.approvalRequired,
            sequence: 1,
            conversationId: 'conversation-other',
          ),
          _event(
            'request-completed',
            ClientEventKind.requestCompleted,
            sequence: 2,
          ),
        ]),
      );

      expect(port.attention, [DesktopAttentionKind.completed]);
    },
  );

  test('hotkey callback remains an explicit voice-toggle callback', () async {
    final port = _FakeDesktopIntegration();
    final container = ProviderContainer(
      overrides: [desktopIntegrationPortProvider.overrideWithValue(port)],
    );
    addTearDown(container.dispose);
    var toggles = 0;

    await container
        .read(desktopIntegrationProvider.notifier)
        .initialize(
          onVoiceToggle: () async => toggles += 1,
          workspace: _workspace(const []),
        );
    await port.onVoiceToggle!();

    expect(toggles, 1);
    expect(port.attention, isEmpty);
  });

  test(
    'attention arriving during initialization is delivered after setup',
    () async {
      final gate = Completer<void>();
      final port = _FakeDesktopIntegration(initializeGate: gate);
      final container = ProviderContainer(
        overrides: [desktopIntegrationPortProvider.overrideWithValue(port)],
      );
      addTearDown(container.dispose);
      final controller = container.read(desktopIntegrationProvider.notifier);
      final initializing = controller.initialize(
        onVoiceToggle: () async {},
        workspace: _workspace(const []),
      );

      await controller.observeWorkspace(
        _workspace([
          _event(
            'approval-during-setup',
            ClientEventKind.approvalRequired,
            sequence: 1,
          ),
        ]),
      );
      expect(port.attention, isEmpty);

      gate.complete();
      await initializing;
      expect(port.attention, [DesktopAttentionKind.approval]);
    },
  );
}

class _FakeDesktopIntegration implements DesktopIntegrationPort {
  _FakeDesktopIntegration({this.initializeGate});

  final Completer<void>? initializeGate;
  DesktopVoiceToggle? onVoiceToggle;
  final List<DesktopAttentionKind> attention = [];

  @override
  Future<DesktopCapabilitySnapshot> initialize({
    required DesktopVoiceToggle onVoiceToggle,
  }) async {
    this.onVoiceToggle = onVoiceToggle;
    await initializeGate?.future;
    return const DesktopCapabilitySnapshot(
      isDesktop: true,
      hotkey: DesktopCapability.available('hotkey available'),
      tray: DesktopCapability.available('tray available'),
      notifications: DesktopCapability.available('notifications available'),
      window: DesktopCapability.available('window available'),
    );
  }

  @override
  Future<void> showAttention(DesktopAttentionKind kind) async {
    attention.add(kind);
  }

  @override
  Future<void> showWindow() async {}

  @override
  Future<void> close() async {}
}

GatewayWorkspaceState _workspace(List<ClientEventRecord> events) =>
    GatewayWorkspaceState(
      selectedConversationId: 'conversation-1',
      events: events,
    );

ClientEventRecord _event(
  String eventId,
  ClientEventKind kind, {
  required int sequence,
  String conversationId = 'conversation-1',
}) {
  final content = switch (kind) {
    ClientEventKind.approvalRequired => ApprovalClientEventContent(
      approvalId: 'approval-$sequence',
      safeSummary: 'Review in app',
      operationSummarySha256: 'b' * 64,
      expiresAt: DateTime.utc(2030),
    ),
    ClientEventKind.clarificationRequired => ClarificationClientEventContent(
      clarificationId: 'clarification-$sequence',
      safePrompt: 'Review in app',
      expiresAt: DateTime.utc(2030),
    ),
    ClientEventKind.requestCompleted => const TerminalClientEventContent(null),
    _ => const EmptyClientEventContent(),
  };
  return ClientEventRecord(
    eventId: eventId,
    connectionId: 'connection-1',
    originDeviceId: 'device-1',
    conversationId: conversationId,
    requestId: 'request-1',
    sequence: BigInt.from(sequence),
    occurredAt: DateTime.utc(2026, 7, 25),
    kind: kind,
    content: content,
    envelopeSha256: 'a' * 64,
  );
}
