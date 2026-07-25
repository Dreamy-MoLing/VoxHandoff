import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/client_session.dart';
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

SpeechPlaybackState _playingSpeech() => SpeechPlaybackState(
  phase: SpeechPhase.playing,
  segment: SpeechSegment(
    conversationId: 'conversation-1',
    requestId: 'request-1',
    messageRevision: BigInt.one,
    index: 0,
    text: 'Safe test speech.',
  ),
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
