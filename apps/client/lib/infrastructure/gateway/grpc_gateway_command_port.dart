import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';

import '../../domain/gateway_sync.dart';
import 'grpc_gateway_live_transport.dart';

class GrpcGatewayCommandPort implements ClientGatewayCommandPort {
  const GrpcGatewayCommandPort(this._connection);

  final GatewayLiveEventConnection _connection;

  @override
  void acknowledge(ClientGatewayAcknowledgement acknowledgement) {
    _connection.acknowledge(
      Ack(
        conversationId: acknowledgement.conversationId,
        sequence: _uint64(acknowledgement.sequence),
        eventId: acknowledgement.eventId,
      ),
    );
  }

  @override
  void requestReplay({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required BigInt afterSequence,
    required int maximumEvents,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversationId,
        replay: ReplayEvents(
          afterSequence: _uint64(afterSequence),
          maximumEvents: maximumEvents,
        ),
      ),
    );
  }

  @override
  void requestStatus({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
  }) {
    _connection.sendCommand(
      ClientCommand(
        commandId: commandId,
        idempotencyKey: idempotencyKey,
        conversationId: conversationId,
        getRequest: GetRequest(requestId: requestId),
      ),
    );
  }

  @override
  Future<void> close() => _connection.close();

  Int64 _uint64(BigInt value) {
    if (value < BigInt.zero || value > maximumUint64) {
      throw const FormatException('The command sequence is invalid.');
    }
    return Int64.parseInt(value.toString());
  }
}
