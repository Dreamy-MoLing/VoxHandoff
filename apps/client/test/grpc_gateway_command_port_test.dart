import 'dart:async';

import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_command_port.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_live_transport.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLiveConnection implements GatewayLiveEventConnection {
  final commands = <ClientCommand>[];
  final acknowledgements = <Ack>[];

  @override
  Stream<GatewayLiveFrame> get frames => const Stream.empty();

  @override
  void acknowledge(Ack acknowledgement) {
    acknowledgements.add(acknowledgement.deepCopy());
  }

  @override
  void sendCommand(ClientCommand command) {
    commands.add(command.deepCopy());
  }

  @override
  Future<void> close() async {}
}

void main() {
  test('maps recovery operations without constructing executable commands', () {
    final connection = FakeLiveConnection();
    final port = GrpcGatewayCommandPort(connection);

    port.requestStatus(
      commandId: 'status-command-1',
      idempotencyKey: 'status-idempotency-1',
      conversationId: 'conversation-1',
      requestId: 'request-1',
    );
    port.requestReplay(
      commandId: 'replay-command-1',
      idempotencyKey: 'replay-idempotency-1',
      conversationId: 'conversation-1',
      afterSequence: BigInt.from(7),
      maximumEvents: 500,
    );
    port.acknowledge(
      ClientGatewayAcknowledgement(
        conversationId: 'conversation-1',
        sequence: BigInt.from(8),
        eventId: 'event-8',
      ),
    );

    expect(connection.commands.map((command) => command.whichCommand()), [
      ClientCommand_Command.getRequest,
      ClientCommand_Command.replay,
    ]);
    expect(connection.commands.first.getRequest.requestId, 'request-1');
    expect(connection.commands.last.replay.afterSequence.toString(), '7');
    expect(connection.acknowledgements.single.eventId, 'event-8');
    expect(
      connection.commands.any(
        (command) => command.whichCommand() == ClientCommand_Command.send,
      ),
      isFalse,
    );
  });
}
