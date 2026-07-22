import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/infrastructure/gateway/gateway_event_mapper.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

EventEnvelope envelope({
  AgentEvent? event,
  String eventId = 'event-1',
  String connectionId = 'node-connection-1',
  String deviceId = 'device-1',
  String conversationId = 'conversation-1',
  String sessionId = 'session-1',
  String requestId = 'request-1',
  Int64? sequence,
}) {
  final result = EventEnvelope(
    protocol: ProtocolVersion(major: 1, minor: 0),
    eventId: eventId,
    connectionId: connectionId,
    deviceId: deviceId,
    conversationId: conversationId,
    sessionId: sessionId,
    requestId: requestId,
    sequence: sequence ?? Int64.ONE,
    event:
        event ??
        AgentEvent(
          type: AgentEventType.AGENT_EVENT_TYPE_MESSAGE_COMPLETED,
          message: MessageEvent(
            text: 'The complete reply.',
            revision: Int64.ONE,
          ),
        ),
  );
  result.ensureOccurredAt()
    ..seconds = Int64(1893456000)
    ..nanos = 123000000;
  return result;
}

void main() {
  test(
    'maps a complete protobuf event into protocol-free durable content',
    () async {
      final mapper = GatewayEventMapper();

      final mapped = await mapper.map(envelope());

      expect(mapped.eventId, 'event-1');
      expect(mapped.originDeviceId, 'device-1');
      expect(mapped.sequence, BigInt.one);
      expect(mapped.kind, ClientEventKind.messageCompleted);
      expect(mapped.occurredAt, DateTime.utc(2030, 1, 1, 0, 0, 0, 123));
      expect(mapped.envelopeSha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      final content = mapped.content as MessageClientEventContent;
      expect(content.text, 'The complete reply.');
      expect(content.revision, BigInt.one);
    },
  );

  test(
    'maps explicit unsupported events without guessing their native shape',
    () async {
      final mapper = GatewayEventMapper();
      final mapped = await mapper.map(
        envelope(
          event: AgentEvent(
            type: AgentEventType.AGENT_EVENT_TYPE_UNSPECIFIED,
            unsupported: UnsupportedEvent(
              nativeTypeNumber: 72,
              safeMessage: 'Upgrade required.',
            ),
          ),
        ),
      );

      expect(mapped.kind, ClientEventKind.unsupported);
      final content = mapped.content as UnsupportedClientEventContent;
      expect(content.nativeTypeNumber, 72);
      expect(content.safeMessage, 'Upgrade required.');
    },
  );

  test('maps request-bound durable connection lifecycle events', () async {
    final mapper = GatewayEventMapper();

    final mapped = await mapper.map(
      envelope(
        event: AgentEvent(
          type: AgentEventType.AGENT_EVENT_TYPE_CONNECTION_LOST,
          connection: ConnectionEvent(safeMessage: 'Connection lost.'),
        ),
      ),
    );

    expect(mapped.kind, ClientEventKind.connectionLost);
    expect(mapped.requestId, 'request-1');
    expect(
      (mapped.content as SafeMessageClientEventContent).safeMessage,
      'Connection lost.',
    );
  });

  test(
    'rejects a type and payload mismatch with no remote text in the error',
    () async {
      final mapper = GatewayEventMapper();

      await expectLater(
        mapper.map(
          envelope(
            event: AgentEvent(
              type: AgentEventType.AGENT_EVENT_TYPE_MESSAGE_DELTA,
              requestProgress: RequestProgressEvent(
                safeMessage: 'secret-bearing malformed payload',
              ),
            ),
          ),
        ),
        throwsA(
          isA<GatewayEventMappingException>()
              .having((error) => error.code, 'code', 'event_payload_mismatch')
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
    'rejects invalid protocol, identity, timestamp, and sequence facts',
    () async {
      final mapper = GatewayEventMapper();
      final invalidProtocol = envelope()..protocol.minor = 1;
      final invalidIdentity = envelope(eventId: 'bad\nevent');
      final missingRequestIdentity = envelope(requestId: '');
      final invalidTimestamp = envelope()..occurredAt.nanos = 1000000000;
      final invalidSequence = envelope(sequence: Int64.ZERO);

      for (final value in [
        invalidProtocol,
        invalidIdentity,
        missingRequestIdentity,
        invalidTimestamp,
        invalidSequence,
      ]) {
        await expectLater(
          mapper.map(value),
          throwsA(isA<GatewayEventMappingException>()),
        );
      }
    },
  );

  test('requires approval identity, expiry, and operation hash', () async {
    final mapper = GatewayEventMapper();
    final approval = ApprovalEvent(
      approvalId: 'approval-1',
      safeSummary: 'Run a command.',
      operationSummarySha256: 'not-a-hash',
    );
    approval.ensureExpiresAt().seconds = Int64(1893456060);

    await expectLater(
      mapper.map(
        envelope(
          event: AgentEvent(
            type: AgentEventType.AGENT_EVENT_TYPE_APPROVAL_REQUIRED,
            approval: approval,
          ),
        ),
      ),
      throwsA(
        isA<GatewayEventMappingException>().having(
          (error) => error.code,
          'code',
          'approval_event_invalid',
        ),
      ),
    );
  });

  test(
    'rejects an oversized event before hashing or exposing its text',
    () async {
      final mapper = GatewayEventMapper();
      final oversized = envelope(
        event: AgentEvent(
          type: AgentEventType.AGENT_EVENT_TYPE_MESSAGE_COMPLETED,
          message: MessageEvent(
            text: List.filled(
              GatewayEventMapper.maximumEnvelopeBytes + 1,
              'x',
            ).join(),
            revision: Int64.ONE,
          ),
        ),
      );

      await expectLater(
        mapper.map(oversized),
        throwsA(
          isA<GatewayEventMappingException>().having(
            (error) => error.code,
            'code',
            'event_too_large',
          ),
        ),
      );
    },
  );
}
