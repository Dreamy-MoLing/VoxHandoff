import 'package:agent_talk_client/application/gateway_workspace_controller.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/conversation_timeline.dart';
import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:agent_talk_client/domain/gateway_workspace.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real HomeScreen keeps 500 historical turns lazy on desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gatewayWorkspaceProvider.overrideWith(
            _MediumHistoryWorkspaceController.new,
          ),
        ],
        child: MaterialApp(
          theme: buildAgentTalkDarkTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('conversation-turns')), findsOneWidget);
    expect(find.byKey(const ValueKey('turn-request-499')), findsNothing);
    expect(find.byType(Card).evaluate().length, lessThan(50));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real HomeScreen virtualizes 2000 historical turns on a phone viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gatewayWorkspaceProvider.overrideWith(
              _LongHistoryWorkspaceController.new,
            ),
          ],
          child: MaterialApp(
            theme: buildAgentTalkDarkTheme(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-conversation')), findsOneWidget);
      expect(find.byKey(const ValueKey('turn-request-1999')), findsNothing);
      expect(find.byType(Card).evaluate().length, lessThan(40));
      expect(tester.takeException(), isNull);
    },
  );
}

class _LongHistoryWorkspaceController extends GatewayWorkspaceController {
  @override
  GatewayWorkspaceState build() => _longHistoryWorkspace(2000);
}

class _MediumHistoryWorkspaceController extends GatewayWorkspaceController {
  @override
  GatewayWorkspaceState build() => _longHistoryWorkspace(500);
}

GatewayWorkspaceState _longHistoryWorkspace(int eventCount) {
  final events = [
    for (var index = 0; index < eventCount; index += 1) _terminalEvent(index),
  ];
  return GatewayWorkspaceState(
    connectionPhase: GatewayConnectionPhase.connected,
    directory: ClientGatewayDirectory(
      commandId: 'directory-command-1',
      nodes: const [
        ClientNodeDirectoryEntry(
          nodeId: 'node-1',
          displayName: 'Hermes host',
          platform: 'linux',
          version: '0.1.0',
        ),
      ],
      agents: const [
        ClientAgentDirectoryEntry(
          agentId: 'hermes-1',
          nodeId: 'node-1',
          displayName: 'Hermes',
          adapter: 'hermes',
          version: 'test',
          capabilityRevision: 'hermes-cap-1',
          supportsInterrupt: true,
          supportsApprovals: true,
          supportsClarifications: false,
        ),
      ],
      conversations: [
        ClientConversationDirectoryEntry(
          conversationId: 'conversation-1',
          title: 'Long Hermes history',
          nodeId: 'node-1',
          agentId: 'hermes-1',
          capabilityRevision: 'hermes-cap-1',
          revision: BigInt.one,
          lastSequence: BigInt.from(eventCount),
        ),
      ],
    ),
    selectedConversationId: 'conversation-1',
    events: events,
    turns: aggregateConversationTurns(events),
    selectedEventsHydrated: true,
  );
}

ClientEventRecord _terminalEvent(int index) {
  final sequence = index + 1;
  return ClientEventRecord(
    eventId: 'event-$sequence',
    connectionId: 'connection-1',
    originDeviceId: 'device-1',
    conversationId: 'conversation-1',
    requestId: 'request-$index',
    sequence: BigInt.from(sequence),
    occurredAt: DateTime.utc(2030).add(Duration(seconds: sequence)),
    kind: ClientEventKind.requestCompleted,
    content: const TerminalClientEventContent(null),
    envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
  );
}
