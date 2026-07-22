import 'package:agent_talk_client/application/client_event_convergence.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClientEventLedger implements ClientEventLedger {
  final requests = <String, TrackedClientRequest>{};
  final localSubmissions = <String, LocalClientSubmission>{};
  final cursors = <String, ConversationEventCursor>{};
  final events = <String, Map<BigInt, ClientEventRecord>>{};
  var commitCalls = 0;
  var failCommit = false;
  var failAfterCommit = false;

  @override
  Future<void> trackRequest(TrackedClientRequest request) async {
    final existing = requests[request.requestId];
    if (existing != null) throw StateError('request already tracked');
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
    commitCalls += 1;
    if (failCommit) throw StateError('secret-bearing storage diagnostic');
    final current = cursors[event.conversationId]?.sequence ?? BigInt.zero;
    if (current != expectedPreviousSequence ||
        event.sequence != current + BigInt.one) {
      throw StateError('cursor conflict');
    }
    final conversationEvents = events.putIfAbsent(
      event.conversationId,
      () => {},
    );
    if (conversationEvents.containsKey(event.sequence)) {
      throw StateError('event conflict');
    }
    conversationEvents[event.sequence] = event;
    cursors[event.conversationId] = ConversationEventCursor(
      conversationId: event.conversationId,
      sequence: event.sequence,
      eventId: event.eventId,
    );
    if (failAfterCommit) {
      throw StateError('commit response lost with secret-bearing diagnostic');
    }
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

ClientEventRecord event({
  int sequence = 1,
  String eventId = 'event-1',
  String connectionId = 'node-connection-1',
  String originDeviceId = 'origin-device-a',
  String conversationId = 'conversation-1',
  String? sessionId = 'session-1',
  String requestId = 'request-1',
  String digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  ClientEventKind kind = ClientEventKind.messageCompleted,
  ClientEventContent? content,
}) => ClientEventRecord(
  eventId: eventId,
  connectionId: connectionId,
  originDeviceId: originDeviceId,
  conversationId: conversationId,
  sessionId: sessionId,
  requestId: requestId,
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
  kind: kind,
  content:
      content ??
      MessageClientEventContent(
        text: 'Complete full reply $sequence',
        revision: BigInt.from(sequence),
      ),
  envelopeSha256: digest,
);

TrackedClientRequest request() => TrackedClientRequest(
  originDeviceId: 'origin-device-a',
  conversationId: 'conversation-1',
  sessionId: 'session-1',
  requestId: 'request-1',
  nodeId: 'node-1',
  agentId: 'agent-1',
  capabilityRevision: 'capability-revision-1',
);

void main() {
  test(
    'commits the complete next event before returning an exact Ack',
    () async {
      final ledger = FakeClientEventLedger();
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(ledger: ledger);
      final incoming = event();

      final result = await convergence.accept(incoming);

      expect(result, isA<ClientEventCommitted>());
      final committed = result as ClientEventCommitted;
      expect(committed.event.content, isA<MessageClientEventContent>());
      expect(
        (committed.event.content as MessageClientEventContent).text,
        'Complete full reply 1',
      );
      expect(committed.acknowledgement.conversationId, 'conversation-1');
      expect(committed.acknowledgement.sequence, BigInt.one);
      expect(committed.acknowledgement.eventId, 'event-1');
      expect(ledger.cursors['conversation-1']!.sequence, BigInt.one);
    },
  );

  test(
    'returns one replay fact for a gap without persisting or Acking it',
    () async {
      final ledger = FakeClientEventLedger();
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(ledger: ledger);

      final result = await convergence.accept(
        event(sequence: 3, eventId: 'event-3'),
      );

      expect(result, isA<ClientEventGap>());
      final replay = (result as ClientEventGap).replay;
      expect(replay.conversationId, 'conversation-1');
      expect(replay.afterSequence, BigInt.zero);
      expect(replay.maximumEvents, 500);
      expect(ledger.commitCalls, 0);
      expect(ledger.cursors, isEmpty);
    },
  );

  test(
    'Acks exact duplicates but rejects any durable identity conflict',
    () async {
      final ledger = FakeClientEventLedger();
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(ledger: ledger);
      final incoming = event();
      await convergence.accept(incoming);

      final duplicate = await convergence.accept(incoming);
      expect(duplicate, isA<ClientEventDuplicate>());
      expect(ledger.commitCalls, 1);

      await expectLater(
        convergence.accept(
          event(
            content: MessageClientEventContent(
              text: 'Conflicting full reply under the same digest',
              revision: BigInt.one,
            ),
          ),
        ),
        throwsA(
          isA<ClientEventConvergenceException>().having(
            (error) => error.code,
            'code',
            'event_identity_conflict',
          ),
        ),
      );

      await expectLater(
        convergence.accept(event(connectionId: 'stale-node-connection')),
        throwsA(
          isA<ClientEventConvergenceException>().having(
            (error) => error.code,
            'code',
            'event_identity_conflict',
          ),
        ),
      );
    },
  );

  test(
    'accepts another device origin but rejects a forged tracked route',
    () async {
      final ledger = FakeClientEventLedger();
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(ledger: ledger);

      final accepted = await convergence.accept(event());
      expect(accepted, isA<ClientEventCommitted>());

      final freshLedger = FakeClientEventLedger();
      freshLedger.requests['request-1'] = request();
      final freshConvergence = ClientEventConvergence(ledger: freshLedger);

      for (final incoming in [
        event(originDeviceId: 'forged-origin-device'),
        event(requestId: 'request-unknown'),
        event(conversationId: 'conversation-2'),
        event(sessionId: 'session-2'),
      ]) {
        await expectLater(
          freshConvergence.accept(incoming),
          throwsA(isA<ClientEventConvergenceException>()),
        );
      }
      expect(freshLedger.commitCalls, 0);
    },
  );

  test(
    'does not Ack an uncertain write and redacts storage diagnostics',
    () async {
      final ledger = FakeClientEventLedger()..failCommit = true;
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(ledger: ledger);

      await expectLater(
        convergence.accept(event()),
        throwsA(
          isA<ClientEventConvergenceException>()
              .having((error) => error.code, 'code', 'storage_failure')
              .having(
                (error) => error.toString(),
                'redacted string',
                isNot(contains('secret-bearing')),
              ),
        ),
      );
      expect(ledger.cursors, isEmpty);
    },
  );

  test('recovers an exact commit whose local response was lost', () async {
    final ledger = FakeClientEventLedger()..failAfterCommit = true;
    ledger.requests['request-1'] = request();
    final convergence = ClientEventConvergence(ledger: ledger);

    final result = await convergence.accept(event());

    expect(result, isA<ClientEventDuplicate>());
    expect(ledger.cursors['conversation-1']!.eventId, 'event-1');
  });

  test('the domain rejects an event without request identity', () {
    expect(() => event(requestId: ''), throwsA(isA<FormatException>()));
  });
}
