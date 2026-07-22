import 'dart:async';
import 'dart:math';

import '../domain/client_event.dart';
import '../domain/gateway_sync.dart';
import 'client_event_convergence.dart';

typedef GatewayRouterIdFactory = String Function(String purpose);
typedef GatewayCommittedEventCallback =
    FutureOr<void> Function(ClientEventRecord event);
typedef GatewayRequestStatusCallback =
    FutureOr<void> Function(ClientRequestStatusSnapshot status);
typedef GatewayControlLeaseCallback =
    FutureOr<void> Function(ClientControlLeaseSnapshot lease);
typedef GatewayHeartbeatCallback = FutureOr<void> Function(BigInt sequence);
typedef GatewayDirectoryCallback =
    FutureOr<void> Function(ClientGatewayDirectory directory);
typedef GatewayConversationCallback =
    FutureOr<void> Function(ClientConversationDirectoryEntry conversation);

class GatewayFrameRouterException implements Exception {
  const GatewayFrameRouterException({
    required this.code,
    required this.safeMessage,
  });

  final String code;
  final String safeMessage;

  @override
  String toString() => 'GatewayFrameRouterException(code: $code)';
}

/// The sole application owner of the authenticated Gateway frame stream.
///
/// It serializes every frame branch, restores unknown request routes before
/// accepting their events, and pages replay only from a durable local cursor.
class GatewayFrameRouter {
  factory GatewayFrameRouter({
    required ClientEventLedger ledger,
    required ClientEventConvergence convergence,
    GatewayRouterIdFactory? idFactory,
    GatewayCommittedEventCallback? onCommitted,
    GatewayRequestStatusCallback? onRequestStatus,
    GatewayControlLeaseCallback? onControlLease,
    GatewayHeartbeatCallback? onHeartbeat,
    GatewayDirectoryCallback? onDirectory,
    GatewayConversationCallback? onConversation,
  }) => GatewayFrameRouter._(
    ledger,
    convergence,
    idFactory ?? _secureOpaqueId,
    onCommitted,
    onRequestStatus,
    onControlLease,
    onHeartbeat,
    onDirectory,
    onConversation,
  );

  GatewayFrameRouter._(
    this._ledger,
    this._convergence,
    this._idFactory,
    this._onCommitted,
    this._onRequestStatus,
    this._onControlLease,
    this._onHeartbeat,
    this._onDirectory,
    this._onConversation,
  );

  static const maximumReplayEvents = 500;
  static const maximumPendingUnknownEvents = 500;

  final ClientEventLedger _ledger;
  final ClientEventConvergence _convergence;
  final GatewayRouterIdFactory _idFactory;
  final GatewayCommittedEventCallback? _onCommitted;
  final GatewayRequestStatusCallback? _onRequestStatus;
  final GatewayControlLeaseCallback? _onControlLease;
  final GatewayHeartbeatCallback? _onHeartbeat;
  final GatewayDirectoryCallback? _onDirectory;
  final GatewayConversationCallback? _onConversation;
  final Map<String, _PendingReplay> _pendingReplays = {};
  final Map<String, _PendingUnknownRequest> _pendingUnknownRequests = {};
  var _pendingUnknownEventCount = 0;

  Future<void> run(
    Stream<ClientGatewayFrame> frames,
    ClientGatewayCommandPort commands,
  ) async {
    try {
      await _startCursorReplay(commands);
      await for (final frame in frames) {
        await _route(frame, commands);
      }
    } on Object {
      await commands.close();
      rethrow;
    }
  }

  Future<void> _startCursorReplay(ClientGatewayCommandPort commands) async {
    late final List<String> conversationIds;
    try {
      conversationIds = await _ledger.listTrackedConversationIds();
    } on Object {
      throw const GatewayFrameRouterException(
        code: 'storage_failure',
        safeMessage: 'The durable conversations could not be read.',
      );
    }
    for (final conversationId in conversationIds) {
      final cursor = await _readCursor(conversationId);
      _requestReplayOnce(
        commands,
        conversationId: conversationId,
        afterSequence: cursor?.sequence ?? BigInt.zero,
      );
    }
  }

