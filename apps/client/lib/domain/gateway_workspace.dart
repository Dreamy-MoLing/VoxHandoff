import 'client_event.dart';
import 'client_session.dart';
import 'conversation_timeline.dart';
import 'gateway_sync.dart';

class GatewayWorkspaceState {
  const GatewayWorkspaceState({
    this.connectionPhase = GatewayConnectionPhase.unpaired,
    this.directory,
    this.selectedConversationId,
    this.events = const [],
    this.turns = const [],
    this.selectedEventsHydrated = false,
    this.latestLiveEvent,
    this.leases = const {},
    this.safeErrorCode,
    this.safeErrorMessage,
    this.uncertainRequestId,
  });

  final GatewayConnectionPhase connectionPhase;
  final ClientGatewayDirectory? directory;
  final String? selectedConversationId;
  final List<ClientEventRecord> events;
  final List<ConversationTurn> turns;
  final bool selectedEventsHydrated;
  final ClientEventRecord? latestLiveEvent;
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

  List<ConversationTurn> get timeline => turns.isNotEmpty || events.isEmpty
      ? turns
      : aggregateConversationTurns(events);

  ConversationTurn? get latestTurn => timeline.isEmpty ? null : timeline.last;

  ConversationTurn? get activeTurn {
    for (final turn in timeline.reversed) {
      if (turn.canInterrupt) return turn;
      if (turn.isTerminal) return null;
    }
    return null;
  }

  ClientEventRecord? get pendingInteraction {
    for (final turn in timeline.reversed) {
      final pending = turn.pendingInteraction;
      if (pending != null) return pending;
    }
    return null;
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
    List<ConversationTurn>? turns,
    bool? selectedEventsHydrated,
    ClientEventRecord? latestLiveEvent,
    Map<String, ClientControlLeaseSnapshot>? leases,
    String? safeErrorCode,
    String? safeErrorMessage,
    String? uncertainRequestId,
    bool clearSelection = false,
    bool clearLiveEvent = false,
    bool clearError = false,
    bool clearUncertain = false,
  }) => GatewayWorkspaceState(
    connectionPhase: connectionPhase ?? this.connectionPhase,
    directory: directory ?? this.directory,
    selectedConversationId: clearSelection
        ? null
        : selectedConversationId ?? this.selectedConversationId,
    events: List.unmodifiable(events ?? this.events),
    turns: List.unmodifiable(turns ?? this.turns),
    selectedEventsHydrated:
        selectedEventsHydrated ?? this.selectedEventsHydrated,
    latestLiveEvent: clearLiveEvent
        ? null
        : latestLiveEvent ?? this.latestLiveEvent,
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
