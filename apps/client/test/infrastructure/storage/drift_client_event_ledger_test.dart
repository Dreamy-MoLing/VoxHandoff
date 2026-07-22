import 'dart:io';

import 'package:agent_talk_client/domain/client_event.dart';
import 'package:agent_talk_client/infrastructure/storage/drift_client_event_ledger.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _originDeviceId = 'origin-device-1';
const _conversationId = 'conversation-1';
const _sessionId = 'session-1';
const _requestId = 'request-1';

TrackedClientRequest _request({
  String originDeviceId = _originDeviceId,
  String conversationId = _conversationId,
  String? sessionId = _sessionId,
  String requestId = _requestId,
  String nodeId = 'node-1',
  String agentId = 'agent-1',
  String capabilityRevision = 'capability-revision-1',
  BigInt? acceptedSequence,
}) => TrackedClientRequest(
  originDeviceId: originDeviceId,
  conversationId: conversationId,
  sessionId: sessionId,
  requestId: requestId,
  nodeId: nodeId,
  agentId: agentId,
  capabilityRevision: capabilityRevision,
  acceptedSequence: acceptedSequence,
);

LocalClientSubmission _submission({
  String requestId = _requestId,
  String originDeviceId = _originDeviceId,
  String commandId = 'command-1',
  String idempotencyKey = 'idempotency-key-1',
  String confirmedTextSha256 =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  LocalClientSubmissionDisposition disposition =
      LocalClientSubmissionDisposition.prepared,
}) => LocalClientSubmission(
  requestId: requestId,
  originDeviceId: originDeviceId,
  commandId: commandId,
  idempotencyKey: idempotencyKey,
  confirmedTextSha256: confirmedTextSha256,
  disposition: disposition,
);

ClientEventRecord _event({
  required int sequence,
  required ClientEventKind kind,
  required ClientEventContent content,
  String? eventId,
  String originDeviceId = _originDeviceId,
  String conversationId = _conversationId,
  String? sessionId = _sessionId,
  String requestId = _requestId,
}) => ClientEventRecord(
  eventId: eventId ?? 'event-$sequence',
  connectionId: 'node-connection-1',
  originDeviceId: originDeviceId,
  conversationId: conversationId,
  sessionId: sessionId,
  requestId: requestId,
  sequence: BigInt.from(sequence),
  occurredAt: DateTime.utc(2030, 1, 1, 0, 0, 0, sequence),
  kind: kind,
  content: content,
  envelopeSha256: sequence.toRadixString(16).padLeft(64, '0'),
);

