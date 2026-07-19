enum GatewayConnectionPhase {
  unpaired,
  connecting,
  connected,
  reconnecting,
  offline,
  failed,
}

enum DraftPhase { editing, confirmed, submitting, accepted, uncertain }

class ClientSessionState {
  const ClientSessionState({
    this.connectionPhase = GatewayConnectionPhase.unpaired,
    this.draftText = '',
    this.draftRevision = 0,
    this.draftPhase = DraftPhase.editing,
    this.requestId,
  });

  final GatewayConnectionPhase connectionPhase;
  final String draftText;
  final int draftRevision;
  final DraftPhase draftPhase;
  final String? requestId;

  bool get canEditDraft =>
      draftPhase == DraftPhase.editing || draftPhase == DraftPhase.confirmed;

  bool get canConfirmDraft =>
      draftPhase == DraftPhase.editing && draftText.trim().isNotEmpty;

  bool get canSubmit =>
      connectionPhase == GatewayConnectionPhase.connected &&
      draftPhase == DraftPhase.confirmed;

  ClientSessionState copyWith({
    GatewayConnectionPhase? connectionPhase,
    String? draftText,
    int? draftRevision,
    DraftPhase? draftPhase,
    String? requestId,
    bool clearRequestId = false,
  }) {
    return ClientSessionState(
      connectionPhase: connectionPhase ?? this.connectionPhase,
      draftText: draftText ?? this.draftText,
      draftRevision: draftRevision ?? this.draftRevision,
      draftPhase: draftPhase ?? this.draftPhase,
      requestId: clearRequestId ? null : requestId ?? this.requestId,
    );
  }
}
