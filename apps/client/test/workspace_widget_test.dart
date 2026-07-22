import 'package:agent_talk_client/app/agent_talk_app.dart';
import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/device_pairing_controller.dart';
import 'package:agent_talk_client/application/gateway_workspace_controller.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:agent_talk_client/domain/gateway_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PairedController extends DevicePairingController {
  @override
  PairingState build() => PairingState(
    phase: PairingPhase.paired,
    gatewayAudience: 'https://gateway.example',
    deviceId: 'device-1',
    credentialId: 'credential-1',
    approvedScopes: const ['observe', 'send', 'approve', 'control'],
  );

  @override
  Future<void> restore() async {}
}

class ConnectedSessionController extends ClientSessionController {
  @override
  ClientSessionState build() => const ClientSessionState(
    connectionPhase: GatewayConnectionPhase.connected,
  );
}

class PopulatedWorkspaceController extends GatewayWorkspaceController {
  @override
  String? get deviceId => 'device-1';

  @override
  GatewayWorkspaceState build() => GatewayWorkspaceState(
    connectionPhase: GatewayConnectionPhase.connected,
    directory: ClientGatewayDirectory(
      commandId: 'directory-command-1',
      nodes: const [
        ClientNodeDirectoryEntry(
          nodeId: 'node-1',
          displayName: 'Workstation',
          platform: 'linux',
          version: '0.1.0',
        ),
      ],
      agents: const [
        ClientAgentDirectoryEntry(
          agentId: 'agent-1',
          nodeId: 'node-1',
          displayName: 'Codex',
          adapter: 'codex',
          version: '1.0.0',
          capabilityRevision: 'capability-1',
          supportsInterrupt: true,
          supportsApprovals: true,
          supportsClarifications: true,
        ),
      ],
      conversations: [
        ClientConversationDirectoryEntry(
          conversationId: 'conversation-1',
          title: 'M2 delivery',
          nodeId: 'node-1',
          agentId: 'agent-1',
          capabilityRevision: 'capability-1',
          revision: BigInt.one,
          lastSequence: BigInt.from(2),
        ),
      ],
    ),
    selectedConversationId: 'conversation-1',
    leases: {
      'conversation-1': ClientControlLeaseSnapshot(
        leaseId: 'lease-1',
        conversationId: 'conversation-1',
        deviceId: 'device-1',
        revision: BigInt.one,
        expiresAt: DateTime.utc(2035),
      ),
    },
    events: [
      ClientEventRecord(
        eventId: 'event-1',
        connectionId: 'connection-1',
        originDeviceId: 'device-1',
        conversationId: 'conversation-1',
        requestId: 'request-1',
        sequence: BigInt.one,
        occurredAt: DateTime.utc(2030),
        kind: ClientEventKind.messageCompleted,
        content: MessageClientEventContent(
          text:
              'This is the complete Agent reply, kept independently of speech.',
          revision: BigInt.one,
        ),
        envelopeSha256: ''.padLeft(64, 'a'),
      ),
      ClientEventRecord(
        eventId: 'event-2',
        connectionId: 'connection-1',
        originDeviceId: 'device-1',
        conversationId: 'conversation-1',
        requestId: 'request-1',
        sequence: BigInt.from(2),
        occurredAt: DateTime.utc(2030, 1, 1, 0, 0, 1),
        kind: ClientEventKind.approvalRequired,
        content: ApprovalClientEventContent(
          approvalId: 'approval-1',
          safeSummary: 'Run the reviewed command?',
          operationSummarySha256: ''.padLeft(64, 'b'),
          expiresAt: DateTime.utc(2035),
        ),
        envelopeSha256: ''.padLeft(64, 'c'),
      ),
    ],
  );
}

void main() {
  Future<void> pumpWorkspace(WidgetTester tester, {Size? size}) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          devicePairingProvider.overrideWith(PairedController.new),
          clientSessionProvider.overrideWith(ConnectedSessionController.new),
          gatewayWorkspaceProvider.overrideWith(
            PopulatedWorkspaceController.new,
          ),
        ],
        child: const AgentTalkApp(),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows durable full text and explicit approval controls', (
    tester,
  ) async {
    await pumpWorkspace(tester);

    expect(find.text('M2 delivery'), findsWidgets);
    expect(find.textContaining('complete Agent reply'), findsOneWidget);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);
    expect(find.text('Send unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connected workspace matches the desktop visual baseline', (
    tester,
  ) async {
    await pumpWorkspace(tester, size: const Size(1280, 800));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/connected_workspace_desktop.png'),
    );
  });

  testWidgets('connected workspace matches the phone visual baseline', (
    tester,
  ) async {
    await pumpWorkspace(tester, size: const Size(390, 844));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/connected_workspace_phone.png'),
    );
  });
}