void main() {
  group('DriftClientEventLedger memory database', () {
    late DriftClientEventLedger ledger;
    late NativeDatabase executor;

    setUp(() {
      executor = NativeDatabase.memory();
      ledger = DriftClientEventLedger(executor);
    });

    tearDown(() => ledger.close());

    test(
      'round-trips every typed payload and canonical storage types',
      () async {
        await ledger.trackRequest(_request());
        final events = <ClientEventRecord>[
          _event(
            sequence: 1,
            kind: ClientEventKind.requestAccepted,
            content: const SafeMessageClientEventContent('Accepted.'),
          ),
          _event(
            sequence: 2,
            kind: ClientEventKind.messageCompleted,
            content: MessageClientEventContent(
              text: 'SYNTHETIC-FULL-REPLY remains complete',
              revision: BigInt.parse('18446744073709551615'),
            ),
          ),
          _event(
            sequence: 3,
            kind: ClientEventKind.toolCompleted,
            content: const ToolClientEventContent(
              toolName: 'read_file',
              stage: 'completed',
              safeSummary: 'Read one project file.',
            ),
          ),
          _event(
            sequence: 4,
            kind: ClientEventKind.approvalRequired,
            content: ApprovalClientEventContent(
              approvalId: 'approval-1',
              safeSummary: 'Publish a release.',
              operationSummarySha256: 'a' * 64,
              expiresAt: DateTime.utc(2030, 1, 2),
            ),
          ),
          _event(
            sequence: 5,
            kind: ClientEventKind.clarificationRequired,
            content: ClarificationClientEventContent(
              clarificationId: 'clarification-1',
              safePrompt: 'Which target should be used?',
              expiresAt: DateTime.utc(2030, 1, 3),
            ),
          ),
          _event(
            sequence: 6,
            kind: ClientEventKind.requestFailed,
            content: const TerminalClientEventContent(
              ClientStageFailure(
                stage: ClientFailureStage.agent,
                category: ClientFailureCategory.upstream,
                code: 'agent_unavailable',
                safeMessage: 'The Agent is unavailable.',
                retryable: true,
              ),
            ),
          ),
          _event(
            sequence: 7,
            kind: ClientEventKind.unsupported,
            content: const UnsupportedClientEventContent(
              nativeTypeNumber: 99,
              safeMessage: 'Upgrade required.',
            ),
          ),
        ];

        for (var index = 0; index < events.length; index += 1) {
          await ledger.commitNextEvent(
            events[index],
            expectedPreviousSequence: BigInt.from(index),
          );
        }

        final storedRequest = await ledger.readRequest(_requestId);
        expect(storedRequest?.originDeviceId, _originDeviceId);
        expect(storedRequest?.conversationId, _conversationId);
        expect(storedRequest?.sessionId, _sessionId);
        expect(storedRequest?.nodeId, 'node-1');
        expect(storedRequest?.agentId, 'agent-1');
        expect(storedRequest?.capabilityRevision, 'capability-revision-1');
        expect(storedRequest?.acceptedSequence, BigInt.one);

        final cursor = await ledger.readCursor(_conversationId);
        expect(cursor?.sequence, BigInt.from(7));
        expect(cursor?.eventId, 'event-7');

        final stored = await ledger.listConversationEvents(_conversationId);
        expect(stored, hasLength(7));
        expect(stored.map((event) => event.kind), [
          ClientEventKind.requestAccepted,
          ClientEventKind.messageCompleted,
          ClientEventKind.toolCompleted,
          ClientEventKind.approvalRequired,
          ClientEventKind.clarificationRequired,
          ClientEventKind.requestFailed,
          ClientEventKind.unsupported,
        ]);
        final message = stored[1].content as MessageClientEventContent;
        expect(message.text, 'SYNTHETIC-FULL-REPLY remains complete');
        expect(message.revision, BigInt.parse('18446744073709551615'));
        final approval = stored[3].content as ApprovalClientEventContent;
        expect(approval.approvalId, 'approval-1');
        expect(approval.expiresAt, DateTime.utc(2030, 1, 2));
        final clarification =
            stored[4].content as ClarificationClientEventContent;
        expect(clarification.safePrompt, 'Which target should be used?');
        final terminal = stored[5].content as TerminalClientEventContent;
        expect(terminal.failure?.stage, ClientFailureStage.agent);
        expect(terminal.failure?.retryable, isTrue);

        final page = await ledger.listConversationEvents(
          _conversationId,
          afterSequence: BigInt.from(5),
        );
        expect(page.map((event) => event.sequence), [
          BigInt.from(6),
          BigInt.from(7),
        ]);
        final watched = await ledger
            .watchConversationEvents(
              _conversationId,
              afterSequence: BigInt.from(6),
            )
            .first;
        expect(watched.single.eventId, 'event-7');
        final watchedRequests = await ledger.watchTrackedRequests().first;
        expect(watchedRequests.single.requestId, _requestId);
        expect(await ledger.listTrackedConversationIds(), [_conversationId]);

        final raw = (await executor.runSelect(
          'SELECT sequence_text, payload_revision_text, '
          'typeof(sequence_text) AS sequence_type, occurred_at_micros '
          'FROM client_events WHERE event_id = ?',
          const ['event-2'],
        )).single;
        expect(raw['sequence_text'], '00000000000000000002');
        expect(raw['payload_revision_text'], '18446744073709551615');
        expect(raw['sequence_type'], 'text');
        expect(
          raw['occurred_at_micros'],
          events[1].occurredAt.microsecondsSinceEpoch,
        );
      },
    );

    test('checks route and cursor in one rollback-safe transaction', () async {
      await ledger.trackRequest(_request());

      final wrongRoute = _event(
        sequence: 1,
        kind: ClientEventKind.messageCompleted,
        content: MessageClientEventContent(
          text: 'Wrong route',
          revision: BigInt.one,
        ),
        originDeviceId: 'different-origin-device',
      );
      await expectLater(
        ledger.commitNextEvent(
          wrongRoute,
          expectedPreviousSequence: BigInt.zero,
        ),
        throwsA(
          isA<DriftClientEventLedgerException>().having(
            (error) => error.code,
            'code',
            'request_identity_conflict',
          ),
        ),
      );
      expect(await ledger.readCursor(_conversationId), isNull);
      expect(await ledger.readEvent(_conversationId, BigInt.one), isNull);

      final first = _event(
        sequence: 1,
        kind: ClientEventKind.requestAccepted,
        content: const SafeMessageClientEventContent('Accepted.'),
      );
      await ledger.commitNextEvent(
        first,
        expectedPreviousSequence: BigInt.zero,
      );

      final second = _event(
        sequence: 2,
        kind: ClientEventKind.messageCompleted,
        content: MessageClientEventContent(
          text: 'Second complete reply',
          revision: BigInt.from(2),
        ),
      );
      await expectLater(
        ledger.commitNextEvent(second, expectedPreviousSequence: BigInt.zero),
        throwsA(
          isA<DriftClientEventLedgerException>().having(
            (error) => error.code,
            'code',
            'event_not_next',
          ),
        ),
      );
      expect(await ledger.readEvent(_conversationId, BigInt.from(2)), isNull);

      await expectLater(
        ledger.commitNextEvent(first, expectedPreviousSequence: BigInt.zero),
        throwsA(
          isA<DriftClientEventLedgerException>().having(
            (error) => error.code,
            'code',
            'cursor_conflict',
          ),
        ),
      );

      final duplicateEventId = _event(
        sequence: 2,
        eventId: 'event-1',
        kind: ClientEventKind.messageCompleted,
        content: MessageClientEventContent(
          text: 'SYNTHETIC-CONFLICTING-BODY',
          revision: BigInt.from(2),
        ),
      );
      late Object uniqueFailure;
      try {
        await ledger.commitNextEvent(
          duplicateEventId,
          expectedPreviousSequence: BigInt.one,
        );
        fail('The unique event id conflict must fail.');
      } on Object catch (error) {
        uniqueFailure = error;
      }
      expect(uniqueFailure, isA<DriftClientEventLedgerException>());
      expect(
        uniqueFailure.toString(),
        isNot(contains('SYNTHETIC-CONFLICTING-BODY')),
      );
      expect((await ledger.readCursor(_conversationId))?.sequence, BigInt.one);
      expect(await ledger.readEvent(_conversationId, BigInt.from(2)), isNull);

      await ledger.commitNextEvent(
        second,
        expectedPreviousSequence: BigInt.one,
      );
      expect(
        (await ledger.readCursor(_conversationId))?.sequence,
        BigInt.from(2),
      );
      expect(
        (await ledger.readEvent(
          _conversationId,
          BigInt.one,
        ))?.samePersistedFact(first),
        isTrue,
      );
    });

    test(
      'establishes accepted sequence atomically before later request events',
      () async {
        await ledger.trackRequest(_request());
        final premature = _event(
          sequence: 1,
          kind: ClientEventKind.agentWorking,
          content: const SafeMessageClientEventContent('Working.'),
        );

        await expectLater(
          ledger.commitNextEvent(
            premature,
            expectedPreviousSequence: BigInt.zero,
          ),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'request_not_accepted',
            ),
          ),
        );
        expect(
          (await ledger.readRequest(_requestId))?.acceptedSequence,
          isNull,
        );
        expect(await ledger.readCursor(_conversationId), isNull);

        final accepted = _event(
          sequence: 1,
          kind: ClientEventKind.requestAccepted,
          content: const SafeMessageClientEventContent('Accepted.'),
        );
        await ledger.commitNextEvent(
          accepted,
          expectedPreviousSequence: BigInt.zero,
        );
        expect(
          (await ledger.readRequest(_requestId))?.acceptedSequence,
          BigInt.one,
        );

        await ledger.commitNextEvent(
          _event(
            sequence: 2,
            kind: ClientEventKind.agentWorking,
            content: const SafeMessageClientEventContent('Working.'),
          ),
          expectedPreviousSequence: BigInt.one,
        );
        expect(
          (await ledger.readCursor(_conversationId))?.sequence,
          BigInt.from(2),
        );
      },
    );

    test('rejects a request.accepted fact at another sequence', () async {
      await ledger.trackRequest(_request(acceptedSequence: BigInt.from(2)));
      await expectLater(
        ledger.commitNextEvent(
          _event(
            sequence: 1,
            kind: ClientEventKind.requestAccepted,
            content: const SafeMessageClientEventContent('Accepted.'),
          ),
          expectedPreviousSequence: BigInt.zero,
        ),
        throwsA(
          isA<DriftClientEventLedgerException>().having(
            (error) => error.code,
            'code',
            'accepted_sequence_conflict',
          ),
        ),
      );
      expect(await ledger.readCursor(_conversationId), isNull);
      expect(
        (await ledger.readRequest(_requestId))?.acceptedSequence,
        BigInt.from(2),
      );
    });

    test(
      'enriches acceptance once and rejects route or sequence reuse',
      () async {
        final route = _request();
        await ledger.trackRequest(route);
        await ledger.trackRequest(route);
        await ledger.trackRequest(_request(acceptedSequence: BigInt.one));
        await ledger.trackRequest(route);
        await ledger.trackRequest(_request(acceptedSequence: BigInt.one));

        expect(
          (await ledger.readRequest(_requestId))?.acceptedSequence,
          BigInt.one,
        );

        await expectLater(
          ledger.trackRequest(_request(acceptedSequence: BigInt.from(2))),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'accepted_sequence_conflict',
            ),
          ),
        );

        await expectLater(
          ledger.trackRequest(_request(conversationId: 'conversation-2')),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'request_identity_conflict',
            ),
          ),
        );
        for (final conflicting in [
          _request(nodeId: 'node-2'),
          _request(agentId: 'agent-2'),
          _request(capabilityRevision: 'capability-revision-2'),
        ]) {
          await expectLater(
            ledger.trackRequest(conflicting),
            throwsA(
              isA<DriftClientEventLedgerException>().having(
                (error) => error.code,
                'code',
                'request_identity_conflict',
              ),
            ),
          );
        }
        final stored = await ledger.readRequest(_requestId);
        expect(stored?.conversationId, _conversationId);
        expect(stored?.acceptedSequence, BigInt.one);
      },
    );

    test('rejects conversation acceptance sequence reuse', () async {
      await ledger.trackRequest(_request(acceptedSequence: BigInt.one));
      await expectLater(
        ledger.trackRequest(
          _request(
            requestId: 'request-acceptance-conflict',
            acceptedSequence: BigInt.one,
          ),
        ),
        throwsA(
          isA<DriftClientEventLedgerException>().having(
            (error) => error.code,
            'code',
            'request_track_failed',
          ),
        ),
      );

      expect(await ledger.watchTrackedRequests().first, hasLength(1));
    });

    test(
      'keeps local submission identity separate and advances it one way',
      () async {
        await expectLater(
          ledger.prepareLocalSubmission(
            _request(),
            _submission(
              disposition: LocalClientSubmissionDisposition.outcomeUnknown,
            ),
          ),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'submission_initial_state_invalid',
            ),
          ),
        );
        final prepared = _submission();
        await ledger.prepareLocalSubmission(_request(), prepared);
        await ledger.prepareLocalSubmission(_request(), prepared);

        final stored = await ledger.readLocalSubmission(_requestId);
        expect(stored?.originDeviceId, _originDeviceId);
        expect(stored?.commandId, 'command-1');
        expect(stored?.idempotencyKey, 'idempotency-key-1');
        expect(stored?.confirmedTextSha256, 'b' * 64);
        expect(stored?.disposition, LocalClientSubmissionDisposition.prepared);

        await ledger.advanceLocalSubmission(
          _requestId,
          expectedDisposition: LocalClientSubmissionDisposition.prepared,
          nextDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
        );
        await ledger.advanceLocalSubmission(
          _requestId,
          expectedDisposition: LocalClientSubmissionDisposition.prepared,
          nextDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
        );
        await ledger.advanceLocalSubmission(
          _requestId,
          expectedDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
          nextDisposition: LocalClientSubmissionDisposition.accepted,
        );
        expect(
          (await ledger.readLocalSubmission(_requestId))?.disposition,
          LocalClientSubmissionDisposition.accepted,
        );

        await expectLater(
          ledger.advanceLocalSubmission(
            _requestId,
            expectedDisposition: LocalClientSubmissionDisposition.accepted,
            nextDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
          ),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'submission_transition_invalid',
            ),
          ),
        );

        final columns = await executor.runSelect(
          "PRAGMA table_info('local_submissions')",
          const [],
        );
        expect(
          columns.map((row) => row['name']),
          isNot(contains('confirmed_text')),
        );
      },
    );

    test(
      'rejects local submission identity reuse and remote-only routes',
      () async {
        await ledger.prepareLocalSubmission(_request(), _submission());
        await ledger.trackRequest(_request(requestId: 'request-2'));
        await ledger.trackRequest(_request(requestId: 'request-3'));

        for (final pair in [
          (
            _request(requestId: 'request-2'),
            _submission(
              requestId: 'request-2',
              commandId: 'command-1',
              idempotencyKey: 'idempotency-key-2',
            ),
          ),
          (
            _request(requestId: 'request-3'),
            _submission(
              requestId: 'request-3',
              commandId: 'command-3',
              idempotencyKey: 'idempotency-key-1',
            ),
          ),
        ]) {
          await expectLater(
            ledger.prepareLocalSubmission(pair.$1, pair.$2),
            throwsA(
              isA<DriftClientEventLedgerException>().having(
                (error) => error.code,
                'code',
                'submission_track_failed',
              ),
            ),
          );
        }

        final remoteRoute = _request(requestId: 'remote-request');
        await ledger.trackRequest(remoteRoute);
        expect(await ledger.readLocalSubmission('remote-request'), isNull);

        await expectLater(
          ledger.prepareLocalSubmission(
            remoteRoute,
            _submission(
              requestId: 'remote-request',
              originDeviceId: 'different-origin',
              commandId: 'remote-command',
              idempotencyKey: 'remote-idempotency',
            ),
          ),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'submission_request_conflict',
            ),
          ),
        );
        expect(await ledger.readLocalSubmission('request-2'), isNull);
        expect(await ledger.readLocalSubmission('request-3'), isNull);
      },
    );

    test('request.accepted atomically converges the local outcome', () async {
      await ledger.prepareLocalSubmission(_request(), _submission());
      await ledger.commitNextEvent(
        _event(
          sequence: 1,
          kind: ClientEventKind.requestAccepted,
          content: const SafeMessageClientEventContent('Accepted.'),
        ),
        expectedPreviousSequence: BigInt.zero,
      );

      expect(
        (await ledger.readRequest(_requestId))?.acceptedSequence,
        BigInt.one,
      );
      expect(
        (await ledger.readLocalSubmission(_requestId))?.disposition,
        LocalClientSubmissionDisposition.accepted,
      );
      expect((await ledger.readCursor(_conversationId))?.eventId, 'event-1');
    });

    test(
      'snapshot acceptance resolves unknown but conflicts with rejected',
      () async {
        await ledger.prepareLocalSubmission(_request(), _submission());
        await ledger.advanceLocalSubmission(
          _requestId,
          expectedDisposition: LocalClientSubmissionDisposition.prepared,
          nextDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
        );
        await ledger.trackRequest(_request(acceptedSequence: BigInt.one));
        expect(
          (await ledger.readLocalSubmission(_requestId))?.disposition,
          LocalClientSubmissionDisposition.accepted,
        );

        final rejectedRoute = _request(
          requestId: 'request-rejected',
          conversationId: 'conversation-rejected',
        );
        final rejectedSubmission = _submission(
          requestId: 'request-rejected',
          commandId: 'command-rejected',
          idempotencyKey: 'idempotency-rejected',
        );
        await ledger.prepareLocalSubmission(rejectedRoute, rejectedSubmission);
        await ledger.advanceLocalSubmission(
          rejectedRoute.requestId,
          expectedDisposition: LocalClientSubmissionDisposition.prepared,
          nextDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
        );
        await ledger.advanceLocalSubmission(
          rejectedRoute.requestId,
          expectedDisposition: LocalClientSubmissionDisposition.outcomeUnknown,
          nextDisposition: LocalClientSubmissionDisposition.rejected,
        );

        await expectLater(
          ledger.trackRequest(
            _request(
              requestId: rejectedRoute.requestId,
              conversationId: rejectedRoute.conversationId,
              acceptedSequence: BigInt.one,
            ),
          ),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'submission_state_conflict',
            ),
          ),
        );
        expect(
          (await ledger.readRequest(rejectedRoute.requestId))?.acceptedSequence,
          isNull,
        );
      },
    );

    test('serializes concurrent commits from the same cursor', () async {
      await ledger.trackRequest(_request());
      final candidateA = _event(
        sequence: 1,
        eventId: 'race-event-a',
        kind: ClientEventKind.requestAccepted,
        content: const SafeMessageClientEventContent('Candidate A accepted.'),
      );
      final candidateB = _event(
        sequence: 1,
        eventId: 'race-event-b',
        kind: ClientEventKind.requestAccepted,
        content: const SafeMessageClientEventContent('Candidate B accepted.'),
      );

      Future<Object?> capture(ClientEventRecord candidate) async {
        try {
          await ledger.commitNextEvent(
            candidate,
            expectedPreviousSequence: BigInt.zero,
          );
          return null;
        } on Object catch (error) {
          return error;
        }
      }

      final outcomes = await Future.wait([
        capture(candidateA),
        capture(candidateB),
      ]);
      expect(outcomes.where((outcome) => outcome == null), hasLength(1));
      final failure = outcomes.singleWhere((outcome) => outcome != null);
      expect(failure, isA<DriftClientEventLedgerException>());
      expect(
        (failure as DriftClientEventLedgerException).code,
        anyOf('cursor_conflict', 'event_commit_failed'),
      );

      final stored = await ledger.listConversationEvents(_conversationId);
      expect(stored, hasLength(1));
      expect(
        stored.single.eventId,
        anyOf(candidateA.eventId, candidateB.eventId),
      );
      final cursor = await ledger.readCursor(_conversationId);
      expect(cursor?.sequence, BigInt.one);
      expect(cursor?.eventId, stored.single.eventId);
    });

    test(
      'strict decoder rejects fields belonging to another payload type',
      () async {
        await ledger.trackRequest(_request());
        await executor.runInsert(
          'INSERT INTO client_events '
          '(event_id, connection_id, origin_device_id, conversation_id, '
          'request_id, sequence_text, occurred_at_micros, kind, '
          'payload_safe_message, payload_text, envelope_sha256) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            'corrupt-event',
            'connection-1',
            _originDeviceId,
            _conversationId,
            _requestId,
            '00000000000000000001',
            DateTime.utc(2030).microsecondsSinceEpoch,
            ClientEventKind.agentWorking.name,
            'Working.',
            'field from the wrong payload',
            'f' * 64,
          ],
        );

        await expectLater(
          ledger.readEvent(_conversationId, BigInt.one),
          throwsA(
            isA<DriftClientEventLedgerException>().having(
              (error) => error.code,
              'code',
              'event_payload_corrupt',
            ),
          ),
        );
      },
    );

    test('rejects values outside unsigned 64-bit storage', () async {
      await expectLater(
        ledger.readEvent(_conversationId, BigInt.one << 64),
        throwsA(
          isA<DriftClientEventLedgerException>().having(
            (error) => error.code,
            'code',
            'event_sequence_invalid',
          ),
        ),
      );
    });

    test('enforces uint64 and lowercase hash facts inside SQLite', () async {
      await ledger.prepareLocalSubmission(_request(), _submission());
      await ledger.commitNextEvent(
        _event(
          sequence: 1,
          kind: ClientEventKind.requestAccepted,
          content: const SafeMessageClientEventContent('Accepted.'),
        ),
        expectedPreviousSequence: BigInt.zero,
      );
      await ledger.commitNextEvent(
        _event(
          sequence: 2,
          kind: ClientEventKind.messageCompleted,
          content: MessageClientEventContent(
            text: 'Complete reply.',
            revision: BigInt.one,
          ),
        ),
        expectedPreviousSequence: BigInt.one,
      );
      await ledger.commitNextEvent(
        _event(
          sequence: 3,
          kind: ClientEventKind.approvalRequired,
          content: ApprovalClientEventContent(
            approvalId: 'approval-db-check',
            safeSummary: 'Check one operation.',
            operationSummarySha256: 'a' * 64,
            expiresAt: DateTime.utc(2030, 1, 2),
          ),
        ),
        expectedPreviousSequence: BigInt.from(2),
      );

      for (final statement in [
        "UPDATE tracked_requests SET accepted_sequence_text = '18446744073709551616' WHERE request_id = 'request-1'",
        "UPDATE local_submissions SET confirmed_text_sha256 = '${'A' * 64}' WHERE request_id = 'request-1'",
        "UPDATE local_submissions SET disposition = 'retried' WHERE request_id = 'request-1'",
        "UPDATE client_events SET sequence_text = '18446744073709551616' WHERE event_id = 'event-2'",
        "UPDATE client_events SET payload_revision_text = '18446744073709551616' WHERE event_id = 'event-2'",
        "UPDATE client_events SET envelope_sha256 = '${'A' * 64}' WHERE event_id = 'event-2'",
        "UPDATE client_events SET payload_operation_summary_sha256 = '${'A' * 64}' WHERE event_id = 'event-3'",
        "UPDATE client_events SET request_id = 'missing-request' WHERE event_id = 'event-2'",
        "UPDATE conversation_cursors SET sequence_text = '00000000000000000004' WHERE conversation_id = 'conversation-1'",
        "UPDATE conversation_cursors SET sequence_text = '18446744073709551616' WHERE conversation_id = 'conversation-1'",
      ]) {
        await expectLater(executor.runCustom(statement), throwsA(anything));
      }
      final foreignKeys = await executor.runSelect(
        'PRAGMA foreign_keys',
        const [],
      );
      expect(foreignKeys.single['foreign_keys'], 1);
      final cursorColumns = await executor.runSelect(
        "PRAGMA table_info('conversation_cursors')",
        const [],
      );
      expect(
        cursorColumns.map((row) => row['name']),
        isNot(contains('event_id')),
      );
      expect(
        (await ledger.readRequest(_requestId))?.acceptedSequence,
        BigInt.one,
      );
      expect(
        (await ledger.readCursor(_conversationId))?.sequence,
        BigInt.from(3),
      );
    });

    test('rejects malformed full request routes before storage', () {
      expect(
        () => _request(nodeId: 'bad\nnode'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _submission(confirmedTextSha256: 'A' * 64),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _request(acceptedSequence: BigInt.zero),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => _request(acceptedSequence: BigInt.one << 64),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test(
    'file database preserves complete events across close and reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'agent-talk-drift-ledger-',
      );
      final file = File('${directory.path}/client-events.sqlite');
      DriftClientEventLedger? openLedger;
      addTearDown(() async {
        await openLedger?.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      openLedger = DriftClientEventLedger.openFile(file);
      await openLedger.trackRequest(_request());
      final original = _event(
        sequence: 1,
        kind: ClientEventKind.requestAccepted,
        content: const SafeMessageClientEventContent('Accepted.'),
      );
      await openLedger.commitNextEvent(
        original,
        expectedPreviousSequence: BigInt.zero,
      );
      await openLedger.close();
      openLedger = null;

      openLedger = DriftClientEventLedger.openFile(file);
      final restored = await openLedger.readEvent(_conversationId, BigInt.one);
      expect(restored?.samePersistedFact(original), isTrue);
      expect(
        (await openLedger.readCursor(_conversationId))?.eventId,
        'event-1',
      );
      expect(
        (await openLedger.readRequest(_requestId))?.originDeviceId,
        _originDeviceId,
      );
      expect(
        (await openLedger.readRequest(_requestId))?.acceptedSequence,
        BigInt.one,
      );

      final next = _event(
        sequence: 2,
        kind: ClientEventKind.messageCompleted,
        content: MessageClientEventContent(
          text: 'Complete reply survives restart.',
          revision: BigInt.one,
        ),
      );
      await openLedger.commitNextEvent(
        next,
        expectedPreviousSequence: BigInt.one,
      );
      expect(
        (await openLedger.readCursor(_conversationId))?.sequence,
        BigInt.from(2),
      );
      expect(
        ((await openLedger.readEvent(_conversationId, BigInt.from(2)))!.content
                as MessageClientEventContent)
            .text,
        'Complete reply survives restart.',
      );
    },
  );
}
