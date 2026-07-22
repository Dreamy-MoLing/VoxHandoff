import 'dart:async';

import 'package:agent_talk_client/application/client_event_convergence.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/infrastructure/gateway/gateway_event_mapper.dart';
import 'package:agent_talk_client/infrastructure/gateway/gateway_event_synchronizer.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_live_transport.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEventLedger implements ClientEventLedger {
  final requests = <String, TrackedClientRequest>{};
  final localSubmissions = <String, LocalClientSubmission>{};
  final cursors = <String, ConversationEventCursor>{};
  final events = <BigInt, ClientEventRecord>{};
  var failCommit = false;

  @override
  Future<void> trackRequest(TrackedClientRequest request) async {
    requests[request.requestId] = request;
  }

  @override
  Future<void> prepareLocalSubmission(
    TrackedClientRequest route,
    LocalClientSubmission submission,
  ) async {
    requests[route.requestId] = route;
    localSubmissions[submission.requestId] = submission;
  }

  @override
  Future<LocalClientSubmission?> readLocalSubmission(String requestId) async =>
      localSubmissions[requestId];

  @override
  Future<void> advanceLocalSubmission(
    String requestId, {
    required LocalClientSubmissionDisposition expectedDisposition,
    required LocalClientSubmissionDisposition nextDisposition,
  }) async {
    final current = localSubmissions[requestId]!;
    localSubmissions[requestId] = LocalClientSubmission(
      requestId: current.requestId,
      originDeviceId: current.originDeviceId,
      commandId: current.commandId,
      idempotencyKey: current.idempotencyKey,
      confirmedTextSha256: current.confirmedTextSha256,
      disposition: nextDisposition,
    );
  }

  @override
  Future<void> commitNextEvent(
    ClientEventRecord event, {
    required BigInt expectedPreviousSequence,
  }) async {
    if (failCommit) throw StateError('secret-bearing database failure');
    final current = cursors[event.conversationId]?.sequence ?? BigInt.zero;
    if (current != expectedPreviousSequence ||
        event.sequence != current + BigInt.one) {
      throw StateError('cursor conflict');
    }
    events[event.sequence] = event;
    cursors[event.conversationId] = ConversationEventCursor(
      conversationId: event.conversationId,
      sequence: event.sequence,
      eventId: event.eventId,
    );
  }

  @override
  Future<ConversationEventCursor?> readCursor(String conversationId) async =>
      cursors[conversationId];

  @override
  Future<ClientEventRecord?> readEvent(
    String conversationId,
    BigInt sequence,
  ) async => events[sequence];

  @override
  Future<TrackedClientRequest?> readRequest(String requestId) async =>
      requests[requestId];
}

class FakeLiveEventConnection implements GatewayLiveEventConnection {
  final _frames = StreamController<GatewayLiveFrame>();
  final acknowledgements = <Ack>[];
  final commands = <ClientCommand>[];
  var closed = false;

  @override
  Stream<GatewayLiveFrame> get frames => _frames.stream;

  void add(EventEnvelope event) => _frames.add(GatewayEventFrame(event));

  Future<void> finish() => _frames.close();

  @override
  void acknowledge(Ack acknowledgement) {
    acknowledgements.add(acknowledgement.deepCopy());
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_frames.isClosed) unawaited(_frames.close());
  }

  @override
  void sendCommand(ClientCommand command) {
    commands.add(command.deepCopy());
  }
}

EventEnvelope gatewayEvent(int sequence, {String? eventId}) {
  final result = EventEnvelope(
    protocol: ProtocolVersion(major: 1, minor: 0),
    eventId: eventId ?? 'event-$sequence',
    connectionId: 'node-connection-$sequence',
    deviceId: 'device-1',
    conversationId: 'conversation-1',
    sessionId: 'session-1',
    requestId: 'request-1',
    sequence: Int64(sequence),
    event: AgentEvent(
      type: AgentEventType.AGENT_EVENT_TYPE_MESSAGE_COMPLETED,
      message: MessageEvent(
        text: 'Complete reply $sequence',
        revision: Int64(sequence),
      ),
    ),
  );
  result.ensureOccurredAt().seconds = Int64(1893456000 + sequence);
  return result;
}

Future<void> waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw TimeoutException('The synchronizer did not reach the expected state.');
}

GatewayEventSynchronizer synchronizer(
  FakeEventLedger ledger, {
  FutureOr<void> Function(ClientEventRecord)? onCommitted,
}) {
  var nextId = 0;
  return GatewayEventSynchronizer(
    mapper: GatewayEventMapper(),
    convergence: ClientEventConvergence(ledger: ledger),
    commandIdFactory: (purpose) => '$purpose-${++nextId}',
    onCommitted: onCommitted,
  );
}

