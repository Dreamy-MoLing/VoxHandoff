import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:cryptography/cryptography.dart';
import 'package:fixnum/fixnum.dart';

import '../../domain/client_event.dart';

class GatewayEventMappingException implements Exception {
  const GatewayEventMappingException({
    required this.code,
    required this.safeMessage,
  });

  final String code;
  final String safeMessage;

  @override
  String toString() => 'GatewayEventMappingException(code: $code)';
}

class GatewayEventMapper {
  GatewayEventMapper({Sha256? sha256}) : _sha256 = sha256 ?? Sha256();

  static const maximumEnvelopeBytes = 1024 * 1024;

  final Sha256 _sha256;

  Future<ClientEventRecord> map(EventEnvelope envelope) async {
    try {
      return await _mapValidated(envelope);
    } on GatewayEventMappingException {
      rethrow;
    } on Object {
      throw const GatewayEventMappingException(
        code: 'event_envelope_invalid',
        safeMessage: 'The Gateway event envelope could not be decoded.',
      );
    }
  }

  Future<ClientEventRecord> _mapValidated(EventEnvelope envelope) async {
    final bytes = envelope.writeToBuffer();
    if (bytes.length > maximumEnvelopeBytes) {
      throw const GatewayEventMappingException(
        code: 'event_too_large',
        safeMessage: 'The Gateway event exceeds the supported size.',
      );
    }
    if (!envelope.hasProtocol() ||
        envelope.protocol.major != 1 ||
        envelope.protocol.minor != 0 ||
        !envelope.hasEvent() ||
        !envelope.hasOccurredAt() ||
        envelope.sequence == 0) {
      throw const GatewayEventMappingException(
        code: 'event_envelope_invalid',
        safeMessage: 'The Gateway event envelope is incomplete.',
      );
    }

    final mapped = _mapEvent(envelope.event);
    final digest = await _sha256.hash(bytes);
    try {
      return ClientEventRecord(
        eventId: envelope.eventId,
        connectionId: envelope.connectionId,
        originDeviceId: envelope.deviceId,
        conversationId: envelope.conversationId,
        sessionId: _optionalOpaque(envelope.sessionId),
        requestId: envelope.requestId,
        sequence: BigInt.parse(envelope.sequence.toStringUnsigned()),
        occurredAt: _timestamp(
          envelope.occurredAt.seconds,
          envelope.occurredAt.nanos,
        ),
        kind: mapped.kind,
        content: mapped.content,
        envelopeSha256: _hex(digest.bytes),
      );
    } on FormatException {
      throw const GatewayEventMappingException(
        code: 'event_identity_invalid',
        safeMessage: 'The Gateway event identity is invalid.',
      );
    } on Object {
      throw const GatewayEventMappingException(
        code: 'event_envelope_invalid',
        safeMessage: 'The Gateway event envelope could not be decoded.',
      );
    }
  }

  _MappedEvent _mapEvent(AgentEvent event) {
    final type = event.type;
    return switch (type.value) {
      0 => _unsupported(event),
      1 => _safeMessage(
        event,
        AgentEvent_Payload.connection,
        ClientEventKind.connectionReady,
        event.connection.safeMessage,
      ),
      2 => _safeMessage(
        event,
        AgentEvent_Payload.connection,
        ClientEventKind.connectionLost,
        event.connection.safeMessage,
      ),
      3 => _safeMessage(
        event,
        AgentEvent_Payload.requestProgress,
        ClientEventKind.requestAccepted,
        event.requestProgress.safeMessage,
      ),
      4 => _safeMessage(
        event,
        AgentEvent_Payload.requestProgress,
        ClientEventKind.agentWorking,
        event.requestProgress.safeMessage,
      ),
      5 => _safeMessage(
        event,
        AgentEvent_Payload.requestProgress,
        ClientEventKind.requestInterrupting,
        event.requestProgress.safeMessage,
      ),
      6 => _message(event, ClientEventKind.messageDelta),
      7 => _message(event, ClientEventKind.messageCompleted),
      8 => _tool(event, ClientEventKind.toolStarted),
      9 => _tool(event, ClientEventKind.toolCompleted),
      10 => _tool(event, ClientEventKind.toolFailed),
      11 => _approval(event, ClientEventKind.approvalRequired),
      12 => _approval(event, ClientEventKind.approvalResolved),
      13 => _approval(event, ClientEventKind.approvalExpired),
      14 => _approval(event, ClientEventKind.approvalCancelled),
      15 => _clarification(event, ClientEventKind.clarificationRequired),
      16 => _clarification(event, ClientEventKind.clarificationResolved),
      17 => _clarification(event, ClientEventKind.clarificationExpired),
      18 => _clarification(event, ClientEventKind.clarificationCancelled),
      19 => _terminal(event, ClientEventKind.requestCompleted),
      20 => _terminal(event, ClientEventKind.requestFailed),
      21 => _terminal(event, ClientEventKind.requestCancelled),
      22 => _terminal(event, ClientEventKind.requestInterrupted),
      _ => throw const GatewayEventMappingException(
        code: 'event_type_unknown',
        safeMessage: 'The Gateway event type requires a protocol upgrade.',
      ),
    };
  }

