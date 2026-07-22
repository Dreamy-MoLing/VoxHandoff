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
    required this.originDeviceId,
    required this.conversationId,
    required this.requestId,
    required this.sequence,
    required this.occurredAt,
    required this.kind,
    required this.content,
    required this.envelopeSha256,
    this.sessionId,
  }) {
    if (!_opaque(eventId) ||
        !_opaque(connectionId) ||
        !_opaque(originDeviceId) ||
        !_opaque(conversationId) ||
        (sessionId != null && !_opaque(sessionId!)) ||
        !_opaque(requestId) ||
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
  final String originDeviceId;
  final String conversationId;
  final String? sessionId;
  final String requestId;
  final BigInt sequence;
  final DateTime occurredAt;
  final ClientEventKind kind;
  final ClientEventContent content;
  final String envelopeSha256;

  bool samePersistedFact(ClientEventRecord other) =>
      eventId == other.eventId &&
      connectionId == other.connectionId &&
      originDeviceId == other.originDeviceId &&
      conversationId == other.conversationId &&
      sessionId == other.sessionId &&
      requestId == other.requestId &&
      sequence == other.sequence &&
      occurredAt == other.occurredAt &&
      kind == other.kind &&
      _sameClientEventContent(content, other.content) &&
      envelopeSha256 == other.envelopeSha256;
}

class TrackedClientRequest {
  TrackedClientRequest({
    required this.originDeviceId,
    required this.conversationId,
    required this.requestId,
    required this.nodeId,
    required this.agentId,
    required this.capabilityRevision,
    this.sessionId,
    this.acceptedSequence,
  }) {
    if (!_opaque(originDeviceId) ||
        !_opaque(conversationId) ||
        !_opaque(requestId) ||
        !_opaque(nodeId) ||
        !_opaque(agentId) ||
        !_opaque(capabilityRevision) ||
        (sessionId != null && !_opaque(sessionId!)) ||
        (acceptedSequence != null &&
            (acceptedSequence! <= BigInt.zero ||
                acceptedSequence! > ClientEventRecord._maximumUint64))) {
      throw const FormatException('The tracked Client request is invalid.');
    }
  }

  final String originDeviceId;
  final String conversationId;
  final String? sessionId;
  final String requestId;
  final String nodeId;
  final String agentId;
  final String capabilityRevision;
  final BigInt? acceptedSequence;
}

enum LocalClientSubmissionDisposition {
  prepared,
  outcomeUnknown,
  accepted,
  rejected,
}

class LocalClientSubmission {
  LocalClientSubmission({
    required this.requestId,
    required this.originDeviceId,
    required this.commandId,
    required this.idempotencyKey,
    required this.confirmedTextSha256,
    required this.disposition,
  }) {
    if (!_opaque(requestId) ||
        !_opaque(originDeviceId) ||
        !_opaque(commandId) ||
        !_opaque(idempotencyKey) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(confirmedTextSha256)) {
      throw const FormatException('The local Client submission is invalid.');
    }
  }

  final String requestId;
  final String originDeviceId;
  final String commandId;
  final String idempotencyKey;
  final String confirmedTextSha256;
  final LocalClientSubmissionDisposition disposition;
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
  /// Records a request route before accepting any event for that request.
  /// Implementations may enrich a null accepted sequence exactly once, but
  /// must reject every other route or acceptance fact conflict.
  Future<void> trackRequest(TrackedClientRequest request);

  /// Atomically prepares a local route and submission without retaining the
  /// confirmed text. Remote snapshots use [trackRequest] instead.
  Future<void> prepareLocalSubmission(
    TrackedClientRequest route,
    LocalClientSubmission submission,
  );

  Future<LocalClientSubmission?> readLocalSubmission(String requestId);

  /// Advances a local submission with compare-and-set semantics. Backward or
  /// otherwise unsafe transitions must fail closed.
  Future<void> advanceLocalSubmission(
    String requestId, {
    required LocalClientSubmissionDisposition expectedDisposition,
    required LocalClientSubmissionDisposition nextDisposition,
  });

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

bool _sameClientEventContent(
  ClientEventContent left,
  ClientEventContent right,
) {
  if (left is EmptyClientEventContent && right is EmptyClientEventContent) {
    return true;
  }
  if (left is SafeMessageClientEventContent &&
      right is SafeMessageClientEventContent) {
    return left.safeMessage == right.safeMessage;
  }
  if (left is MessageClientEventContent && right is MessageClientEventContent) {
    return left.text == right.text && left.revision == right.revision;
  }
  if (left is ToolClientEventContent && right is ToolClientEventContent) {
    return left.toolName == right.toolName &&
        left.stage == right.stage &&
        left.safeSummary == right.safeSummary;
  }
  if (left is ApprovalClientEventContent &&
      right is ApprovalClientEventContent) {
    return left.approvalId == right.approvalId &&
        left.safeSummary == right.safeSummary &&
        left.operationSummarySha256 == right.operationSummarySha256 &&
        left.expiresAt == right.expiresAt;
  }
  if (left is ClarificationClientEventContent &&
      right is ClarificationClientEventContent) {
    return left.clarificationId == right.clarificationId &&
        left.safePrompt == right.safePrompt &&
        left.expiresAt == right.expiresAt;
  }
  if (left is TerminalClientEventContent &&
      right is TerminalClientEventContent) {
    return _sameClientStageFailure(left.failure, right.failure);
  }
  if (left is UnsupportedClientEventContent &&
      right is UnsupportedClientEventContent) {
    return left.nativeTypeNumber == right.nativeTypeNumber &&
        left.safeMessage == right.safeMessage;
  }
  return false;
}

bool _sameClientStageFailure(
  ClientStageFailure? left,
  ClientStageFailure? right,
) {
  if (left == null || right == null) return left == right;
  return left.stage == right.stage &&
      left.category == right.category &&
      left.code == right.code &&
      left.safeMessage == right.safeMessage &&
      left.retryable == right.retryable;
}
