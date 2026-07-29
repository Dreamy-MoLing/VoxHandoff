import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/conversation_timeline.dart';
import 'package:agent_talk_client/domain/gateway_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates deltas, final reply, and tool facts into one user turn', () {
    final events = [
      _event(1, ClientEventKind.requestAccepted),
      _message(2, ClientEventKind.messageDelta, 'Hel', 1),
      _tool(3, ClientEventKind.toolStarted, 'terminal', 'Started.'),
      _message(4, ClientEventKind.messageDelta, 'lo', 2),
      _tool(5, ClientEventKind.toolCompleted, 'terminal', 'Completed.'),
      _message(6, ClientEventKind.messageCompleted, 'Hello', 3),
      _event(7, ClientEventKind.requestCompleted),
    ];

    final turns = aggregateConversationTurns(events);

    expect(turns, hasLength(1));
    expect(turns.single.userText, 'Run the verified task.');
    expect(turns.single.assistantText, 'Hello');
    expect(turns.single.tools, hasLength(1));
    expect(turns.single.tools.single.state, ToolTraceState.completed);
    expect(turns.single.isTerminal, isTrue);
    expect(turns.single.canInterrupt, isFalse);
  });

  test('never selects an earlier message event as an active request', () {
    final complete = aggregateConversationTurns([
      _event(1, ClientEventKind.requestAccepted),
      _message(2, ClientEventKind.messageCompleted, 'Done', 1),
      _event(3, ClientEventKind.requestCompleted),
    ]);
    final workspace = GatewayWorkspaceState(
      selectedConversationId: 'conversation-1',
      events: complete.single.events,
      turns: complete,
    );

    expect(workspace.activeTurn, isNull);
  });

  test('resolves an approval inside its own turn', () {
    final required = _approval(2, ClientEventKind.approvalRequired);
    final resolved = _approval(3, ClientEventKind.approvalResolved);
    final turns = aggregateConversationTurns([
      _event(1, ClientEventKind.requestAccepted),
      required,
      resolved,
    ]);

    expect(turns.single.pendingInteraction, isNull);
  });
}

ClientEventRecord _event(int sequence, ClientEventKind kind) =>
    ClientEventRecord(
      eventId: 'event-$sequence',
      connectionId: 'connection-1',
      originDeviceId: 'device-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
      sequence: BigInt.from(sequence),
      occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
      kind: kind,
      content: switch (kind) {
        ClientEventKind.requestCompleted ||
        ClientEventKind.requestFailed ||
        ClientEventKind.requestCancelled ||
        ClientEventKind.requestInterrupted => const TerminalClientEventContent(
          null,
        ),
        ClientEventKind.requestAccepted => const SafeMessageClientEventContent(
          'Safe progress.',
          confirmedText: 'Run the verified task.',
        ),
        _ => const SafeMessageClientEventContent('Safe progress.'),
      },
      envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
    );

ClientEventRecord _message(
  int sequence,
  ClientEventKind kind,
  String text,
  int revision,
) => ClientEventRecord(
  eventId: 'event-$sequence',
  connectionId: 'connection-1',
  originDeviceId: 'device-1',
  conversationId: 'conversation-1',
  requestId: 'request-1',
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
  kind: kind,
  content: MessageClientEventContent(
    text: text,
    revision: BigInt.from(revision),
  ),
  envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
);

ClientEventRecord _tool(
  int sequence,
  ClientEventKind kind,
  String name,
  String summary,
) => ClientEventRecord(
  eventId: 'event-$sequence',
  connectionId: 'connection-1',
  originDeviceId: 'device-1',
  conversationId: 'conversation-1',
  requestId: 'request-1',
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
  kind: kind,
  content: ToolClientEventContent(
    toolName: name,
    stage: kind.name,
    safeSummary: summary,
  ),
  envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
);

ClientEventRecord _approval(int sequence, ClientEventKind kind) =>
    ClientEventRecord(
      eventId: 'event-$sequence',
      connectionId: 'connection-1',
      originDeviceId: 'device-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
      sequence: BigInt.from(sequence),
      occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
      kind: kind,
      content: ApprovalClientEventContent(
        approvalId: 'approval-1',
        safeSummary: 'Safe approval.',
        operationSummarySha256: 'a' * 64,
        expiresAt: DateTime.utc(2035),
      ),
      envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
    );