  _MappedEvent _safeMessage(
    AgentEvent event,
    AgentEvent_Payload expectedPayload,
    ClientEventKind kind,
    String safeMessage,
  ) {
    _expectPayload(event, expectedPayload);
    return _MappedEvent(kind, SafeMessageClientEventContent(safeMessage));
  }

  _MappedEvent _message(AgentEvent event, ClientEventKind kind) {
    _expectPayload(event, AgentEvent_Payload.message);
    return _MappedEvent(
      kind,
      MessageClientEventContent(
        text: event.message.text,
        revision: BigInt.parse(event.message.revision.toStringUnsigned()),
      ),
    );
  }

  _MappedEvent _tool(AgentEvent event, ClientEventKind kind) {
    _expectPayload(event, AgentEvent_Payload.tool);
    return _MappedEvent(
      kind,
      ToolClientEventContent(
        toolName: event.tool.toolName,
        stage: event.tool.stage,
        safeSummary: event.tool.safeSummary,
      ),
    );
  }

  _MappedEvent _approval(AgentEvent event, ClientEventKind kind) {
    _expectPayload(event, AgentEvent_Payload.approval);
    if (!event.approval.hasExpiresAt() ||
        !_opaque(event.approval.approvalId) ||
        !RegExp(
          r'^[0-9a-f]{64}$',
        ).hasMatch(event.approval.operationSummarySha256)) {
      throw const GatewayEventMappingException(
        code: 'approval_event_invalid',
        safeMessage: 'The approval event is incomplete.',
      );
    }
    return _MappedEvent(
      kind,
      ApprovalClientEventContent(
        approvalId: event.approval.approvalId,
        safeSummary: event.approval.safeSummary,
        operationSummarySha256: event.approval.operationSummarySha256,
        expiresAt: _timestamp(
          event.approval.expiresAt.seconds,
          event.approval.expiresAt.nanos,
        ),
      ),
    );
  }

  _MappedEvent _clarification(AgentEvent event, ClientEventKind kind) {
    _expectPayload(event, AgentEvent_Payload.clarification);
    if (!event.clarification.hasExpiresAt() ||
        !_opaque(event.clarification.clarificationId)) {
      throw const GatewayEventMappingException(
        code: 'clarification_event_invalid',
        safeMessage: 'The clarification event is incomplete.',
      );
    }
    return _MappedEvent(
      kind,
      ClarificationClientEventContent(
        clarificationId: event.clarification.clarificationId,
        safePrompt: event.clarification.safePrompt,
        expiresAt: _timestamp(
          event.clarification.expiresAt.seconds,
          event.clarification.expiresAt.nanos,
        ),
      ),
    );
  }

  _MappedEvent _terminal(AgentEvent event, ClientEventKind kind) {
    _expectPayload(event, AgentEvent_Payload.requestTerminal);
    final terminal = event.requestTerminal;
    if (kind == ClientEventKind.requestFailed && !terminal.hasFailure()) {
      throw const GatewayEventMappingException(
        code: 'terminal_event_invalid',
        safeMessage: 'The failed request event has no failure fact.',
      );
    }
    return _MappedEvent(
      kind,
      TerminalClientEventContent(
        terminal.hasFailure() ? _failure(terminal.failure) : null,
      ),
    );
  }