  Future<void> _route(
    ClientGatewayFrame frame,
    ClientGatewayCommandPort commands,
  ) async {
    switch (frame) {
      case ClientGatewayEventFrame():
        await _acceptEvent(frame.event, commands);
      case ClientGatewayRequestStatusFrame():
        await _acceptRequestStatus(frame.status, commands);
      case ClientGatewayReplayCompletedFrame():
        await _acceptReplayCompletion(frame.completion, commands);
      case ClientGatewayControlLeaseFrame():
        await _onControlLease?.call(frame.lease);
      case ClientGatewayHeartbeatFrame():
        await _onHeartbeat?.call(frame.lastReceivedSequence);
      case ClientGatewayDirectoryFrame():
        await _onDirectory?.call(frame.directory);
      case ClientGatewayConversationFrame():
        await _onConversation?.call(frame.conversation);
    }
  }

  Future<void> _acceptEvent(
    ClientEventRecord event,
    ClientGatewayCommandPort commands,
  ) async {
    late final ClientEventConvergenceResult result;
    try {
      result = await _convergence.accept(event);
    } on ClientEventConvergenceException catch (error) {
      if (error.code == 'request_unknown') {
        _holdUnknownEvent(event, commands);
        return;
      }
      rethrow;
    }

    switch (result) {
      case ClientEventCommitted():
        commands.acknowledge(_ack(result.acknowledgement));
        await _onCommitted?.call(event);
      case ClientEventDuplicate():
        commands.acknowledge(_ack(result.acknowledgement));
      case ClientEventGap():
        _requestReplayOnce(
          commands,
          conversationId: result.replay.conversationId,
          afterSequence: result.replay.afterSequence,
        );
    }
    await _finishDurableReplay(event.conversationId, commands);
  }

  void _holdUnknownEvent(
    ClientEventRecord event,
    ClientGatewayCommandPort commands,
  ) {
    final pending = _pendingUnknownRequests.putIfAbsent(
      event.requestId,
      () => _PendingUnknownRequest(event.conversationId),
    );
    if (pending.conversationId != event.conversationId) {
      throw const GatewayFrameRouterException(
        code: 'request_identity_conflict',
        safeMessage: 'The unknown request events disagree on conversation.',
      );
    }
    for (final existing in pending.events) {
      if (existing.conversationId == event.conversationId &&
          existing.sequence == event.sequence) {
        if (existing.samePersistedFact(event)) return;
        throw const GatewayFrameRouterException(
          code: 'event_identity_conflict',
          safeMessage:
              'The unknown request event conflicts with a pending fact.',
        );
      }
    }
    if (_pendingUnknownEventCount >= maximumPendingUnknownEvents) {
      throw const GatewayFrameRouterException(
        code: 'unknown_request_buffer_full',
        safeMessage: 'Too many unknown request events are awaiting recovery.',
      );
    }
    pending.events.add(event);
    _pendingUnknownEventCount += 1;
    if (pending.lookupSent) return;
    pending.lookupSent = true;
    commands.requestStatus(
      commandId: _idFactory('request-status-command'),
      idempotencyKey: _idFactory('request-status-idempotency'),
      conversationId: event.conversationId,
      requestId: event.requestId,
    );
  }

  Future<void> _acceptRequestStatus(
    ClientRequestStatusSnapshot status,
    ClientGatewayCommandPort commands,
  ) async {
    final pending = _pendingUnknownRequests[status.requestId];
    if (pending != null) {
      if (pending.conversationId != status.conversationId ||
          pending.events.any(
            (event) =>
                event.originDeviceId != status.originDeviceId ||
                event.sessionId != status.sessionId,
          )) {
        throw const GatewayFrameRouterException(
          code: 'request_identity_conflict',
          safeMessage: 'The recovered request route conflicts with its events.',
        );
      }
      try {
        await _ledger.trackRequest(status.toTrackedRequest());
      } on Object {
        throw const GatewayFrameRouterException(
          code: 'storage_failure',
          safeMessage: 'The recovered request route could not be stored.',
        );
      }
      _pendingUnknownRequests.remove(status.requestId);
      _pendingUnknownEventCount -= pending.events.length;
      for (final event in pending.events) {
        await _acceptEvent(event, commands);
      }
    }
    await _onRequestStatus?.call(status);
  }

