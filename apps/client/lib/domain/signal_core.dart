import 'client_event.dart';
import 'client_session.dart';
import 'gateway_workspace.dart';
import 'speech.dart';
import 'voice.dart';

enum SignalCoreState {
  idle,
  recording,
  transcribing,
  awaitingConfirmation,
  submitting,
  working,
  speaking,
  approval,
  completed,
  failed,
  uncertain,
}

class SignalCoreSnapshot {
  const SignalCoreSnapshot({
    required this.state,
    required this.label,
    required this.audioLevel,
    required this.playbackLevel,
    this.conversationId,
    this.requestId,
    this.sourceIdentity,
  });

  final SignalCoreState state;
  final String label;
  final double audioLevel;
  final double playbackLevel;
  final String? conversationId;
  final String? requestId;
  final String? sourceIdentity;

  bool get demandsInteraction => state == SignalCoreState.approval;

  bool get isExpanded =>
      state == SignalCoreState.recording ||
      state == SignalCoreState.transcribing;
}

SignalCoreSnapshot resolveSignalCore({
  required GatewayWorkspaceState workspace,
  required ClientSessionState session,
  required VoiceSessionState voice,
  required SpeechPlaybackState speech,
}) {
  final conversationId = workspace.selectedConversationId;
  final events =
      workspace.events
          .where((event) => event.conversationId == conversationId)
          .toList(growable: false)
        ..sort((left, right) => left.sequence.compareTo(right.sequence));
  final latestEvent = events.isEmpty ? null : events.last;
  final latestRequestId = latestEvent?.requestId;
  final pendingInteraction = _latestPendingInteraction(events);

  if (pendingInteraction != null) {
    return _snapshot(
      SignalCoreState.approval,
      pendingInteraction.kind == ClientEventKind.approvalRequired
          ? 'Approval required'
          : 'Clarification required',
      conversationId: conversationId,
      requestId: pendingInteraction.requestId,
      sourceIdentity: pendingInteraction.eventId,
    );
  }

  final uncertainRequestId =
      workspace.uncertainRequestId ??
      (session.draftPhase == DraftPhase.uncertain ? session.requestId : null);
  if (uncertainRequestId != null) {
    return _snapshot(
      SignalCoreState.uncertain,
      'Request outcome uncertain',
      conversationId: conversationId,
      requestId: uncertainRequestId,
      sourceIdentity: uncertainRequestId,
    );
  }

  if (voice.phase == VoiceInputPhase.failed ||
      speech.phase == SpeechPhase.failed ||
      latestEvent?.kind == ClientEventKind.requestFailed) {
    return _snapshot(
      SignalCoreState.failed,
      'Request or voice stage failed',
      conversationId: conversationId,
      requestId: latestRequestId,
      sourceIdentity:
          voice.failure?.code ?? speech.failure?.code ?? latestEvent?.eventId,
    );
  }

  if (voice.phase == VoiceInputPhase.recording) {
    return _snapshot(
      SignalCoreState.recording,
      'Recording voice',
      conversationId: conversationId,
      audioLevel: voice.audioLevel,
      sourceIdentity: voice.sessionId,
    );
  }
  if (voice.phase == VoiceInputPhase.transcribing ||
      voice.phase == VoiceInputPhase.requestingPermission) {
    return _snapshot(
      SignalCoreState.transcribing,
      voice.phase == VoiceInputPhase.requestingPermission
          ? 'Preparing microphone'
          : 'Transcribing voice',
      conversationId: conversationId,
      sourceIdentity: voice.sessionId,
    );
  }
  if (voice.phase == VoiceInputPhase.awaitingConfirmation ||
      session.draftPhase == DraftPhase.confirmed) {
    return _snapshot(
      SignalCoreState.awaitingConfirmation,
      'Waiting for text confirmation',
      conversationId: conversationId,
      sourceIdentity: voice.sessionId,
    );
  }
  if (session.draftPhase == DraftPhase.submitting) {
    return _snapshot(
      SignalCoreState.submitting,
      'Submitting confirmed text',
      conversationId: conversationId,
      requestId: session.requestId,
      sourceIdentity: session.requestId,
    );
  }

  if (latestEvent != null && !_terminalKinds.contains(latestEvent.kind)) {
    return _snapshot(
      SignalCoreState.working,
      'Agent working',
      conversationId: conversationId,
      requestId: latestEvent.requestId,
      sourceIdentity: latestEvent.eventId,
    );
  }

  final segment = speech.segment;
  if (speech.phase == SpeechPhase.playing &&
      segment != null &&
      segment.conversationId == conversationId &&
      (latestRequestId == null || segment.requestId == latestRequestId)) {
    return _snapshot(
      SignalCoreState.speaking,
      'Playing speech',
      conversationId: conversationId,
      requestId: segment.requestId,
      playbackLevel: 1,
      sourceIdentity: segment.identity,
    );
  }

  if (latestEvent?.kind == ClientEventKind.requestCompleted) {
    return _snapshot(
      SignalCoreState.completed,
      'Request completed',
      conversationId: conversationId,
      requestId: latestEvent!.requestId,
      sourceIdentity: latestEvent.eventId,
    );
  }

  return _snapshot(
    SignalCoreState.idle,
    'VoxHandoff idle',
    conversationId: conversationId,
  );
}

SignalCoreSnapshot _snapshot(
  SignalCoreState state,
  String label, {
  String? conversationId,
  String? requestId,
  String? sourceIdentity,
  double audioLevel = 0,
  double playbackLevel = 0,
}) => SignalCoreSnapshot(
  state: state,
  label: label,
  conversationId: conversationId,
  requestId: requestId,
  sourceIdentity: sourceIdentity,
  audioLevel: audioLevel.clamp(0, 1),
  playbackLevel: playbackLevel.clamp(0, 1),
);

ClientEventRecord? _latestPendingInteraction(List<ClientEventRecord> events) {
  final resolvedApprovalIds = <String>{};
  final resolvedClarificationIds = <String>{};
  for (final event in events.reversed) {
    final content = event.content;
    if (content is ApprovalClientEventContent) {
      if (event.kind != ClientEventKind.approvalRequired) {
        resolvedApprovalIds.add(content.approvalId);
      } else if (!resolvedApprovalIds.contains(content.approvalId)) {
        return event;
      }
    }
    if (content is ClarificationClientEventContent) {
      if (event.kind != ClientEventKind.clarificationRequired) {
        resolvedClarificationIds.add(content.clarificationId);
      } else if (!resolvedClarificationIds.contains(content.clarificationId)) {
        return event;
      }
    }
  }
  return null;
}

const _terminalKinds = {
  ClientEventKind.requestCompleted,
  ClientEventKind.requestFailed,
  ClientEventKind.requestCancelled,
  ClientEventKind.requestInterrupted,
};