  _MappedEvent _unsupported(AgentEvent event) {
    _expectPayload(event, AgentEvent_Payload.unsupported);
    return _MappedEvent(
      ClientEventKind.unsupported,
      UnsupportedClientEventContent(
        nativeTypeNumber: event.unsupported.nativeTypeNumber,
        safeMessage: event.unsupported.safeMessage,
      ),
    );
  }

  ClientStageFailure _failure(StageFailure failure) => ClientStageFailure(
    stage: _failureStage(failure.stage.value),
    category: _failureCategory(failure.category.value),
    code: failure.code,
    safeMessage: failure.safeMessage,
    retryable: failure.retryable,
  );

  ClientFailureStage _failureStage(int value) => switch (value) {
    0 => ClientFailureStage.unspecified,
    1 => ClientFailureStage.recording,
    2 => ClientFailureStage.stt,
    3 => ClientFailureStage.connection,
    4 => ClientFailureStage.authentication,
    5 => ClientFailureStage.authorization,
    6 => ClientFailureStage.protocol,
    7 => ClientFailureStage.agent,
    8 => ClientFailureStage.summary,
    9 => ClientFailureStage.tts,
    10 => ClientFailureStage.playback,
    11 => ClientFailureStage.storage,
    12 => ClientFailureStage.sync,
    13 => ClientFailureStage.configuration,
    _ => throw const GatewayEventMappingException(
      code: 'failure_stage_unknown',
      safeMessage: 'The failure stage requires a protocol upgrade.',
    ),
  };

  ClientFailureCategory _failureCategory(int value) => switch (value) {
    0 => ClientFailureCategory.unspecified,
    1 => ClientFailureCategory.validation,
    2 => ClientFailureCategory.unavailable,
    3 => ClientFailureCategory.authentication,
    4 => ClientFailureCategory.authorization,
    5 => ClientFailureCategory.protocol,
    6 => ClientFailureCategory.timeout,
    7 => ClientFailureCategory.rateLimit,
    8 => ClientFailureCategory.upstream,
    9 => ClientFailureCategory.storage,
    10 => ClientFailureCategory.privacy,
    11 => ClientFailureCategory.unknown,
    _ => throw const GatewayEventMappingException(
      code: 'failure_category_unknown',
      safeMessage: 'The failure category requires a protocol upgrade.',
    ),
  };

  void _expectPayload(AgentEvent event, AgentEvent_Payload expected) {
    if (event.whichPayload() != expected) {
      throw const GatewayEventMappingException(
        code: 'event_payload_mismatch',
        safeMessage: 'The Gateway event payload does not match its type.',
      );
    }
  }

  DateTime _timestamp(Int64 seconds, int nanos) {
    if (seconds < Int64(-62135596800) ||
        seconds > Int64(253402300799) ||
        nanos < 0 ||
        nanos > 999999999) {
      throw const GatewayEventMappingException(
        code: 'event_timestamp_invalid',
        safeMessage: 'The Gateway event timestamp is invalid.',
      );
    }
    try {
      return DateTime.fromMicrosecondsSinceEpoch(
        seconds.toInt() * Duration.microsecondsPerSecond + nanos ~/ 1000,
        isUtc: true,
      );
    } on Object {
      throw const GatewayEventMappingException(
        code: 'event_timestamp_invalid',
        safeMessage: 'The Gateway event timestamp is invalid.',
      );
    }
  }

  String? _optionalOpaque(String value) {
    if (value.isEmpty) return null;
    if (!_opaque(value)) {
      throw const GatewayEventMappingException(
        code: 'event_identity_invalid',
        safeMessage: 'The Gateway event identity is invalid.',
      );
    }
    return value;
  }

  bool _opaque(String value) =>
      value.isNotEmpty &&
      value.length <= 256 &&
      !value.contains(RegExp(r'[\u0000-\u001f\u007f]'));

  String _hex(List<int> bytes) =>
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

class _MappedEvent {
  const _MappedEvent(this.kind, this.content);

  final ClientEventKind kind;
  final ClientEventContent content;
}
