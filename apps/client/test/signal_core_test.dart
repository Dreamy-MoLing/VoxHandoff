import 'package:agent_talk_client/application/hermes_conversation_controller.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/domain/gateway_workspace.dart';
import 'package:agent_talk_client/domain/signal_core.dart';
import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idleVoice = VoiceSessionState();
  const idleSpeech = SpeechPlaybackState();

  test('resolves every M4 state from durable or locally provable facts', () {
    expect(
      resolveSignalCore(
        workspace: const GatewayWorkspaceState(),
        session: const ClientSessionState(),
        voice: idleVoice,
        speech: idleSpeech,
      ).state,
      SignalCoreState.idle,
    );
    expect(
      resolveSignalCore(
        workspace: const GatewayWorkspaceState(),
        session: const ClientSessionState(),
        voice: const VoiceSessionState(
          phase: VoiceInputPhase.recording,
          sessionId: 'voice-1',
          audioLevel: 0.7,
        ),
        speech: idleSpeech,
      ).state,
      SignalCoreState.recording,
    );
    expect(
      resolveSignalCore(
        workspace: const GatewayWorkspaceState(),
        session: const ClientSessionState(),
        voice: const VoiceSessionState(
          phase: VoiceInputPhase.transcribing,
          sessionId: 'voice-1',
        ),
        speech: idleSpeech,
      ).state,
      SignalCoreState.transcribing,
    );
    expect(
      resolveSignalCore(
        workspace: const GatewayWorkspaceState(),
        session: const ClientSessionState(draftPhase: DraftPhase.confirmed),
        voice: idleVoice,
        speech: idleSpeech,
      ).state,
      SignalCoreState.awaitingConfirmation,
    );
    expect(
      resolveSignalCore(
        workspace: const GatewayWorkspaceState(),
        session: const ClientSessionState(
          draftPhase: DraftPhase.submitting,
          requestId: 'request-1',
        ),
        voice: idleVoice,
        speech: idleSpeech,
      ).state,
      SignalCoreState.submitting,
    );
    expect(
      _resolveWithEvents([_event(ClientEventKind.agentWorking)]).state,
      SignalCoreState.working,
    );
    expect(
      _resolveWithEvents([
        _event(ClientEventKind.requestCompleted),
      ], speech: _playingSpeech()).state,
      SignalCoreState.speaking,
    );
    expect(
      _resolveWithEvents([_event(ClientEventKind.approvalRequired)]).state,
      SignalCoreState.approval,
    );
    expect(
      _resolveWithEvents([_event(ClientEventKind.requestCompleted)]).state,
      SignalCoreState.completed,
    );
    expect(
      _resolveWithEvents([_event(ClientEventKind.requestFailed)]).state,
      SignalCoreState.failed,
    );
    expect(
      resolveSignalCore(
        workspace: const GatewayWorkspaceState(
          selectedConversationId: 'conversation-1',
          uncertainRequestId: 'request-1',
        ),
        session: const ClientSessionState(),
        voice: idleVoice,
        speech: idleSpeech,
      ).state,
      SignalCoreState.uncertain,
    );
  });

  test('maps Hermes sending and connection phases to working', () {
    final sending = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: idleSpeech,
      hermesConversation: _hermesState(
        HermesConversationPhase.sending,
        messages: [_hermesReply(terminal: DirectMessageTerminal.streaming)],
      ),
    );
    expect(sending.state, SignalCoreState.working);
    expect(sending.label, '助手工作中');
    expect(sending.requestId, 'hermes-reply-1');

    for (final phase in [
      HermesConversationPhase.testing,
      HermesConversationPhase.bootstrapping,
      HermesConversationPhase.restoring,
    ]) {
      final snapshot = resolveSignalCore(
        workspace: const GatewayWorkspaceState(),
        session: const ClientSessionState(),
        voice: idleVoice,
        speech: idleSpeech,
        hermesConversation: _hermesState(phase),
      );
      expect(snapshot.state, SignalCoreState.working);
      expect(
        snapshot.label,
        phase == HermesConversationPhase.testing ? '正在测试连接' : '正在连接 Hermes',
      );
    }
  });

  test('maps Hermes failure and ready terminal states', () {
    final failed = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: idleSpeech,
      hermesConversation: _hermesState(
        HermesConversationPhase.failed,
        failure: const HermesConversationFailure(
          code: 'hermes_test_failure',
          message: 'Safe failure.',
        ),
        messages: [_hermesReply(terminal: DirectMessageTerminal.failed)],
      ),
    );
    expect(failed.state, SignalCoreState.failed);
    expect(failed.label, 'Hermes 请求失败');
    expect(failed.requestId, 'hermes-reply-1');

    final completed = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: idleSpeech,
      hermesConversation: _hermesState(
        HermesConversationPhase.ready,
        messages: [_hermesReply()],
      ),
    );
    expect(completed.state, SignalCoreState.completed);
    expect(completed.requestId, 'hermes-reply-1');

    final idle = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: idleSpeech,
      hermesConversation: _hermesState(HermesConversationPhase.ready),
    );
    expect(idle.state, SignalCoreState.idle);
  });

  test('maps Hermes speech and keeps voice input ahead of Hermes phases', () {
    final speaking = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: _playingSpeech(
        conversationId: 'hermes-conversation-1',
        requestId: 'hermes-reply-1',
      ),
      hermesConversation: _hermesState(
        HermesConversationPhase.ready,
        messages: [_hermesReply()],
      ),
    );
    expect(speaking.state, SignalCoreState.speaking);
    expect(speaking.playbackLevel, 0.63);

    final recording = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: const VoiceSessionState(
        phase: VoiceInputPhase.recording,
        sessionId: 'hermes-voice-1',
        audioLevel: 0.72,
      ),
      speech: idleSpeech,
      hermesConversation: _hermesState(HermesConversationPhase.sending),
    );
    expect(recording.state, SignalCoreState.recording);
    expect(recording.audioLevel, 0.72);
  });

  test('uses safety priority and never turns uncertain into completed', () {
    final snapshot = resolveSignalCore(
      workspace: GatewayWorkspaceState(
        selectedConversationId: 'conversation-1',
        uncertainRequestId: 'request-1',
        events: [
          _event(ClientEventKind.requestCompleted),
          _event(ClientEventKind.approvalRequired, sequence: 2),
        ],
      ),
      session: const ClientSessionState(),
      voice: const VoiceSessionState(
        phase: VoiceInputPhase.recording,
        sessionId: 'voice-1',
        audioLevel: 1,
      ),
      speech: _playingSpeech(),
    );

    expect(snapshot.state, SignalCoreState.approval);
    expect(snapshot.audioLevel, 0);
    expect(snapshot.playbackLevel, 0);
  });

  test('uses only the current speech segment PCM envelope', () {
    final snapshot = _resolveWithEvents([
      _event(ClientEventKind.requestCompleted),
    ], speech: _playingSpeech());

    expect(snapshot.state, SignalCoreState.speaking);
    expect(snapshot.playbackLevel, 0.63);
  });

  test('maps a streaming speech segment to the speaking core state', () {
    final snapshot = _resolveWithEvents([
      _event(ClientEventKind.requestCompleted),
    ], speech: _playingSpeech(phase: SpeechPhase.speakingStreaming));

    expect(snapshot.state, SignalCoreState.speaking);
    expect(snapshot.playbackLevel, 0.63);
  });

  test('resolved interactions no longer retain visual priority', () {
    final required = _event(ClientEventKind.approvalRequired);
    final resolved = _event(ClientEventKind.approvalResolved, sequence: 2);

    expect(
      _resolveWithEvents([required, resolved]).state,
      SignalCoreState.working,
    );
  });

  test('drops stale playback identity after conversation switch', () {
    final snapshot = resolveSignalCore(
      workspace: const GatewayWorkspaceState(
        selectedConversationId: 'conversation-2',
      ),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: _playingSpeech(),
    );

    expect(snapshot.state, SignalCoreState.idle);
    expect(snapshot.playbackLevel, 0);
  });

  test('drops stale speech failure identity after conversation switch', () {
    final snapshot = resolveSignalCore(
      workspace: const GatewayWorkspaceState(
        selectedConversationId: 'conversation-2',
      ),
      session: const ClientSessionState(),
      voice: idleVoice,
      speech: SpeechPlaybackState(
        phase: SpeechPhase.failed,
        segment: SpeechSegment(
          conversationId: 'conversation-1',
          requestId: 'request-1',
          messageRevision: BigInt.one,
          index: 0,
          text: 'Safe speech.',
        ),
        failure: VoiceStageFailure(
          stage: VoiceFailureStage.playback,
          code: 'old_playback_failure',
          safeMessage: 'Old playback failed.',
          retryable: true,
        ),
      ),
    );

    expect(snapshot.state, SignalCoreState.idle);
  });

  test('only exposes current recording level while recording', () {
    final snapshot = resolveSignalCore(
      workspace: const GatewayWorkspaceState(),
      session: const ClientSessionState(),
      voice: const VoiceSessionState(
        phase: VoiceInputPhase.cancelled,
        sessionId: 'stale-voice',
        audioLevel: 0.9,
      ),
      speech: idleSpeech,
    );

    expect(snapshot.state, SignalCoreState.idle);
    expect(snapshot.audioLevel, 0);
  });

  test('current recording overrides a failed previous request', () {
    final snapshot = resolveSignalCore(
      workspace: GatewayWorkspaceState(
        selectedConversationId: 'conversation-1',
        events: [_event(ClientEventKind.requestFailed)],
      ),
      session: const ClientSessionState(),
      voice: const VoiceSessionState(
        phase: VoiceInputPhase.recording,
        sessionId: 'voice-new',
        audioLevel: 0.6,
      ),
      speech: idleSpeech,
    );

    expect(snapshot.state, SignalCoreState.recording);
    expect(snapshot.audioLevel, 0.6);
  });
}