void main() {
  test(
    'deduplicates gap replay and Acks only consecutive durable events',
    () async {
      final ledger = FakeEventLedger();
      ledger.requests['request-1'] = TrackedClientRequest(
        originDeviceId: 'device-1',
        conversationId: 'conversation-1',
        sessionId: 'session-1',
        requestId: 'request-1',
        nodeId: 'node-1',
        agentId: 'agent-1',
        capabilityRevision: 'capability-revision-1',
      );
      final committed = <BigInt>[];
      final connection = FakeLiveEventConnection();
      final running = synchronizer(
        ledger,
        onCommitted: (event) => committed.add(event.sequence),
      ).run(connection);

      connection.add(gatewayEvent(2));
      connection.add(gatewayEvent(2));
      await waitUntil(() => connection.commands.length == 1);
      expect(connection.acknowledgements, isEmpty);
      expect(connection.commands.single.replay.afterSequence, Int64.ZERO);
      expect(connection.commands.single.replay.maximumEvents, 500);

      connection.add(gatewayEvent(1));
      connection.add(gatewayEvent(2));
      await waitUntil(() => connection.acknowledgements.length == 2);
      expect(committed, [BigInt.one, BigInt.from(2)]);
      expect(connection.acknowledgements.map((value) => value.eventId), [
        'event-1',
        'event-2',
      ]);

      connection.add(gatewayEvent(4));
      connection.add(gatewayEvent(4));
      await waitUntil(() => connection.commands.length == 2);
      expect(connection.commands.last.replay.afterSequence, Int64(2));

      await connection.finish();
      await running;
      expect(connection.closed, isFalse);
    },
  );

  test(
    'Acks an exact duplicate without publishing it twice to the view',
    () async {
      final ledger = FakeEventLedger();
      ledger.requests['request-1'] = TrackedClientRequest(
        originDeviceId: 'device-1',
        conversationId: 'conversation-1',
        sessionId: 'session-1',
        requestId: 'request-1',
        nodeId: 'node-1',
        agentId: 'agent-1',
        capabilityRevision: 'capability-revision-1',
      );
      final committed = <BigInt>[];
      final connection = FakeLiveEventConnection();
      final running = synchronizer(
        ledger,
        onCommitted: (event) => committed.add(event.sequence),
      ).run(connection);

      connection.add(gatewayEvent(1));
      connection.add(gatewayEvent(1));
      await waitUntil(() => connection.acknowledgements.length == 2);
      await connection.finish();
      await running;

      expect(committed, [BigInt.one]);
      expect(connection.acknowledgements.length, 2);
    },
  );

  test(
    'closes the stream and emits no Ack when durable commit is uncertain',
    () async {
      final ledger = FakeEventLedger()..failCommit = true;
      ledger.requests['request-1'] = TrackedClientRequest(
        originDeviceId: 'device-1',
        conversationId: 'conversation-1',
        sessionId: 'session-1',
        requestId: 'request-1',
        nodeId: 'node-1',
        agentId: 'agent-1',
        capabilityRevision: 'capability-revision-1',
      );
      final connection = FakeLiveEventConnection();
      final running = synchronizer(ledger).run(connection);

      connection.add(gatewayEvent(1));
      await expectLater(
        running,
        throwsA(
          isA<ClientEventConvergenceException>().having(
            (error) => error.code,
            'code',
            'storage_failure',
          ),
        ),
      );

      expect(connection.closed, isTrue);
      expect(connection.acknowledgements, isEmpty);
      expect(ledger.cursors, isEmpty);
    },
  );

  test('closes on malformed protobuf without exposing its payload', () async {
    final ledger = FakeEventLedger();
    final connection = FakeLiveEventConnection();
    final running = synchronizer(ledger).run(connection);
    final malformed = gatewayEvent(1)
      ..event = AgentEvent(
        type: AgentEventType.AGENT_EVENT_TYPE_MESSAGE_DELTA,
        requestProgress: RequestProgressEvent(
          safeMessage: 'secret-bearing malformed payload',
        ),
      );

    connection.add(malformed);

    await expectLater(
      running,
      throwsA(
        isA<GatewayEventMappingException>().having(
          (error) => error.toString(),
          'redacted string',
          isNot(contains('secret-bearing')),
        ),
      ),
    );
    expect(connection.closed, isTrue);
    expect(connection.acknowledgements, isEmpty);
  });
}
