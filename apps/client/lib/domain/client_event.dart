enum ClientEventKind {
  connectionReady,
  connectionLost,
  requestAccepted,
  agentWorking,
  requestInterrupting,
  messageDelta,
  messageCompleted,
  toolStarted,
  toolCompleted,
  toolFailed,
  approvalRequired,
  approvalResolved,
  approvalExpired,
  approvalCancelled,
  clarificationRequired,
  clarificationResolved,
  clarificationExpired,
  clarificationCancelled,
  requestCompleted,
  requestFailed,
  requestCancelled,
  requestInterrupted,
  unsupported,
}

sealed class ClientEventContent {
  const ClientEventContent();
}

class EmptyClientEventContent extends ClientEventContent {
  const EmptyClientEventContent();
}

class SafeMessageClientEventContent extends ClientEventContent {
  const SafeMessageClientEventContent(this.safeMessage);

  final String safeMessage;
}

class MessageClientEventContent extends ClientEventContent {
  const MessageClientEventContent({required this.text, required this.revision});

  final String text;
  final BigInt revision;
}

class ToolClientEventContent extends ClientEventContent {
  const ToolClientEventContent({
    required this.toolName,
    required this.stage,
    required this.safeSummary,
  });

  final String toolName;
  final String stage;
  final String safeSummary;
}

class ApprovalClientEventContent extends ClientEventContent {
  const ApprovalClientEventContent({
    required this.approvalId,
    required this.safeSummary,
    required this.operationSummarySha256,
    required this.expiresAt,
  });

  final String approvalId;
  final String safeSummary;
  final String operationSummarySha256;
  final DateTime expiresAt;
}

class ClarificationClientEventContent extends ClientEventContent {
  const ClarificationClientEventContent({
    required this.clarificationId,
    required this.safePrompt,
    required this.expiresAt,
  });

  final String clarificationId;
  final String safePrompt;
  final DateTime expiresAt;
}

enum ClientFailureStage {
  unspecified,
  recording,
  stt,
  connection,
  authentication,
  authorization,
  protocol,
  agent,
  summary,
  tts,
  playback,
  storage,
  sync,
  configuration,
}

enum ClientFailureCategory {
  unspecified,
  validation,
  unavailable,
  authentication,
  authorization,
  protocol,
  timeout,
  rateLimit,
  upstream,
  storage,
  privacy,
  unknown,
}

class ClientStageFailure {
  const ClientStageFailure({
    required this.stage,
    required this.category,
    required this.code,
    required this.safeMessage,
    required this.retryable,
  });

  final ClientFailureStage stage;
  final ClientFailureCategory category;
  final String code;
  final String safeMessage;
  final bool retryable;
}

class TerminalClientEventContent extends ClientEventContent {
  const TerminalClientEventContent(this.failure);

  final ClientStageFailure? failure;
}

class UnsupportedClientEventContent extends ClientEventContent {
  const UnsupportedClientEventContent({
    required this.nativeTypeNumber,
    required this.safeMessage,
  });

  final int nativeTypeNumber;
  final String safeMessage;
}

class ClientEventRecord {
  ClientEventRecord({
    required this.eventId,
    required this.connectionId,
    required this.deviceId,
    required this.conversationId,
    required this.sequence,
    required this.occurredAt,
    required this.kind,
    required this.content,
    required this.envelopeSha256,
    this.sessionId,
    this.requestId,
  }) {
    if (!_opaque(eventId) ||
        !_opaque(connectionId) ||
        !_opaque(deviceId) ||
        !_opaque(conversationId) ||
        (sessionId != null && !_opaque(sessionId!)) ||
        (requestId != null && !_opaque(requestId!)) ||
        sequence <= BigInt.zero ||
        sequence > _maximumUint64 ||
        !occurredAt.isUtc ||
        !_contentMatchesKind(kind, content) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(envelopeSha256)) {
      throw const FormatException('The Client event fact is invalid.');
    }
  }