SignalCoreSnapshot _resolveWithEvents(
  List<ClientEventRecord> events, {
  SpeechPlaybackState speech = const SpeechPlaybackState(),
}) => resolveSignalCore(
  workspace: GatewayWorkspaceState(
    selectedConversationId: 'conversation-1',
    events: events,
  ),
  session: const ClientSessionState(),
  voice: const VoiceSessionState(),
  speech: speech,
);

SpeechPlaybackState _playingSpeech({
  SpeechPhase phase = SpeechPhase.playing,
  String conversationId = 'conversation-1',
  String requestId = 'request-1',
}) => SpeechPlaybackState(
  phase: phase,
  playbackLevel: 0.63,
  segment: SpeechSegment(
    conversationId: conversationId,
    requestId: requestId,
    messageRevision: BigInt.one,
    index: 0,
    text: 'Safe test speech.',
  ),
);

HermesConversationState _hermesState(
  HermesConversationPhase phase, {
  List<DirectChatMessage> messages = const [],
  HermesConversationFailure? failure,
}) => HermesConversationState(
  phase: phase,
  configuration: HermesConversationConfiguration(
    providerProfileId: 'hermes-provider-1',
    origin: Uri.parse('https://hermes.example.test'),
    model: 'hermes-model',
    conversationId: 'hermes-conversation-1',
    sessionId: 'hermes-session-1',
    sessionKey: 'hermes-session-key',
  ),
  messages: messages,
  failure: failure,
  credentialAvailable: true,
);

