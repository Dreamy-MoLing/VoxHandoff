import 'dart:async';

import 'package:agent_talk_client/application/client_event_convergence.dart';
import 'package:agent_talk_client/application/gateway_frame_router.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/domain/gateway_sync.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEventLedger implements ClientEventLedger {
  final requests = <String, TrackedClientRequest>{};
  final localSubmissions = <String, LocalClientSubmission>{};
  final cursors = <String, ConversationEventCursor>{};
  final events = <String, Map<BigInt, ClientEventRecord>>{};
  var failCommit = false;

  @override
  Future<void> trackRequest(TrackedClientRequest request) async {
    final existing = requests[request.requestId];
    if (existing != null &&
        (existing.originDeviceId != request.originDeviceId ||
            existing.conversationId != request.conversationId ||
            existing.sessionId != request.sessionId ||
            existing.nodeId != request.nodeId ||
            existing.agentId != request.agentId ||
            existing.capabilityRevision != request.capabilityRevision ||
            existing.acceptedSequence != request.acceptedSequence)) {
      throw StateError('route conflict');
    }
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
  }) async {}

  @override
  Future<List<String>> listTrackedConversationIds() async =>
      requests.values.map((request) => request.conversationId).toSet().toList()
        ..sort();

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
    events.putIfAbsent(event.conversationId, () => {})[event.sequence] = event;
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
  ) async => events[conversationId]?[sequence];

  @override
  Future<TrackedClientRequest?> readRequest(String requestId) async =>
      requests[requestId];
}

class ReplayCall {
  const ReplayCall({
    required this.commandId,
    required this.conversationId,
    required this.afterSequence,
    required this.maximumEvents,
  });

  final String commandId;
  final String conversationId;
  final BigInt afterSequence;
  final int maximumEvents;
}

class StatusCall {
  const StatusCall(this.conversationId, this.requestId);

  final String conversationId;
  final String requestId;
}

class FakeCommandPort implements ClientGatewayCommandPort {
  final acknowledgements = <ClientGatewayAcknowledgement>[];
  final replays = <ReplayCall>[];
  final statuses = <StatusCall>[];
  var closed = false;

  @override
  void acquireControl({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    String? expectedLeaseId,
    BigInt? expectedRevision,
    required bool explicitTakeover,
  }) {}

  @override
  void createConversation({
    required String commandId,
    required String idempotencyKey,
    required ClientConversationDirectoryEntry conversation,
  }) {}

  @override
  void requestDirectory({
    required String commandId,
    required String idempotencyKey,
  }) {}

  @override
  void sendConfirmedText({
    required String commandId,
    required String idempotencyKey,
    required String requestId,
    required ClientConversationDirectoryEntry conversation,
    required ClientControlLeaseSnapshot lease,
    required String confirmedText,
  }) {}

