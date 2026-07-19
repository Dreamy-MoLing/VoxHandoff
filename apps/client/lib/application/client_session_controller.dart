import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/client_session.dart';

final clientSessionProvider =
    NotifierProvider<ClientSessionController, ClientSessionState>(
      ClientSessionController.new,
    );

class ClientSessionController extends Notifier<ClientSessionState> {
  @override
  ClientSessionState build() => const ClientSessionState();

  void setConnectionPhase(GatewayConnectionPhase phase) {
    state = state.copyWith(connectionPhase: phase);
  }

  void editDraft(String text) {
    if (!state.canEditDraft) {
      throw StateError('A submitted or uncertain draft cannot be overwritten.');
    }
    state = state.copyWith(
      draftText: text,
      draftRevision: state.draftRevision + 1,
      draftPhase: DraftPhase.editing,
      clearRequestId: true,
    );
  }

  void confirmDraft() {
    if (!state.canConfirmDraft) {
      throw StateError('Only a non-empty editable draft can be confirmed.');
    }
    state = state.copyWith(
      draftText: state.draftText.trim(),
      draftPhase: DraftPhase.confirmed,
    );
  }

  void reopenDraft() {
    if (state.draftPhase != DraftPhase.confirmed) {
      throw StateError('Only a locally confirmed draft can be reopened.');
    }
    state = state.copyWith(draftPhase: DraftPhase.editing);
  }

  void beginSubmission(String requestId) {
    if (!state.canSubmit ||
        requestId.isEmpty ||
        requestId.contains(RegExp(r'\s'))) {
      throw StateError(
        'Submission requires a connected Gateway, confirmation, and opaque request ID.',
      );
    }
    state = state.copyWith(
      draftPhase: DraftPhase.submitting,
      requestId: requestId,
    );
  }

  void markAccepted(String requestId) {
    if (state.draftPhase != DraftPhase.submitting ||
        state.requestId != requestId) {
      throw StateError('Acceptance does not match the in-flight request.');
    }
    state = state.copyWith(draftPhase: DraftPhase.accepted);
  }

  void markAcceptanceUncertain(String requestId) {
    if (state.draftPhase != DraftPhase.submitting ||
        state.requestId != requestId) {
      throw StateError('Uncertain state does not match the in-flight request.');
    }
    state = state.copyWith(draftPhase: DraftPhase.uncertain);
  }
}
