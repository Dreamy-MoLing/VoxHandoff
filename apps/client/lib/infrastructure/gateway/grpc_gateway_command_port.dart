import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';

import '../../domain/gateway_sync.dart';
import 'grpc_gateway_live_transport.dart';

class GrpcGatewayCommandPort implements ClientGatewayCommandPort {
  const GrpcGatewayCommandPort(this._connection);

  final GatewayLiveEventConnection _connection;

  @override
  void acknowledge(ClientGatewayAcknowledgement acknowledgement) {
    _connection.acknowledge(
      Ack(
        conversationId: acknowledgement.conversationId,
        sequence: _uint64(acknowledgement.sequence),
        eventId: acknowledgement.eventId,
      ),
    );
  }

  @override
  void requestReplay({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required BigInt afterSequence,
    required int maximumEvents,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversationId,
        replay: ReplayEvents(
          afterSequence: _uint64(afterSequence),
          maximumEvents: maximumEvents,
        ),
      ),
    );
  }

  @override
  void requestStatus({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversationId,
        getRequest: GetRequest(requestId: requestId),
      ),
    );
  }

  @override
  void requestDirectory({
    required String commandId,
    required String idempotencyKey,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        listDirectory: ListDirectory(),
      ),
    );
  }

  @override
  void createConversation({
    required String commandId,
    required String idempotencyKey,
    required ClientConversationDirectoryEntry conversation,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversation.conversationId,
        createConversation: CreateConversation(
          nodeId: conversation.nodeId,
          agentId: conversation.agentId,
          capabilityRevision: conversation.capabilityRevision,
          sessionId: conversation.sessionId ?? '',
          title: conversation.title,
        ),
      ),
    );
  }

  @override
  void acquireControl({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    String? expectedLeaseId,
    BigInt? expectedRevision,
    required bool explicitTakeover,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversationId,
        acquireLease: AcquireControlLease(
          expectedLeaseId: expectedLeaseId ?? '',
          expectedRevision: _uint64(expectedRevision ?? BigInt.zero),
          explicitTakeover: explicitTakeover,
        ),
      ),
    );
  }

  @override
  void sendConfirmedText({
    required String commandId,
    required String idempotencyKey,
    required String requestId,
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversation.conversationId,
        leaseId: lease.leaseId,
        leaseRevision: _uint64(lease.revision),
        requestId: requestId,
        send: SendRequest(
          agentId: conversation.agentId,
          nodeId: conversation.nodeId,
          sessionId: conversation.sessionId ?? '',
          confirmedText: confirmedText,
          capabilityRevision: conversation.capabilityRevision,
        ),
      ),
    );
  }

  @override
  Future<void> close() => _connection.close();

  Int64 _uint64(BigInt value) {
    if (value < BigInt.zero || value > maximumUint64) {
      throw const FormatException('The command sequence is invalid.');
    }
    return Int64.parseInt(value.toString());
  }
}
