import 'client_event.dart';
import 'client_session.dart';
import 'gateway_sync.dart';

class GatewayWorkspaceState {
  const GatewayWorkspaceState({
    this.connectionPhase = GatewayConnectionPhase.unpaired,
    this.directory,
    this.selectedConversationId,
    this.events = const [],
    this.leases = const {},
    this.safeErrorCode,
    this.safeErrorMessage,
    this.uncertainRequestId,
  });

  final GatewayConnectionPhase connectionPhase;
  final ClientGatewayDirectory? directory;
  final String? selectedConversationId;
  final List<ClientEventRecord> events;
  final Map<String, ClientControlLeaseSnapshot> leases;
  final String? safeErrorCode;
  final String? safeErrorMessage;
  final String? uncertainRequestId;

  ClientConversationDirectoryEntry? get selectedConversation {
    final id = selectedConversationId;
    if (id == null) return null;
    for (final conversation in directory?.conversations ?? const []) {
      if (conversation.conversationId == id) return conversation;
    }
    return null;
  }

  ClientControlLeaseSnapshot? get selectedLease {
    final id = selectedConversationId;
    return id == null ? null : leases[id];
  }

  bool ownsSelectedLease(String? deviceId, DateTime now) {
    final lease = selectedLease;
    return lease != null &&
        deviceId != null &&
        lease.deviceId == deviceId &&
        lease.expiresAt.isAfter(now.toUtc());
  }

  GatewayWorkspaceState copyWith({
    GatewayConnectionPhase? connectionPhase,
    ClientGatewayDirectory? directory,
    String? selectedConversationId,
    List<ClientEventRecord>? events,
    Map<String, ClientControlLeaseSnapshot>? leases,
    String? safeErrorCode,
    String? safeErrorMessage,
    String? uncertainRequestId,
    bool clearSelection = false,
    bool clearError = false,
    bool clearUncertain = false,
  }) => GatewayWorkspaceState(
    connectionPhase: connectionPhase ?? this.connectionPhase,
    directory: directory ?? this.directory,
    selectedConversationId: clearSelection
        ? null
        : selectedConversationId ?? this.selectedConversationId,
    events: List.unmodifiable(events ?? this.events),
    leases: Map.unmodifiable(leases ?? this.leases),
    safeErrorCode: clearError ? null : safeErrorCode ?? this.safeErrorCode,
    safeErrorMessage: clearError
        ? null
        : safeErrorMessage ?? this.safeErrorMessage,
    uncertainRequestId: clearUncertain
        ? null
        : uncertainRequestId ?? this.uncertainRequestId,
  );
}
