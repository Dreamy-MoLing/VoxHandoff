import 'client_event.dart';

enum ToolTraceState { running, completed, failed }

class ToolTrace {
  const ToolTrace({
    required this.toolName,
    required this.safeSummary,
    required this.state,
  });

  final String toolName;
  final String safeSummary;
  final ToolTraceState state;
}

class ConversationTurn {
  const ConversationTurn({
    required this.requestId,
    required this.events,
    required this.userText,
    required this.assistantText,
    required this.messageRevision,
    required this.tools,
    required this.pendingInteraction,
    required this.terminalEvent,
  });

  final String requestId;
  final List<ClientEventRecord> events;
  final String? userText;
  final String assistantText;
  final BigInt messageRevision;
  final List<ToolTrace> tools;
  final ClientEventRecord? pendingInteraction;
  final ClientEventRecord? terminalEvent;

  ClientEventRecord get firstEvent => events.first;
  ClientEventRecord get latestEvent => events.last;
  bool get isTerminal => terminalEvent != null;
  bool get canInterrupt => !isTerminal && events.any(_marksActiveRequest);
  bool get isFailed => terminalEvent?.kind == ClientEventKind.requestFailed;

  ConversationTurn append(ClientEventRecord event) =>
      _buildTurn([...events, event]);
}

List<ConversationTurn> aggregateConversationTurns(
  List<ClientEventRecord> events,
) {
  final turns = <ConversationTurn>[];
  for (final event in events) {
    if (turns.isNotEmpty && turns.last.requestId == event.requestId) {
      turns[turns.length - 1] = turns.last.append(event);
    } else {
      turns.add(_buildTurn([event]));
    }
  }
  return List.unmodifiable(turns);
}

List<ConversationTurn> appendConversationTurnEvent(
  List<ConversationTurn> turns,
  ClientEventRecord event,
) {
  if (turns.isEmpty || turns.last.requestId != event.requestId) {
    return List.unmodifiable([
      ...turns,
      _buildTurn([event]),
    ]);
  }
  return List.unmodifiable([
    ...turns.take(turns.length - 1),
    turns.last.append(event),
  ]);
}

ConversationTurn _buildTurn(List<ClientEventRecord> events) {
  var assistantText = '';
  String? userText;
  var messageRevision = BigInt.zero;
  final tools = <ToolTrace>[];
  ClientEventRecord? terminalEvent;

  for (final event in events) {
    final content = event.content;
    if (event.kind == ClientEventKind.requestAccepted &&
        content is SafeMessageClientEventContent &&
        content.confirmedText != null) {
      userText = content.confirmedText;
    } else if (content is MessageClientEventContent) {
      if (event.kind == ClientEventKind.messageCompleted) {
        if (content.revision >= messageRevision) {
          assistantText = content.text;
          messageRevision = content.revision;
        }
      } else if (event.kind == ClientEventKind.messageDelta &&
          content.revision >= messageRevision) {
        assistantText += content.text;
        messageRevision = content.revision;
      }
    } else if (content is ToolClientEventContent) {
      final state = switch (event.kind) {
        ClientEventKind.toolCompleted => ToolTraceState.completed,
        ClientEventKind.toolFailed => ToolTraceState.failed,
        _ => ToolTraceState.running,
      };
      final openIndex = tools.lastIndexWhere(
        (tool) =>
            tool.toolName == content.toolName &&
            tool.state == ToolTraceState.running,
      );
      final trace = ToolTrace(
        toolName: content.toolName,
        safeSummary: content.safeSummary,
        state: state,
      );
      if (openIndex >= 0 && state != ToolTraceState.running) {
        tools[openIndex] = trace;
      } else {
        tools.add(trace);
      }
    }
    if (_terminalKinds.contains(event.kind)) terminalEvent = event;
  }

  return ConversationTurn(
    requestId: events.first.requestId,
    events: List.unmodifiable(events),
    userText: userText,
    assistantText: assistantText,
    messageRevision: messageRevision,
    tools: List.unmodifiable(tools),
    pendingInteraction: _latestPendingInteraction(events),
    terminalEvent: terminalEvent,
  );
}

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

bool _marksActiveRequest(ClientEventRecord event) =>
    event.kind != ClientEventKind.connectionReady &&
    event.kind != ClientEventKind.connectionLost &&
    !_terminalKinds.contains(event.kind);

const _terminalKinds = {
  ClientEventKind.requestCompleted,
  ClientEventKind.requestFailed,
  ClientEventKind.requestCancelled,
  ClientEventKind.requestInterrupted,
};
