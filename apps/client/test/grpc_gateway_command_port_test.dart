import 'dart:async';

import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_command_port.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_live_transport.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLiveConnection implements GatewayLiveEventConnection {
  final commands = <ClientCommand>[];
  final acknowledgements = <Ack>[];

  @override
  Stream<GatewayLiveFrame> get frames => const Stream.empty();

  @override
  void acknowledge(Ack acknowledgement) {
    acknowledgements.add(acknowledgement.deepCopy());
  }

  @override
  void sendCommand(ClientCommand command) {
    commands.add(command.deepCopy());
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('maps recovery operations without constructing executable commands', () {
    final connection = FakeLiveConnection();
    final port = GrpcGatewayCommandPort(connection);

    port.requestStatus(
      commandId: 'status-command-1',
      idempotencyKey: 'status-idempotency-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
    );
    port.requestReplay(
      commandId: 'replay-command-1',
      idempotencyKey: 'replay-idempotency-1',
      conversationId: 'conversation-1',
      afterSequence: BigInt.from(7),
      maximumEvents: 500,
    );
    port.acknowledge(
      ClientGatewayAcknowledgement(
        conversationId: 'conversation-1',
        sequence: BigInt.from(8),
        eventId: 'event-8',
      ),
    );

    expect(connection.commands.map((command) => command.whichCommand()), [
      ClientCommand_Command.getRequest,
      ClientCommand_Command.replay,
    ]);
    expect(connection.commands.first.getRequest.requestId, 'request-1');
    expect(connection.commands.last.replay.afterSequence.toString(), '7');
    expect(connection.acknowledgements.single.eventId, 'event-8');
    expect(
      connection.commands.any(
        (command) => command.whichCommand() == ClientCommand_Command.send,
      ),
      isFalse,
    );
  });

  test('maps explicit directory, conversation, lease, and send commands', () {
    final connection = FakeLiveConnection();
    final port = GrpcGatewayCommandPort(connection);
    final conversation = ClientConversationDirectoryEntry(
      conversationId: 'conversation-1',
      title: 'Codex work',
      nodeId: 'node-1',
      agentId: 'agent-1',
      capabilityRevision: 'capability-1',
      sessionId: 'session-1',
      revision: BigInt.one,
      lastSequence: BigInt.zero,
    );
    final lease = ClientControlLeaseSnapshot(
      leaseId: 'lease-1',
      conversationId: 'conversation-1',
      deviceId: 'device-1',
      revision: BigInt.from(2),
      expiresAt: DateTime.utc(2030),
    );

    port.requestDirectory(
      commandId: 'directory-command-1',
      idempotencyKey: 'directory-idempotency-1',
    );
    port.createConversation(
      commandId: 'create-command-1',
      idempotencyKey: 'create-idempotency-1',
      conversation: conversation,
    );
    port.acquireControl(
      commandId: 'lease-command-1',
      idempotencyKey: 'lease-idempotency-1',
      conversationId: 'conversation-1',
      explicitTakeover: true,
    );
    port.renewControl(
      commandId: 'renew-command-1',
      idempotencyKey: 'renew-idempotency-1',
      lease: lease,
    );
    port.sendConfirmedText(
      commandId: 'send-command-1',
      idempotencyKey: 'send-idempotency-1',
      requestId: 'request-1',
      conversation: conversation,
      lease: lease,
      confirmedText: 'Confirmed text',
    );
    port.interruptRequest(
      commandId: 'interrupt-command-1',
      idempotencyKey: 'interrupt-idempotency-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
      lease: lease,
    );
    port.resolveApproval(
      commandId: 'approval-command-1',
      idempotencyKey: 'approval-idempotency-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
      approvalId: 'approval-1',
      operationSummarySha256: ''.padLeft(64, 'a'),
      decision: ClientApprovalDecision.deny,
      deviceSignature: ClientDeviceSignature(
        credentialId: 'credential-1',
        nonce: List.filled(32, 1),
        signature: List.filled(64, 2),
      ),
      lease: lease,
    );
    port.resolveClarification(
      commandId: 'clarification-command-1',
      idempotencyKey: 'clarification-idempotency-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
      clarificationId: 'clarification-1',
      confirmedText: 'Explicit answer',
      lease: lease,
    );

    expect(connection.commands.map((command) => command.whichCommand()), [
      ClientCommand_Command.listDirectory,
      ClientCommand_Command.createConversation,
      ClientCommand_Command.acquireLease,
      ClientCommand_Command.renewLease,
      ClientCommand_Command.send,
      ClientCommand_Command.interrupt,
      ClientCommand_Command.resolveApproval,
      ClientCommand_Command.resolveClarification,
    ]);
    expect(connection.commands[1].createConversation.title, 'Codex work');
    expect(connection.commands[2].acquireLease.explicitTakeover, isTrue);
    expect(connection.commands[3].renewLease.leaseId, 'lease-1');
    expect(connection.commands[3].renewLease.expectedRevision.toString(), '2');
    expect(connection.commands[4].leaseRevision.toString(), '2');
    expect(connection.commands[4].send.confirmedText, 'Confirmed text');
    expect(
      connection.commands[6].resolveApproval.decision,
      ApprovalDecision.APPROVAL_DECISION_DENY,
    );
    expect(
      connection.commands[6].resolveApproval.deviceSignature.signature,
      hasLength(64),
    );
    expect(
      connection.commands[7].resolveClarification.confirmedText,
      'Explicit answer',
    );
  });
}