  Future<void> _acceptReplayCompletion(
    ClientReplayCompletion completion,
    ClientGatewayCommandPort commands,
  ) async {
    final pending = _pendingReplays[completion.conversationId];
    if (pending == null ||
        pending.commandId != completion.commandId ||
        pending.afterSequence != completion.afterSequence) {
      throw const GatewayFrameRouterException(
        code: 'replay_completion_unexpected',
        safeMessage: 'The replay completion does not match a pending request.',
      );
    }
    pending.completion = completion;
    await _finishDurableReplay(completion.conversationId, commands);
  }

  Future<void> _finishDurableReplay(
    String conversationId,
    ClientGatewayCommandPort commands,
  ) async {
    final pending = _pendingReplays[conversationId];
    final completion = pending?.completion;
    if (pending == null || completion == null) return;
    final cursor = await _readCursor(conversationId);
    final sequence = cursor?.sequence ?? BigInt.zero;
    if (sequence < completion.throughSequence) {
      final awaitingRoute = _pendingUnknownRequests.values.any(
        (request) => request.conversationId == conversationId,
      );
      if (awaitingRoute) return;
      _pendingReplays.remove(conversationId);
      _requestReplayOnce(
        commands,
        conversationId: conversationId,
        afterSequence: sequence,
      );
      return;
    }
    _pendingReplays.remove(conversationId);
    if (completion.mayHaveMore || pending.replayAgain) {
      _requestReplayOnce(
        commands,
        conversationId: conversationId,
        afterSequence: sequence,
      );
    }
  }

  void _requestReplayOnce(
    ClientGatewayCommandPort commands, {
    required String conversationId,
    required BigInt afterSequence,
  }) {
    final existing = _pendingReplays[conversationId];
    if (existing != null) {
      if (existing.afterSequence != afterSequence) existing.replayAgain = true;
      return;
    }
    final commandId = _idFactory('replay-command');
    _pendingReplays[conversationId] = _PendingReplay(
      commandId: commandId,
      afterSequence: afterSequence,
    );
    commands.requestReplay(
      commandId: commandId,
      idempotencyKey: _idFactory('replay-idempotency'),
      conversationId: conversationId,
      afterSequence: afterSequence,
      maximumEvents: maximumReplayEvents,
    );
  }

  Future<ConversationEventCursor?> _readCursor(String conversationId) async {
    try {
      final cursor = await _ledger.readCursor(conversationId);
      if (cursor != null && cursor.conversationId != conversationId) {
        throw const GatewayFrameRouterException(
          code: 'cursor_identity_conflict',
          safeMessage: 'The durable cursor belongs to another conversation.',
        );
      }
      return cursor;
    } on GatewayFrameRouterException {
      rethrow;
    } on Object {
      throw const GatewayFrameRouterException(
        code: 'storage_failure',
        safeMessage: 'The durable cursor could not be read.',
      );
    }
  }

  ClientGatewayAcknowledgement _ack(ClientEventAcknowledgement value) =>
      ClientGatewayAcknowledgement(
        conversationId: value.conversationId,
        sequence: value.sequence,
        eventId: value.eventId,
      );

  static String _secureOpaqueId(String purpose) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$purpose-$suffix';
  }
}

class _PendingReplay {
  _PendingReplay({required this.commandId, required this.afterSequence});

  final String commandId;
  final BigInt afterSequence;
  ClientReplayCompletion? completion;
  bool replayAgain = false;
}

class _PendingUnknownRequest {
  _PendingUnknownRequest(this.conversationId);

  final String conversationId;
  final List<ClientEventRecord> events = [];
  bool lookupSent = false;
}