  @override
  void interruptRequest({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  void resolveApproval({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
    required String approvalId,
    required String operationSummarySha256,
    required ClientApprovalDecision decision,
    required ClientDeviceSignature deviceSignature,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  void resolveClarification({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required String requestId,
    required String clarificationId,
    required String confirmedText,
    required ClientControlLeaseSnapshot lease,
  }) {}

  @override
  void acknowledge(ClientGatewayAcknowledgement acknowledgement) {
    acknowledgements.add(acknowledgement);
  }

  @override
  void requestReplay({
    required String commandId,
    required String idempotencyKey,
    required String conversationId,
    required BigInt afterSequence,
    required int maximumEvents,
  }) {
    replays.add(
      ReplayCall(
        commandId: commandId,
        conversationId: conversationId,
        afterSequence: afterSequence,
        maximumEvents: maximumEvents,
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
    statuses.add(StatusCall(conversationId, requestId));
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

ClientEventRecord event(
  int sequence, {
  String requestId = 'request-1',
  ClientEventKind kind = ClientEventKind.messageCompleted,
}) => ClientEventRecord(
  eventId: 'event-$sequence',
  connectionId: 'node-connection-$sequence',
  originDeviceId: 'device-1',
  conversationId: 'conversation-1',
  sessionId: 'session-1',
  requestId: requestId,
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
  kind: kind,
  content: kind == ClientEventKind.requestAccepted
      ? const SafeMessageClientEventContent('Accepted.')
      : MessageClientEventContent(
          text: 'Complete reply $sequence',
          revision: BigInt.from(sequence),
        ),
  envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
);

TrackedClientRequest route({bool accepted = true}) => TrackedClientRequest(
  originDeviceId: 'device-1',
  conversationId: 'conversation-1',
  sessionId: 'session-1',
  requestId: 'request-1',
  nodeId: 'node-1',
  agentId: 'agent-1',
  capabilityRevision: 'capability-revision-1',
  acceptedSequence: accepted ? BigInt.one : null,
);

ClientRequestStatusSnapshot status({
  String requestId = 'request-1',
  int acceptedSequence = 1,
}) => ClientRequestStatusSnapshot(
  requestId: requestId,
  originDeviceId: 'device-1',
  conversationId: 'conversation-1',
  sessionId: 'session-1',
  state: ClientRequestState.accepted,
  nodeId: 'node-1',
  agentId: 'agent-1',
  capabilityRevision: 'capability-revision-1',
  acceptedSequence: BigInt.from(acceptedSequence),
  failure: null,
);

GatewayFrameRouter router(
  FakeEventLedger ledger, {
  FutureOr<void> Function(ClientEventRecord)? onCommitted,
  FutureOr<void> Function(ClientRequestStatusSnapshot)? onRequestStatus,
}) {
  var nextId = 0;
  return GatewayFrameRouter(
    ledger: ledger,
    convergence: ClientEventConvergence(ledger: ledger),
    idFactory: (purpose) => '$purpose-${++nextId}',
    onCommitted: onCommitted,
    onRequestStatus: onRequestStatus,
  );
}

Future<void> waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw TimeoutException('The frame router did not reach the expected state.');
}

void main() {
  test(
    'replays every tracked cursor at startup and pages after durability',
    () async {
      final ledger = FakeEventLedger();
      ledger.requests['request-1'] = route();
      ledger.cursors['conversation-1'] = ConversationEventCursor(
        conversationId: 'conversation-1',
        sequence: BigInt.from(2),
        eventId: 'event-2',
      );
      ledger.events['conversation-1'] = {BigInt.from(2): event(2)};
      final commands = FakeCommandPort();
      final frames = StreamController<ClientGatewayFrame>();
      final running = router(ledger).run(frames.stream, commands);

      await waitUntil(() => commands.replays.length == 1);
      expect(commands.replays.single.afterSequence, BigInt.from(2));
      expect(commands.replays.single.maximumEvents, 500);

      frames.add(ClientGatewayEventFrame(event(3)));
      final firstReplay = commands.replays.single;
      frames.add(
        ClientGatewayReplayCompletedFrame(
          ClientReplayCompletion(
            commandId: firstReplay.commandId,
            conversationId: 'conversation-1',
            afterSequence: BigInt.from(2),
            throughSequence: BigInt.from(3),
            eventCount: 1,
            mayHaveMore: true,
          ),
        ),
      );
      await waitUntil(() => commands.replays.length == 2);
      expect(commands.replays.last.afterSequence, BigInt.from(3));

      final secondReplay = commands.replays.last;
      frames.add(
        ClientGatewayReplayCompletedFrame(
          ClientReplayCompletion(
            commandId: secondReplay.commandId,
            conversationId: 'conversation-1',
            afterSequence: BigInt.from(3),
            throughSequence: BigInt.from(3),
            eventCount: 0,
            mayHaveMore: false,
          ),
        ),
      );
      await frames.close();
      await running;

      expect(commands.acknowledgements.single.eventId, 'event-3');
      expect(commands.replays, hasLength(2));
      expect(commands.closed, isFalse);
    },
  );

  test(
    'recovers an unknown request once before storing or Acking its event',
    () async {
      final ledger = FakeEventLedger();
      final commands = FakeCommandPort();
      final frames = StreamController<ClientGatewayFrame>();
      final committed = <String>[];
      final statuses = <ClientRequestStatusSnapshot>[];
      final running = router(
        ledger,
        onCommitted: (value) => committed.add(value.eventId),
        onRequestStatus: statuses.add,
      ).run(frames.stream, commands);

      final accepted = event(1, kind: ClientEventKind.requestAccepted);
      frames.add(ClientGatewayEventFrame(accepted));
      frames.add(ClientGatewayEventFrame(accepted));
      await waitUntil(() => commands.statuses.length == 1);
      expect(commands.acknowledgements, isEmpty);
      expect(ledger.cursors, isEmpty);

      frames.add(ClientGatewayRequestStatusFrame(status()));
      await waitUntil(() => commands.acknowledgements.length == 1);
      await frames.close();
      await running;

      expect(commands.statuses.single.requestId, 'request-1');
      expect(ledger.requests['request-1']?.originDeviceId, 'device-1');
      expect(committed, ['event-1']);
      expect(statuses, hasLength(1));
      expect(commands.replays, isEmpty);
    },
  );

  test(
    'replays from the durable cursor after interleaved route recovery',
    () async {
      final ledger = FakeEventLedger();
      ledger.requests['known-request'] = TrackedClientRequest(
        originDeviceId: 'device-1',
        conversationId: 'conversation-1',
        sessionId: 'session-1',
        requestId: 'known-request',
        nodeId: 'node-1',
        agentId: 'agent-1',
        capabilityRevision: 'capability-revision-1',
      );
      final commands = FakeCommandPort();
      final frames = StreamController<ClientGatewayFrame>();
      final running = router(ledger).run(frames.stream, commands);
      await waitUntil(() => commands.replays.length == 1);

      frames.add(
        ClientGatewayEventFrame(
          event(
            1,
            requestId: 'request-a',
            kind: ClientEventKind.requestAccepted,
          ),
        ),
      );
      frames.add(
        ClientGatewayEventFrame(
          event(
            2,
            requestId: 'request-b',
            kind: ClientEventKind.requestAccepted,
          ),
        ),
      );
      frames.add(ClientGatewayEventFrame(event(3, requestId: 'request-a')));
      await waitUntil(() => commands.statuses.length == 2);
      final firstReplay = commands.replays.single;
      frames.add(
        ClientGatewayReplayCompletedFrame(
          ClientReplayCompletion(
            commandId: firstReplay.commandId,
            conversationId: 'conversation-1',
            afterSequence: BigInt.zero,
            throughSequence: BigInt.from(3),
            eventCount: 3,
            mayHaveMore: false,
          ),
        ),
      );
      frames.add(
        ClientGatewayRequestStatusFrame(
          status(requestId: 'request-a', acceptedSequence: 1),
        ),
      );
      frames.add(
        ClientGatewayRequestStatusFrame(
          status(requestId: 'request-b', acceptedSequence: 2),
        ),
      );

      await waitUntil(() => commands.replays.length == 2);
      expect(commands.replays.last.afterSequence, BigInt.from(2));
      frames.add(ClientGatewayEventFrame(event(3, requestId: 'request-a')));
      final secondReplay = commands.replays.last;
      frames.add(
        ClientGatewayReplayCompletedFrame(
          ClientReplayCompletion(
            commandId: secondReplay.commandId,
            conversationId: 'conversation-1',
            afterSequence: BigInt.from(2),
            throughSequence: BigInt.from(3),
            eventCount: 1,
            mayHaveMore: false,
          ),
        ),
      );
      await frames.close();
      await running;

      expect(commands.acknowledgements.map((ack) => ack.sequence), [
        BigInt.one,
        BigInt.from(2),
        BigInt.from(3),
      ]);
    },
  );

  test('fails closed when recovered route disagrees and never Acks', () async {
    final ledger = FakeEventLedger();
    final commands = FakeCommandPort();
    final frames = StreamController<ClientGatewayFrame>();
    final running = router(ledger).run(frames.stream, commands);

    frames.add(
      ClientGatewayEventFrame(event(1, kind: ClientEventKind.requestAccepted)),
    );
    await waitUntil(() => commands.statuses.length == 1);
    frames.add(
      ClientGatewayRequestStatusFrame(
        ClientRequestStatusSnapshot(
          requestId: 'request-1',
          originDeviceId: 'different-device',
          conversationId: 'conversation-1',
          sessionId: 'session-1',
          state: ClientRequestState.accepted,
          nodeId: 'node-1',
          agentId: 'agent-1',
          capabilityRevision: 'capability-revision-1',
          acceptedSequence: BigInt.one,
          failure: null,
        ),
      ),
    );

    await expectLater(
      running,
      throwsA(
        isA<GatewayFrameRouterException>().having(
          (error) => error.code,
          'code',
          'request_identity_conflict',
        ),
      ),
    );
    expect(commands.closed, isTrue);
    expect(commands.acknowledgements, isEmpty);
  });

  test(
    'requests one gap replay and never treats it as a command resubmit',
    () async {
      final ledger = FakeEventLedger();
      ledger.requests['request-1'] = route();
      final commands = FakeCommandPort();
      final frames = StreamController<ClientGatewayFrame>();
      final running = router(ledger).run(frames.stream, commands);

      await waitUntil(() => commands.replays.length == 1);
      expect(commands.replays.single.afterSequence, BigInt.zero);
      frames.add(ClientGatewayEventFrame(event(2)));
      frames.add(ClientGatewayEventFrame(event(2)));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(commands.replays, hasLength(1));
      expect(commands.statuses, isEmpty);
      expect(commands.acknowledgements, isEmpty);

      await frames.close();
      await running;
    },
  );

  test('closes the stream and emits no Ack when commit is uncertain', () async {
    final ledger = FakeEventLedger()..failCommit = true;
    ledger.requests['request-1'] = route(accepted: false);
    final commands = FakeCommandPort();
    final frames = StreamController<ClientGatewayFrame>();
    final running = router(ledger).run(frames.stream, commands);
    await waitUntil(() => commands.replays.length == 1);

    frames.add(
      ClientGatewayEventFrame(event(1, kind: ClientEventKind.requestAccepted)),
    );
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

    expect(commands.closed, isTrue);
    expect(commands.acknowledgements, isEmpty);
  });
}
