import 'package:agent_talk_client/application/client_event_convergence.dart';
import 'package:agent_talk_client/domain/client_event.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeClientEventLedger implements ClientEventLedger {
  final requests = <String, TrackedClientRequest>{};
  final cursors = <String, ConversationEventCursor>{};
  final events = <String, Map<BigInt, ClientEventRecord>>{};
  var commitCalls = 0;
  var failCommit = false;
  var failAfterCommit = false;

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
  String deviceId = 'device-1',
  String conversationId = 'conversation-1',
  String? sessionId = 'session-1',
  String? requestId = 'request-1',
  String digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  ClientEventKind kind = ClientEventKind.messageCompleted,
  ClientEventContent? content,
}) => ClientEventRecord(
  eventId: eventId,
  connectionId: connectionId,
  deviceId: deviceId,
  conversationId: conversationId,
  sessionId: sessionId,
  requestId: requestId,
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, sequence),
  kind: kind,
  content:
      content ??
      (kind == ClientEventKind.connectionReady
          ? const SafeMessageClientEventContent('Connected.')
          : MessageClientEventContent(
              text: 'Complete full reply $sequence',
              revision: BigInt.from(sequence),
            )),
  envelopeSha256: digest,
);

TrackedClientRequest request() => TrackedClientRequest(
  deviceId: 'device-1',
  conversationId: 'conversation-1',
  sessionId: 'session-1',
  requestId: 'request-1',
);

void main() {
  test(
    'commits the complete next event before returning an exact Ack',
    () async {
      final ledger = FakeClientEventLedger();
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(
        ledger: ledger,
        expectedDeviceId: 'device-1',
      );
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
      final convergence = ClientEventConvergence(
        ledger: ledger,
        expectedDeviceId: 'device-1',
      );

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
      final convergence = ClientEventConvergence(
        ledger: ledger,
        expectedDeviceId: 'device-1',
      );
      final incoming = event();
      await convergence.accept(incoming);

      final duplicate = await convergence.accept(incoming);
      expect(duplicate, isA<ClientEventDuplicate>());
      expect(ledger.commitCalls, 1);

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
    'rejects wrong device, request, conversation, and session facts',
    () async {
      final ledger = FakeClientEventLedger();
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(
        ledger: ledger,
        expectedDeviceId: 'device-1',
      );

      for (final incoming in [
        event(deviceId: 'device-2'),
        event(requestId: 'request-unknown'),
        event(conversationId: 'conversation-2'),
        event(sessionId: 'session-2'),
      ]) {
        await expectLater(
          convergence.accept(incoming),
          throwsA(isA<ClientEventConvergenceException>()),
        );
      }
      expect(ledger.commitCalls, 0);
    },
  );

  test(
    'does not Ack an uncertain write and redacts storage diagnostics',
    () async {
      final ledger = FakeClientEventLedger()..failCommit = true;
      ledger.requests['request-1'] = request();
      final convergence = ClientEventConvergence(
        ledger: ledger,
        expectedDeviceId: 'device-1',
      );

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
    final convergence = ClientEventConvergence(
      ledger: ledger,
      expectedDeviceId: 'device-1',
    );

    final result = await convergence.accept(event());

    expect(result, isA<ClientEventDuplicate>());
    expect(ledger.cursors['conversation-1']!.eventId, 'event-1');
  });

  test('allows only connection facts to omit a request identity', () async {
    final ledger = FakeClientEventLedger();
    final convergence = ClientEventConvergence(
      ledger: ledger,
      expectedDeviceId: 'device-1',
    );

    await expectLater(
      convergence.accept(event(requestId: null)),
      throwsA(
        isA<ClientEventConvergenceException>().having(
          (error) => error.code,
          'code',
          'request_missing',
        ),
      ),
    );
    final connection = await convergence.accept(
      event(
        requestId: null,
        sessionId: null,
        kind: ClientEventKind.connectionReady,
      ),
    );
    expect(connection, isA<ClientEventCommitted>());
  });
}
