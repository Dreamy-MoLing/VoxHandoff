import 'client_event.dart';

sealed class ClientGatewayFrame {
  const ClientGatewayFrame();
}

class ClientGatewayEventFrame extends ClientGatewayFrame {
  const ClientGatewayEventFrame(this.event);

  final ClientEventRecord event;
}

enum ClientRequestState {
  accepted,
  working,
  completed,
  failed,
  cancelled,
  interrupted,
}

class ClientRequestStatusSnapshot {
  ClientRequestStatusSnapshot({
    required this.requestId,
    required this.originDeviceId,
    required this.conversationId,
    required this.state,
    required this.nodeId,
    required this.agentId,
    required this.capabilityRevision,
    required this.acceptedSequence,
    required this.failure,
    this.sessionId,
  }) {
    if (!_opaque(requestId) ||
        !_opaque(originDeviceId) ||
        !_opaque(conversationId) ||
        !_opaque(nodeId) ||
        !_opaque(agentId) ||
        !_opaque(capabilityRevision) ||
        (sessionId != null && !_opaque(sessionId!)) ||
        acceptedSequence <= BigInt.zero ||
        acceptedSequence > maximumUint64 ||
        (state == ClientRequestState.failed) != (failure != null)) {
      throw const FormatException('The request status snapshot is invalid.');
    }
  }

  final String requestId;
  final String originDeviceId;
  final String conversationId;
  final String? sessionId;
  final ClientRequestState state;
  final String nodeId;
  final String agentId;
  final String capabilityRevision;
  final BigInt acceptedSequence;
  final ClientStageFailure? failure;

  TrackedClientRequest toTrackedRequest() => TrackedClientRequest(
    originDeviceId: originDeviceId,
    conversationId: conversationId,
    sessionId: sessionId,
    requestId: requestId,
    nodeId: nodeId,
    agentId: agentId,
    capabilityRevision: capabilityRevision,
    acceptedSequence: acceptedSequence,
  );
}

class ClientGatewayRequestStatusFrame extends ClientGatewayFrame {
  const ClientGatewayRequestStatusFrame(this.status);

  final ClientRequestStatusSnapshot status;
}

class ClientReplayCompletion {
  ClientReplayCompletion({
    required this.commandId,
    required this.conversationId,
    required this.afterSequence,
    required this.throughSequence,
    required this.eventCount,
    required this.mayHaveMore,
  }) {
    if (!_opaque(commandId) ||
        !_opaque(conversationId) ||
        afterSequence < BigInt.zero ||
        throughSequence < afterSequence ||
        throughSequence > maximumUint64 ||
        eventCount < 0 ||
        eventCount > 500 ||
        (eventCount == 0 && throughSequence != afterSequence) ||
        (eventCount > 0 &&
            throughSequence - afterSequence != BigInt.from(eventCount))) {
      throw const FormatException('The replay completion fact is invalid.');
    }
  }

  final String commandId;
  final String conversationId;
  final BigInt afterSequence;
  final BigInt throughSequence;
  final int eventCount;
  final bool mayHaveMore;
}

class ClientGatewayReplayCompletedFrame extends ClientGatewayFrame {
  const ClientGatewayReplayCompletedFrame(this.completion);

  final ClientReplayCompletion completion;
}

class ClientNodeDirectoryEntry {
  const ClientNodeDirectoryEntry({
    required this.nodeId,
    required this.displayName,
    required this.platform,
    required this.version,
  });

  final String nodeId;
  final String displayName;
  final String platform;
  final String version;
}

class ClientAgentDirectoryEntry {
  const ClientAgentDirectoryEntry({
    required this.agentId,
    required this.displayName,
    required this.adapter,
    required this.version,
    required this.capabilityRevision,
    required this.supportsInterrupt,
    required this.supportsApprovals,
    required this.supportsClarifications,
  });

  final String agentId;
  final String displayName;
  final String adapter;
  final String version;
  final String capabilityRevision;
  final bool supportsInterrupt;
  final bool supportsApprovals;
  final bool supportsClarifications;
}

class ClientConversationDirectoryEntry {
  const ClientConversationDirectoryEntry({
    required this.conversationId,
    required this.title,
    required this.nodeId,
    required this.agentId,
    required this.capabilityRevision,
    required this.revision,
    required this.lastSequence,
    this.sessionId,
  });

  final String conversationId;
  final String title;
  final String nodeId;
  final String agentId;
  final String capabilityRevision;
  final String? sessionId;
  final BigInt revision;
  final BigInt lastSequence;
}

class ClientGatewayDirectory {
  const ClientGatewayDirectory({
    required this.commandId,
    required this.nodes,
    required this.agents,
    required this.conversations,
  });

  final String commandId;
  final List<ClientNodeDirectoryEntry> nodes;
  final List<ClientAgentDirectoryEntry> agents;
  final List<ClientConversationDirectoryEntry> conversations;
}

class ClientGatewayDirectoryFrame extends ClientGatewayFrame {
  const ClientGatewayDirectoryFrame(this.directory);
  final ClientGatewayDirectory directory;
}

class ClientGatewayConversationFrame extends ClientGatewayFrame {
  const ClientGatewayConversationFrame(this.conversation);
  final ClientConversationDirectoryEntry conversation;
}

class ClientGatewayHeartbeatFrame extends ClientGatewayFrame {
  const ClientGatewayHeartbeatFrame(this.lastReceivedSequence);

  final BigInt lastReceivedSequence;
}

class ClientControlLeaseSnapshot {
  ClientControlLeaseSnapshot({
    required this.leaseId,
    required this.conversationId,
    required this.deviceId,
    required this.revision,
    required this.expiresAt,
  }) {
    if (!_opaque(leaseId) ||
        !_opaque(conversationId) ||
        !_opaque(deviceId) ||
        revision <= BigInt.zero ||
        revision > maximumUint64 ||
        !expiresAt.isUtc) {
      throw const FormatException('The control lease snapshot is invalid.');
    }
  }

  final String leaseId;
  final String conversationId;
  final String deviceId;
  final BigInt revision;
  final DateTime expiresAt;
}

class ClientGatewayControlLeaseFrame extends ClientGatewayFrame {
  const ClientGatewayControlLeaseFrame(this.lease);

  final ClientControlLeaseSnapshot lease;
}

class ClientGatewayAcknowledgement {
  const ClientGatewayAcknowledgement({
    required this.conversationId,
    required this.sequence,
    required this.eventId,
  });

  final String conversationId;
  final BigInt sequence;
  final String eventId;
}

abstract interface class ClientGatewayCommandPort {
  void acknowledge(ClientGatewayAcknowledgement acknowledgement);

  void requestReplay({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required BigInt afterSequence,
    required int maximumEvents,
  });

  void requestStatus({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
  });

  void requestDirectory({
    required String commandId,
    required String idempotencyKey,
  });

  void createConversation({
    required String commandId,
    required String idempotencyKey,
    required ClientConversationDirectoryEntry conversation,
  });

  void acquireControl({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    String? expectedLeaseId,
    BigInt? expectedRevision,
    required bool explicitTakeover,
  });

  void sendConfirmedText({
    required String commandId,
    required String idempotencyKey,
    required String requestId,
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  });

  Future<void> close();
}

final BigInt maximumUint64 = (BigInt.one << 64) - BigInt.one;

bool _opaque(String value) =>
    value.isNotEmpty &&
    value.length <= 256 &&
    !value.contains(RegExp(r'[\u0000-\u001f\u007f]'));
