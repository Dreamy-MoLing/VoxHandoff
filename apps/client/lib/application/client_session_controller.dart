import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/client_session.dart';
import '../domain/confirmed_draft.dart';

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
      clearConfirmedDraft: true,
    );
  }

  void confirmDraft([ConfirmedDraft? confirmedDraft]) {
    if (!state.canConfirmDraft) {
      throw StateError('Only a non-empty editable draft can be confirmed.');
    }
    final boundDraft =
        confirmedDraft ??
        ConfirmedDraft(
          draftId: 'legacy-test-draft',
          draftRevision: state.draftRevision,
          confirmedText: state.draftText,
          assistantId: 'legacy-test-assistant',
          assistantRevision: 1,
          contextSnapshotRevision: 0,
          contextSnapshotHash: ConfirmedDraft.contextHash(const []),
          target: const HermesTargetSnapshot(
            conversationId: 'legacy-test-conversation',
            nodeId: 'legacy-test-node',
            agentId: 'legacy-test-agent',
            capabilityRevision: 'legacy-test-capability',
          ),
        );
    if (boundDraft.draftRevision != state.draftRevision ||
        boundDraft.confirmedText != state.draftText.trim()) {
      throw StateError('The confirmed draft does not match the editable text.');
    }
    state = state.copyWith(
      draftText: boundDraft.confirmedText,
      draftPhase: DraftPhase.confirmed,
      confirmedDraft: boundDraft,
    );
  }

  void reopenDraft() {
    if (state.draftPhase != DraftPhase.confirmed) {
      throw StateError('Only a locally confirmed draft can be reopened.');
    }
    state = state.copyWith(
      draftPhase: DraftPhase.editing,
      clearConfirmedDraft: true,
    );
  }

  void invalidateConfirmation() {
    if (state.draftPhase == DraftPhase.confirmed) {
      state = state.copyWith(
        draftPhase: DraftPhase.editing,
        clearConfirmedDraft: true,
      );
    }
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

  /// A directly configured LLM has no Gateway acceptance proof. Its request is
  /// intentionally single-shot and local; this only advances the editable
  /// draft after the controller has durably recorded the confirmed text.
  void markAcceptedLocal() {
    if (state.draftPhase != DraftPhase.confirmed ||
        state.confirmedDraft == null) {
      throw StateError('Only a confirmed draft can be sent to a local LLM.');
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

  void startNextDraft() {
    if (state.draftPhase != DraftPhase.accepted) {
      throw StateError(
        'Only an accepted draft can be cleared for the next request.',
      );
    }
    state = state.copyWith(
      draftText: '',
      draftRevision: state.draftRevision + 1,
      draftPhase: DraftPhase.editing,
      clearRequestId: true,
      clearConfirmedDraft: true,
    );
  }
}
