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
  final latestTurn = workspace.latestTurn;
  final latestEvent = latestTurn?.latestEvent;
  final latestRequestId = latestTurn?.requestId;
  final pendingInteraction = workspace.pendingInteraction;

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
      voice.phase == VoiceInputPhase.awaitingCallConfirm ||
      session.draftPhase == DraftPhase.confirmed) {
    return _snapshot(
      SignalCoreState.awaitingConfirmation,
      voice.phase == VoiceInputPhase.awaitingCallConfirm
          ? 'Call preview'
          : 'Waiting for text confirmation',
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

  if (voice.phase == VoiceInputPhase.failed ||
      _isCurrentSpeechFailure(speech, conversationId, latestRequestId) ||
      latestTurn?.isFailed == true) {
    return _snapshot(
      SignalCoreState.failed,
      'Request or voice stage failed',
      conversationId: conversationId,
      requestId: latestRequestId,
      sourceIdentity:
          voice.failure?.code ?? speech.failure?.code ?? latestEvent?.eventId,
    );
  }

  final activeTurn = workspace.activeTurn;
  if (activeTurn != null) {
    return _snapshot(
      SignalCoreState.working,
      'Agent working',
      conversationId: conversationId,
      requestId: activeTurn.requestId,
      sourceIdentity: activeTurn.latestEvent.eventId,
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
      playbackLevel: speech.playbackLevel,
      sourceIdentity: segment.identity,
    );
  }

  if (latestTurn?.terminalEvent?.kind == ClientEventKind.requestCompleted) {
    return _snapshot(
      SignalCoreState.completed,
      'Request completed',
      conversationId: conversationId,
      requestId: latestTurn!.requestId,
      sourceIdentity: latestTurn.terminalEvent!.eventId,
    );
  }

  return _snapshot(
    SignalCoreState.idle,
    'VoxHandoff idle',
    conversationId: conversationId,
  );
}

bool _isCurrentSpeechFailure(
  SpeechPlaybackState speech,
  String? conversationId,
  String? latestRequestId,
) {
  if (speech.phase != SpeechPhase.failed) return false;
  final segment = speech.segment;
  if (segment == null) return true;
  return segment.conversationId == conversationId &&
      (latestRequestId == null || segment.requestId == latestRequestId);
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
