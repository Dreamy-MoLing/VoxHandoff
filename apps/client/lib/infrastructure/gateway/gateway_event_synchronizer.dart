import 'dart:async';
import 'dart:math';

import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';

import '../../application/client_event_convergence.dart';
import '../../domain/client_event.dart';
import 'gateway_event_mapper.dart';
import 'grpc_gateway_live_transport.dart';

typedef GatewayCommandIdFactory = String Function(String purpose);
typedef CommittedClientEventCallback =
    FutureOr<void> Function(ClientEventRecord event);

class GatewayEventSynchronizer {
  factory GatewayEventSynchronizer({
    required GatewayEventMapper mapper,
    required ClientEventConvergence convergence,
    GatewayCommandIdFactory? commandIdFactory,
    CommittedClientEventCallback? onCommitted,
  }) => GatewayEventSynchronizer._(
    mapper,
    convergence,
    commandIdFactory ?? _secureOpaqueId,
    onCommitted,
  );

  GatewayEventSynchronizer._(
    this._mapper,
    this._convergence,
    this._commandIdFactory,
    this._onCommitted,
  );

  final GatewayEventMapper _mapper;
  final ClientEventConvergence _convergence;
  final GatewayCommandIdFactory _commandIdFactory;
  final CommittedClientEventCallback? _onCommitted;
  final Map<String, BigInt> _pendingReplay = {};

  Future<void> run(GatewayLiveEventConnection connection) async {
    try {
      await for (final frame in connection.frames) {
        if (frame is! GatewayEventFrame) continue;
        final event = await _mapper.map(frame.event);
        final result = await _convergence.accept(event);
        switch (result) {
          case ClientEventCommitted():
            _clearSatisfiedReplay(event);
            connection.acknowledge(_ack(result.acknowledgement));
            await _onCommitted?.call(event);
          case ClientEventDuplicate():
            _clearSatisfiedReplay(event);
            connection.acknowledge(_ack(result.acknowledgement));
          case ClientEventGap():
            _requestReplayOnce(connection, result.replay);
        }
      }
    } on Object {
      await connection.close();
      rethrow;
    }
  }

  void _requestReplayOnce(
    GatewayLiveEventConnection connection,
    ClientReplayDirective replay,
  ) {
    final pending = _pendingReplay[replay.conversationId];
    if (pending == replay.afterSequence) return;
    _pendingReplay[replay.conversationId] = replay.afterSequence;
    connection.sendCommand(
      ClientCommand(
        commandId: _commandIdFactory('replay-command'),
        idempotencyKey: _commandIdFactory('replay-idempotency'),
        conversationId: replay.conversationId,
        replay: ReplayEvents(
          afterSequence: _uint64(replay.afterSequence),
          maximumEvents: replay.maximumEvents,
        ),
      ),
    );
  }

  void _clearSatisfiedReplay(ClientEventRecord event) {
    final pending = _pendingReplay[event.conversationId];
    if (pending != null && event.sequence > pending) {
      _pendingReplay.remove(event.conversationId);
    }
  }

  Ack _ack(ClientEventAcknowledgement value) => Ack(
    conversationId: value.conversationId,
    sequence: _uint64(value.sequence),
    eventId: value.eventId,
  );

  Int64 _uint64(BigInt value) {
    if (value < BigInt.zero || value > _maximumUint64) {
      throw const GatewayEventMappingException(
        code: 'event_sequence_invalid',
        safeMessage: 'The event sequence is outside the protocol range.',
      );
    }
    return Int64.parseInt(value.toString());
  }

  static final BigInt _maximumUint64 = (BigInt.one << 64) - BigInt.one;

  static String _secureOpaqueId(String purpose) {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '$purpose-$suffix';
  }
}