DirectChatMessage _hermesReply({
  DirectMessageTerminal terminal = DirectMessageTerminal.completed,
  int revision = 1,
}) => DirectChatMessage(
  id: 'hermes-reply-1',
  role: DirectChatRole.assistant,
  text: 'Safe Hermes reply.',
  createdAt: DateTime.utc(2030),
  terminal: terminal,
  revision: revision,
);

ClientEventRecord _event(ClientEventKind kind, {int sequence = 1}) {
  final content = switch (kind) {
    ClientEventKind.approvalRequired ||
    ClientEventKind.approvalResolved ||
    ClientEventKind.approvalExpired ||
    ClientEventKind.approvalCancelled => ApprovalClientEventContent(
      approvalId: 'approval-1',
      safeSummary: 'Safe operation summary.',
      operationSummarySha256: ''.padLeft(64, 'a'),
      expiresAt: DateTime.utc(2035),
    ),
    ClientEventKind.clarificationRequired ||
    ClientEventKind.clarificationResolved ||
    ClientEventKind.clarificationExpired ||
    ClientEventKind.clarificationCancelled => ClarificationClientEventContent(
      clarificationId: 'clarification-1',
      safePrompt: 'Safe clarification prompt.',
      expiresAt: DateTime.utc(2035),
    ),
    ClientEventKind.requestCompleted ||
    ClientEventKind.requestFailed ||
    ClientEventKind.requestCancelled ||
    ClientEventKind.requestInterrupted => const TerminalClientEventContent(
      null,
    ),
    _ => const SafeMessageClientEventContent('Safe event.'),
  };
  return ClientEventRecord(
    eventId: 'event-$sequence',
    connectionId: 'connection-1',
    originDeviceId: 'device-1',
    conversationId: 'conversation-1',
    requestId: 'request-1',
    sequence: BigInt.from(sequence),
    occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
    kind: kind,
    content: content,
    envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
  );
}
