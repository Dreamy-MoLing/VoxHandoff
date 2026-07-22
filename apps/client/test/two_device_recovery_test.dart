import 'package:agent_talk_client/application/client_event_convergence.dart';
import 'package:agent_talk_client/application/gateway_frame_router.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:agent_talk_client/infrastructure/storage/drift_client_event_ledger.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingCommandPort implements ClientGatewayCommandPort {
  final replayAfter = <BigInt>[];
  final acknowledgements = <ClientGatewayAcknowledgement>[];
  var sendCalls = 0;
  var acquireCalls = 0;
  bool? explicitTakeover;

  @override
  void acknowledge(ClientGatewayAcknowledgement acknowledgement) =>
      acknowledgements.add(acknowledgement);

  @override
  void requestReplay({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required BigInt afterSequence,
    required int maximumEvents,
  }) => replayAfter.add(afterSequence);

  @override
  void acquireControl({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    String? expectedLeaseId,
    BigInt? expectedRevision,
    required bool explicitTakeover,
  }) {
    acquireCalls += 1;
    this.explicitTakeover = explicitTakeover;
  }

  @override
  void sendConfirmedText({
    required String commandId,
    required String idempotencyKey,
    required String requestId,
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  }) => sendCalls += 1;

  @override
  void createConversation({
    required String commandId,
    required String idempotencyKey,
    required ClientConversationDirectoryEntry conversation,
  }) {}

  @override
  void interruptRequest({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  void requestDirectory({
    required String commandId,
    required String idempotencyKey,
  }) {}

  @override
  void requestStatus({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
  }) {}

  @override
  void resolveApproval({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
    required String approvalId,
    required String operationSummarySha256,
    required ClientApprovalDecision decision,
    required ClientDeviceSignature deviceSignature,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  void resolveClarification({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
    required String clarificationId,
    required String confirmedText,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  Future<void> close() async {}
}

TrackedClientRequest route(int request, int acceptedSequence) =>
    TrackedClientRequest(
      originDeviceId: 'desktop-device',
      conversationId: 'conversation-1',
      requestId: 'request-$request',
      nodeId: 'node-1',
      agentId: 'agent-1',
      capabilityRevision: 'capability-1',
      acceptedSequence: BigInt.from(acceptedSequence),
    );

ClientEventRecord event(
  int sequence, {
  required int request,
  required ClientEventKind kind,
}) => ClientEventRecord(
  eventId: 'event-$sequence',
  connectionId: 'node-connection-1',
  originDeviceId: 'desktop-device',
  conversationId: 'conversation-1',
  requestId: 'request-$request',
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
  kind: kind,
  content: kind == ClientEventKind.requestAccepted
      ? const SafeMessageClientEventContent('Accepted.')
      : MessageClientEventContent(
          text: 'Complete reply $request',
          revision: BigInt.one,
        ),
  envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
);

GatewayFrameRouter router(
  DriftClientEventLedger ledger, {
  GatewayControlLeaseCallback? onLease,
}) => GatewayFrameRouter(
  ledger: ledger,
  convergence: ClientEventConvergence(ledger: ledger),
  onControlLease: onLease,
);

void main() {
  test(
    'two clients observe, explicitly take over, and resume from cursor',
    () async {
      // These are deliberately separate in-memory executors modelling two
      // devices, not duplicate handles to one database.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
      );
      final desktop = DriftClientEventLedger.inMemory();
      final phone = DriftClientEventLedger.inMemory();
      addTearDown(desktop.close);
      addTearDown(phone.close);
      await desktop.trackRequest(route(1, 1));
      await phone.trackRequest(route(1, 1));
      final desktopCommands = RecordingCommandPort();
      final phoneCommands = RecordingCommandPort();
      ClientControlLeaseSnapshot? desktopLease;
      ClientControlLeaseSnapshot? phoneLease;
      final heldByDesktop = ClientControlLeaseSnapshot(
        leaseId: 'lease-desktop',
        conversationId: 'conversation-1',
        deviceId: 'desktop-device',
        revision: BigInt.one,
        expiresAt: DateTime.utc(2030, 1, 1, 0, 5),
      );

      final initialFrames = [
        ClientGatewayEventFrame(
          event(1, request: 1, kind: ClientEventKind.requestAccepted),
        ),
        ClientGatewayEventFrame(
          event(2, request: 1, kind: ClientEventKind.messageCompleted),
        ),
        ClientGatewayControlLeaseFrame(heldByDesktop),
      ];
      await router(
        desktop,
        onLease: (lease) => desktopLease = lease,
      ).run(Stream.fromIterable(initialFrames), desktopCommands);
      await router(
        phone,
        onLease: (lease) => phoneLease = lease,
      ).run(Stream.fromIterable(initialFrames), phoneCommands);
      expect(desktopLease?.deviceId, 'desktop-device');
      expect(phoneLease?.deviceId, 'desktop-device');
      expect(phoneCommands.acquireCalls, 0);

      phoneCommands.acquireControl(
        commandId: 'takeover-command-1',
        idempotencyKey: 'takeover-idempotency-1',
        conversationId: 'conversation-1',
        expectedLeaseId: heldByDesktop.leaseId,
        expectedRevision: heldByDesktop.revision,
        explicitTakeover: true,
      );
      expect(phoneCommands.acquireCalls, 1);
      expect(phoneCommands.explicitTakeover, isTrue);

      await desktop.trackRequest(route(2, 3));
      await phone.trackRequest(route(2, 3));
      final recoveredFrames = [
        ClientGatewayEventFrame(
          event(3, request: 2, kind: ClientEventKind.requestAccepted),
        ),
        ClientGatewayEventFrame(
          event(4, request: 2, kind: ClientEventKind.messageCompleted),
        ),
      ];
      await router(
        phone,
      ).run(Stream.fromIterable(recoveredFrames), phoneCommands);
      await router(
        desktop,
      ).run(Stream.fromIterable(recoveredFrames), desktopCommands);

      expect(phoneCommands.replayAfter, contains(BigInt.from(2)));
      expect(
        (await phone.readCursor('conversation-1'))?.sequence,
        BigInt.from(4),
      );
      expect(
        (await desktop.readCursor('conversation-1'))?.sequence,
        BigInt.from(4),
      );
      expect(
        await phone.listConversationEvents('conversation-1'),
        hasLength(4),
      );
      expect(
        await desktop.listConversationEvents('conversation-1'),
        hasLength(4),
      );
      expect(phoneCommands.sendCalls, 0);
      expect(desktopCommands.sendCalls, 0);
    },
  );
}
