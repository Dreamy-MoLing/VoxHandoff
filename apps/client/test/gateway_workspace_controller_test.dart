import 'dart:async';

import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/gateway_workspace_controller.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWorkspaceFactory implements GatewayWorkspaceSessionFactory {
  final session = FakeWorkspaceSession();

  @override
  Future<GatewayWorkspaceSession> open() async => session;
}

class FakeWorkspaceSession implements GatewayWorkspaceSession {
  final runCompleter = Completer<void>();
  WorkspaceDirectoryCallback? directoryCallback;
  WorkspaceConversationCallback? conversationCallback;
  WorkspaceEventCallback? eventCallback;
  WorkspaceStatusCallback? statusCallback;
  WorkspaceLeaseCallback? leaseCallback;
  var directoryRequests = 0;
  var acquireCalls = 0;
  var renewCalls = 0;
  var createCalls = 0;
  var sendCalls = 0;
  var unknownCalls = 0;
  var closeCalls = 0;
  bool? lastExplicitTakeover;
  bool throwAfterPrepared = false;
  final storedEvents = <ClientEventRecord>[];

  @override
  String get deviceId => 'device-1';

  @override
  Future<void> run({
    required WorkspaceDirectoryCallback onDirectory,
    required WorkspaceConversationCallback onConversation,
    required WorkspaceEventCallback onEvent,
    required WorkspaceStatusCallback onStatus,
    required WorkspaceLeaseCallback onLease,
  }) {
    directoryCallback = onDirectory;
    conversationCallback = onConversation;
    eventCallback = onEvent;
    statusCallback = onStatus;
    leaseCallback = onLease;
    return runCompleter.future;
  }

  @override
  void requestDirectory() => directoryRequests += 1;

  @override
  void acquireControl(
    String conversationId, {
    ClientControlLeaseSnapshot? expected,
    required bool explicitTakeover,
  }) {
    acquireCalls += 1;
    lastExplicitTakeover = explicitTakeover;
  }

  @override
  void renewControl(ClientControlLeaseSnapshot lease) {
    renewCalls += 1;
  }

  @override
  void createConversation(ClientConversationDirectoryEntry conversation) {
    createCalls += 1;
  }

  @override
  Future<String> sendConfirmedText({
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
    required void Function(String requestId) onPrepared,
  }) async {
    sendCalls += 1;
    onPrepared('request-local-1');
    if (throwAfterPrepared) throw StateError('wire write failed');
    return 'request-local-1';
  }

  @override
  void interruptRequest({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  Future<void> resolveApproval({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
    required ClientApprovalDecision decision,
  }) async {}

  @override
  void resolveClarification({
    required ClientEventRecord event,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  }) {}

  @override
  Future<List<ClientEventRecord>> listEvents(String conversationId) async =>
      List.unmodifiable(storedEvents);

  @override
  Future<void> markOutstandingUnknown() async => unknownCalls += 1;

  @override
  Future<void> close() async => closeCalls += 1;
}

ClientGatewayDirectory directory() => ClientGatewayDirectory(
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
      title: 'M2',
      nodeId: 'node-1',
      agentId: 'agent-1',
      capabilityRevision: 'capability-1',
      revision: BigInt.one,
      lastSequence: BigInt.zero,
    ),
  ],
);

void main() {
  test(
    'requires explicit control and never resubmits an uncertain send',
    () async {
      final factory = FakeWorkspaceFactory();
      final container = ProviderContainer(
        overrides: [
          gatewayWorkspaceSessionFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      final workspace = container.read(gatewayWorkspaceProvider.notifier);

      await workspace.connect();
      expect(factory.session.directoryRequests, 1);
      expect(factory.session.acquireCalls, 0);
      await factory.session.directoryCallback!(directory());
      expect(
        container.read(gatewayWorkspaceProvider).selectedConversationId,
        'conversation-1',
      );

      workspace.acquireSelectedControl(explicitTakeover: false);
      expect(factory.session.acquireCalls, 1);
      expect(factory.session.lastExplicitTakeover, isFalse);
      await factory.session.leaseCallback!(
        ClientControlLeaseSnapshot(
          leaseId: 'lease-1',
          conversationId: 'conversation-1',
          deviceId: 'device-1',
          revision: BigInt.one,
          expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
        ),
      );

      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('confirmed text');
      draft.confirmDraft();
      await workspace.sendConfirmedText('confirmed text');
      expect(factory.session.sendCalls, 1);
      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.submitting,
      );

      factory.session.runCompleter.completeError(StateError('disconnect'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(factory.session.unknownCalls, 1);
      expect(factory.session.sendCalls, 1);
      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.uncertain,
      );
      expect(
        container.read(gatewayWorkspaceProvider).connectionPhase,
        GatewayConnectionPhase.offline,
      );
    },
  );

  test(
    'renews an owned lease and makes a prepared write failure uncertain',
    () async {
      final factory = FakeWorkspaceFactory();
      final container = ProviderContainer(
        overrides: [
          gatewayWorkspaceSessionFactoryProvider.overrideWithValue(factory),
        ],
      );
      addTearDown(container.dispose);
      final workspace = container.read(gatewayWorkspaceProvider.notifier);

      await workspace.connect();
      await factory.session.directoryCallback!(directory());
      await factory.session.leaseCallback!(
        ClientControlLeaseSnapshot(
          leaseId: 'lease-short',
          conversationId: 'conversation-1',
          deviceId: 'device-1',
          revision: BigInt.one,
          expiresAt: DateTime.now().toUtc().add(
            const Duration(milliseconds: 400),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 220));
      expect(factory.session.renewCalls, 1);

      final draft = container.read(clientSessionProvider.notifier);
      draft.editDraft('confirmed text');
      draft.confirmDraft();
      factory.session.throwAfterPrepared = true;
      await workspace.sendConfirmedText('confirmed text');

      expect(factory.session.sendCalls, 1);
      expect(
        container.read(clientSessionProvider).draftPhase,
        DraftPhase.uncertain,
      );
      expect(
        container.read(gatewayWorkspaceProvider).safeErrorCode,
        'submission_outcome_uncertain',
      );
    },
  );
}
