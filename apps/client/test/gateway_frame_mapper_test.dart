import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:agent_talk_client/infrastructure/gateway/gateway_frame_mapper.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_live_transport.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

RequestStatus requestStatus() => RequestStatus(
  requestId: 'request-1',
  conversationId: 'conversation-1',
  state: 'accepted',
  nodeId: 'node-1',
  agentId: 'agent-1',
  capabilityRevision: 'capability-revision-1',
  acceptedSequence: Int64.ONE,
  originDeviceId: 'origin-device-1',
  sessionId: 'session-1',
);

void main() {
  test('maps the complete request route needed for unknown recovery', () async {
    final mapped = await GatewayFrameMapper().map(
      GatewayRequestStatusFrame(requestStatus()),
    );

    expect(mapped, isA<ClientGatewayRequestStatusFrame>());
    final status = (mapped as ClientGatewayRequestStatusFrame).status;
    expect(status.requestId, 'request-1');
    expect(status.originDeviceId, 'origin-device-1');
    expect(status.sessionId, 'session-1');
    expect(status.acceptedSequence, BigInt.one);
    expect(status.toTrackedRequest().nodeId, 'node-1');
  });

  test('maps a correlated replay completion fact', () async {
    final mapped = await GatewayFrameMapper().map(
      GatewayReplayCompletedFrame(
        ReplayCompleted(
          commandId: 'replay-command-1',
          conversationId: 'conversation-1',
          afterSequence: Int64(10),
          throughSequence: Int64(12),
          eventCount: 2,
          mayHaveMore: true,
        ),
      ),
    );

    final completion = (mapped as ClientGatewayReplayCompletedFrame).completion;
    expect(completion.afterSequence, BigInt.from(10));
    expect(completion.throughSequence, BigInt.from(12));
    expect(completion.eventCount, 2);
    expect(completion.mayHaveMore, isTrue);
  });

  test(
    'rejects incomplete recovery identity without echoing remote text',
    () async {
      final malformed = requestStatus()
        ..originDeviceId = ''
        ..nodeId = 'secret-bearing-node-value';

      await expectLater(
        GatewayFrameMapper().map(GatewayRequestStatusFrame(malformed)),
        throwsA(
          isA<GatewayFrameMappingException>()
              .having((error) => error.code, 'code', 'request_status_invalid')
              .having(
                (error) => error.toString(),
                'redacted string',
                isNot(contains('secret-bearing')),
              ),
        ),
      );
    },
  );

  test(
    'rejects a replay count that disagrees with its sequence range',
    () async {
      await expectLater(
        GatewayFrameMapper().map(
          GatewayReplayCompletedFrame(
            ReplayCompleted(
              commandId: 'replay-command-1',
              conversationId: 'conversation-1',
              afterSequence: Int64(10),
              throughSequence: Int64(12),
              eventCount: 1,
            ),
          ),
        ),
        throwsA(
          isA<GatewayFrameMappingException>().having(
            (error) => error.code,
            'code',
            'replay_completion_invalid',
          ),
        ),
      );
    },
  );
}
