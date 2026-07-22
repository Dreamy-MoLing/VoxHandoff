import '../domain/client_event.dart';

sealed class ClientEventConvergenceResult {
  const ClientEventConvergenceResult();
}

class ClientEventCommitted extends ClientEventConvergenceResult {
  const ClientEventCommitted({
    required this.event,
    required this.acknowledgement,
  });

  final ClientEventRecord event;
  final ClientEventAcknowledgement acknowledgement;
}

class ClientEventDuplicate extends ClientEventConvergenceResult {
  const ClientEventDuplicate(this.acknowledgement);

  final ClientEventAcknowledgement acknowledgement;
}

class ClientEventGap extends ClientEventConvergenceResult {
  const ClientEventGap(this.replay);

  final ClientReplayDirective replay;
}

class ClientEventAcknowledgement {
  const ClientEventAcknowledgement({
    required this.conversationId,
    required this.sequence,
    required this.eventId,
  });

  final String conversationId;
  final BigInt sequence;
  final String eventId;
}

class ClientReplayDirective {
  const ClientReplayDirective({
    required this.conversationId,
    required this.afterSequence,
    this.maximumEvents = 500,
  });

  final String conversationId;
  final BigInt afterSequence;
  final int maximumEvents;
}

class ClientEventConvergenceException implements Exception {
  const ClientEventConvergenceException({
    required this.code,
    required this.safeMessage,
  });

  final String code;
  final String safeMessage;

  @override
  String toString() => 'ClientEventConvergenceException(code: $code)';
}

class ClientEventConvergence {
  factory ClientEventConvergence({required ClientEventLedger ledger}) =>
      ClientEventConvergence._(ledger);

  const ClientEventConvergence._(this._ledger);

  final ClientEventLedger _ledger;

  Future<ClientEventConvergenceResult> accept(ClientEventRecord event) async {
    await _verifyRequestRoute(event);

    final cursor = await _readCursor(event.conversationId);
    final previousSequence = cursor?.sequence ?? BigInt.zero;
    if (event.sequence <= previousSequence) {
      return _duplicateOrConflict(event);
    }
    if (event.sequence != previousSequence + BigInt.one) {
      return ClientEventGap(
        ClientReplayDirective(
          conversationId: event.conversationId,
          afterSequence: previousSequence,
        ),
      );
    }

    try {
      await _ledger.commitNextEvent(
        event,
        expectedPreviousSequence: previousSequence,
      );
    } on Object {
      final converged = await _readExactAfterCommitRace(event);
      if (converged != null) return converged;
      throw const ClientEventConvergenceException(
        code: 'storage_failure',
        safeMessage: 'The event could not be stored durably.',
      );
    }
    return ClientEventCommitted(
      event: event,
      acknowledgement: _acknowledgement(event),
    );
  }

  Future<void> _verifyRequestRoute(ClientEventRecord event) async {
    final requestId = event.requestId;
    final request = await _readRequest(requestId);
    if (request == null) {
      throw const ClientEventConvergenceException(
        code: 'request_unknown',
        safeMessage: 'The event does not match a tracked request.',
      );
    }
    if (request.originDeviceId != event.originDeviceId ||
        request.conversationId != event.conversationId ||
        request.sessionId != event.sessionId ||
        request.requestId != requestId) {
      throw const ClientEventConvergenceException(
        code: 'request_identity_conflict',
        safeMessage: 'The event conflicts with the tracked request route.',
      );
    }
  }

  Future<TrackedClientRequest?> _readRequest(String requestId) async {
    try {
      return await _ledger.readRequest(requestId);
    } on Object {
      throw const ClientEventConvergenceException(
        code: 'storage_failure',
        safeMessage: 'The tracked request could not be read.',
      );
    }
  }

  Future<ConversationEventCursor?> _readCursor(String conversationId) async {
    try {
      final cursor = await _ledger.readCursor(conversationId);
      if (cursor != null && cursor.conversationId != conversationId) {
        throw const ClientEventConvergenceException(
          code: 'cursor_identity_conflict',
          safeMessage: 'The durable cursor belongs to another conversation.',
        );
      }
      return cursor;
    } on ClientEventConvergenceException {
      rethrow;
    } on Object {
      throw const ClientEventConvergenceException(
        code: 'storage_failure',
        safeMessage: 'The conversation cursor could not be read.',
      );
    }
  }

  Future<ClientEventConvergenceResult> _duplicateOrConflict(
    ClientEventRecord event,
  ) async {
    final existing = await _readEvent(event.conversationId, event.sequence);
    if (existing != null && existing.samePersistedFact(event)) {
      return ClientEventDuplicate(_acknowledgement(event));
    }
    throw const ClientEventConvergenceException(
      code: 'event_identity_conflict',
      safeMessage: 'The event conflicts with a durable sequence fact.',
    );
  }

  Future<ClientEventDuplicate?> _readExactAfterCommitRace(
    ClientEventRecord event,
  ) async {
    try {
      final cursor = await _ledger.readCursor(event.conversationId);
      if (cursor == null || cursor.sequence < event.sequence) return null;
      final existing = await _ledger.readEvent(
        event.conversationId,
        event.sequence,
      );
      if (existing != null && existing.samePersistedFact(event)) {
        return ClientEventDuplicate(_acknowledgement(event));
      }
      return null;
    } on Object {
      return null;
    }
  }

  Future<ClientEventRecord?> _readEvent(
    String conversationId,
    BigInt sequence,
  ) async {
    try {
      return await _ledger.readEvent(conversationId, sequence);
    } on Object {
      throw const ClientEventConvergenceException(
        code: 'storage_failure',
        safeMessage: 'The durable event could not be read.',
      );
    }
  }

  ClientEventAcknowledgement _acknowledgement(ClientEventRecord event) =>
      ClientEventAcknowledgement(
        conversationId: event.conversationId,
        sequence: event.sequence,
        eventId: event.eventId,
      );
}