  static final BigInt _maximumUint64 = (BigInt.one << 64) - BigInt.one;

  final String eventId;
  final String connectionId;
  final String deviceId;
  final String conversationId;
  final String? sessionId;
  final String? requestId;
  final BigInt sequence;
  final DateTime occurredAt;
  final ClientEventKind kind;
  final ClientEventContent content;
  final String envelopeSha256;

  bool samePersistedFact(ClientEventRecord other) =>
      eventId == other.eventId &&
      connectionId == other.connectionId &&
      deviceId == other.deviceId &&
      conversationId == other.conversationId &&
      sessionId == other.sessionId &&
      requestId == other.requestId &&
      sequence == other.sequence &&
      occurredAt == other.occurredAt &&
      kind == other.kind &&
      envelopeSha256 == other.envelopeSha256;
}

class TrackedClientRequest {
  TrackedClientRequest({
    required this.deviceId,
    required this.conversationId,
    required this.requestId,
    this.sessionId,
  }) {
    if (!_opaque(deviceId) ||
        !_opaque(conversationId) ||
        !_opaque(requestId) ||
        (sessionId != null && !_opaque(sessionId!))) {
      throw const FormatException('The tracked Client request is invalid.');
    }
  }

  final String deviceId;
  final String conversationId;
  final String? sessionId;
  final String requestId;
}

class ConversationEventCursor {
  ConversationEventCursor({
    required this.conversationId,
    required this.sequence,
    required this.eventId,
  }) {
    if (!_opaque(conversationId) ||
        sequence <= BigInt.zero ||
        sequence > ClientEventRecord._maximumUint64 ||
        !_opaque(eventId)) {
      throw const FormatException('The conversation cursor is invalid.');
    }
  }

  final String conversationId;
  final BigInt sequence;
  final String eventId;
}

abstract interface class ClientEventLedger {
  Future<TrackedClientRequest?> readRequest(String requestId);

  Future<ConversationEventCursor?> readCursor(String conversationId);

  Future<ClientEventRecord?> readEvent(String conversationId, BigInt sequence);

  /// Atomically stores the complete event and advances its conversation cursor.
  /// Implementations must reject a cursor other than [expectedPreviousSequence].
  Future<void> commitNextEvent(
    ClientEventRecord event, {
    required BigInt expectedPreviousSequence,
  });
}

bool _opaque(String value) =>
    value.isNotEmpty &&
    value.length <= 256 &&
    !value.contains(RegExp(r'[\u0000-\u001f\u007f]'));

bool _contentMatchesKind(
  ClientEventKind kind,
  ClientEventContent content,
) => switch (kind) {
  ClientEventKind.connectionReady ||
  ClientEventKind.connectionLost ||
  ClientEventKind.requestAccepted ||
  ClientEventKind.agentWorking ||
  ClientEventKind.requestInterrupting =>
    content is SafeMessageClientEventContent,
  ClientEventKind.messageDelta ||
  ClientEventKind.messageCompleted => content is MessageClientEventContent,
  ClientEventKind.toolStarted ||
  ClientEventKind.toolCompleted ||
  ClientEventKind.toolFailed => content is ToolClientEventContent,
  ClientEventKind.approvalRequired ||
  ClientEventKind.approvalResolved ||
  ClientEventKind.approvalExpired ||
  ClientEventKind.approvalCancelled => content is ApprovalClientEventContent,
  ClientEventKind.clarificationRequired ||
  ClientEventKind.clarificationResolved ||
  ClientEventKind.clarificationExpired ||
  ClientEventKind.clarificationCancelled =>
    content is ClarificationClientEventContent,
  ClientEventKind.requestCompleted ||
  ClientEventKind.requestFailed ||
  ClientEventKind.requestCancelled ||
  ClientEventKind.requestInterrupted => content is TerminalClientEventContent,
  ClientEventKind.unsupported => content is UnsupportedClientEventContent,
};
