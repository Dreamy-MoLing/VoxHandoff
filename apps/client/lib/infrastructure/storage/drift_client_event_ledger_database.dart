part of 'drift_client_event_ledger.dart';

@DriftDatabase(
  tables: [
    _TrackedRequests,
    _LocalSubmissions,
    _ClientEvents,
    _ConversationCursors,
  ],
)
class _EventLedgerDatabase extends _$_EventLedgerDatabase
    implements ClientEventLedger {
  _EventLedgerDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Records the exact route before a request can accept any Agent event.
  /// Repeating an identical route is idempotent; reusing an id for a different
  /// route fails closed.
  @override
  Future<void> trackRequest(TrackedClientRequest request) async {
    try {
      await transaction(() async {
        await _upsertTrackedRequest(request);
      });
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('request_track_failed');
    }
  }

  @override
  Future<void> prepareLocalSubmission(
    TrackedClientRequest route,
    LocalClientSubmission submission,
  ) async {
    if (submission.disposition != LocalClientSubmissionDisposition.prepared) {
      throw const DriftClientEventLedgerException(
        'submission_initial_state_invalid',
      );
    }
    if (route.requestId != submission.requestId ||
        route.originDeviceId != submission.originDeviceId) {
      throw const DriftClientEventLedgerException(
        'submission_request_conflict',
      );
    }
    try {
      await transaction(() async {
        final acceptedSequence = await _upsertTrackedRequest(route);
        if (acceptedSequence != null) {
          throw const DriftClientEventLedgerException(
            'submission_route_already_accepted',
          );
        }
        final existing =
            await (select(localSubmissions)
                  ..where((row) => row.requestId.equals(submission.requestId)))
                .getSingleOrNull();
        if (existing != null) {
          if (!_sameLocalSubmissionIdentity(existing, submission)) {
            throw const DriftClientEventLedgerException(
              'submission_identity_conflict',
            );
          }
          return;
        }
        await into(localSubmissions).insert(
          _LocalSubmissionsCompanion.insert(
            requestId: submission.requestId,
            originDeviceId: submission.originDeviceId,
            commandId: submission.commandId,
            idempotencyKey: submission.idempotencyKey,
            confirmedTextSha256: submission.confirmedTextSha256,
            disposition: submission.disposition.name,
          ),
        );
      });
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('submission_track_failed');
    }
  }

  Future<BigInt?> _upsertTrackedRequest(TrackedClientRequest request) async {
    final existing =
        await (select(trackedRequests)
              ..where((row) => row.requestId.equals(request.requestId)))
            .getSingleOrNull();
    if (existing != null) {
      if (!_sameRequestRoute(existing, request)) {
        throw const DriftClientEventLedgerException(
          'request_identity_conflict',
        );
      }
      final storedAccepted = _decodeOptionalAcceptedSequence(existing);
      final incomingAccepted = request.acceptedSequence;
      if (storedAccepted == null && incomingAccepted != null) {
        final affected =
            await (update(trackedRequests)..where(
                  (row) =>
                      row.requestId.equals(request.requestId) &
                      row.acceptedSequenceText.isNull(),
                ))
                .write(
                  _TrackedRequestsCompanion(
                    acceptedSequenceText: Value(
                      _encodeUint64(
                        incomingAccepted,
                        allowZero: false,
                        code: 'accepted_sequence_invalid',
                      ),
                    ),
                  ),
                );
        if (affected != 1) {
          throw const DriftClientEventLedgerException(
            'accepted_sequence_conflict',
          );
        }
        await _reconcileLocalSubmissionAccepted(request.requestId);
        return incomingAccepted;
      }
      if (storedAccepted != null &&
          incomingAccepted != null &&
          storedAccepted != incomingAccepted) {
        throw const DriftClientEventLedgerException(
          'accepted_sequence_conflict',
        );
      }
      if (storedAccepted != null) {
        await _reconcileLocalSubmissionAccepted(request.requestId);
      }
      return storedAccepted;
    }
    await into(trackedRequests).insert(
      _TrackedRequestsCompanion.insert(
        requestId: request.requestId,
        originDeviceId: request.originDeviceId,
        conversationId: request.conversationId,
        sessionId: Value(request.sessionId),
        nodeId: request.nodeId,
        agentId: request.agentId,
        capabilityRevision: request.capabilityRevision,
        acceptedSequenceText: Value(
          request.acceptedSequence == null
              ? null
              : _encodeUint64(
                  request.acceptedSequence!,
                  allowZero: false,
                  code: 'accepted_sequence_invalid',
                ),
        ),
      ),
    );
    return request.acceptedSequence;
  }

  Future<void> _reconcileLocalSubmissionAccepted(String requestId) async {
    final local = await (select(
      localSubmissions,
    )..where((row) => row.requestId.equals(requestId))).getSingleOrNull();
    if (local == null) return;
    final current = _decodeSubmissionDisposition(local.disposition);
    if (current == LocalClientSubmissionDisposition.accepted) return;
    if (current == LocalClientSubmissionDisposition.rejected) {
      throw const DriftClientEventLedgerException('submission_state_conflict');
    }
    final affected =
        await (update(localSubmissions)..where(
              (row) =>
                  row.requestId.equals(requestId) &
                  row.disposition.equals(current.name),
            ))
            .write(
              const _LocalSubmissionsCompanion(disposition: Value('accepted')),
            );
    if (affected != 1) {
      throw const DriftClientEventLedgerException('submission_state_conflict');
    }
  }

  @override
  Future<LocalClientSubmission?> readLocalSubmission(String requestId) async {
    _validateOpaque(requestId, code: 'request_id_invalid');
    try {
      final row =
          await (select(localSubmissions)
                ..where((candidate) => candidate.requestId.equals(requestId)))
              .getSingleOrNull();
      return row == null ? null : _decodeLocalSubmission(row);
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('submission_read_failed');
    }
  }

  @override
  Future<void> advanceLocalSubmission(
    String requestId, {
    required LocalClientSubmissionDisposition expectedDisposition,
    required LocalClientSubmissionDisposition nextDisposition,
  }) async {
    _validateOpaque(requestId, code: 'request_id_invalid');
    if (!_safeSubmissionTransition(expectedDisposition, nextDisposition)) {
      throw const DriftClientEventLedgerException(
        'submission_transition_invalid',
      );
    }
    try {
      await transaction(() async {
        final existing = await (select(
          localSubmissions,
        )..where((row) => row.requestId.equals(requestId))).getSingleOrNull();
        if (existing == null) {
          throw const DriftClientEventLedgerException('submission_unknown');
        }
        final current = _decodeSubmissionDisposition(existing.disposition);
        if (current == nextDisposition) return;
        if (current != expectedDisposition) {
          throw const DriftClientEventLedgerException(
            'submission_state_conflict',
          );
        }
        final affected =
            await (update(localSubmissions)..where(
                  (row) =>
                      row.requestId.equals(requestId) &
                      row.disposition.equals(expectedDisposition.name),
                ))
                .write(
                  _LocalSubmissionsCompanion(
                    disposition: Value(nextDisposition.name),
                  ),
                );
        if (affected != 1) {
          throw const DriftClientEventLedgerException(
            'submission_state_conflict',
          );
        }
      });
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('submission_advance_failed');
    }
  }

  @override
  Future<TrackedClientRequest?> readRequest(String requestId) async {
    _validateOpaque(requestId, code: 'request_id_invalid');
    try {
      final row =
          await (select(trackedRequests)
                ..where((candidate) => candidate.requestId.equals(requestId)))
              .getSingleOrNull();
      return row == null ? null : _decodeRequest(row);
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('request_read_failed');
    }
  }

  @override
  Future<ConversationEventCursor?> readCursor(String conversationId) async {
    _validateOpaque(conversationId, code: 'conversation_id_invalid');
    try {
      final row =
          await (select(conversationCursors)..where(
                (candidate) => candidate.conversationId.equals(conversationId),
              ))
              .getSingleOrNull();
      return row == null ? null : await _decodeCursor(row);
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('cursor_read_failed');
    }
  }

  @override
  Future<List<String>> listTrackedConversationIds() async {
    try {
      final rows = await customSelect(
        'SELECT DISTINCT conversation_id FROM tracked_requests '
        'ORDER BY conversation_id',
        readsFrom: {trackedRequests},
      ).get();
      return rows
          .map((row) => row.read<String>('conversation_id'))
          .toList(growable: false);
    } on Object {
      throw const DriftClientEventLedgerException('conversation_list_failed');
    }
  }

  @override
  Future<ClientEventRecord?> readEvent(
    String conversationId,
    BigInt sequence,
  ) async {
    _validateOpaque(conversationId, code: 'conversation_id_invalid');
    final sequenceText = _encodeUint64(
      sequence,
      allowZero: false,
      code: 'event_sequence_invalid',
    );
    try {
      final row = await _readStoredEvent(conversationId, sequenceText);
      return row == null ? null : _decodeEvent(row);
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('event_read_failed');
    }
  }

  Future<List<ClientEventRecord>> listConversationEvents(
    String conversationId, {
    BigInt? afterSequence,
    int limit = 500,
  }) async {
    _validateOpaque(conversationId, code: 'conversation_id_invalid');
    final after = _encodeUint64(
      afterSequence ?? BigInt.zero,
      allowZero: true,
      code: 'event_sequence_invalid',
    );
    _validateLimit(limit);
    try {
      final query = select(clientEvents)
        ..where(
          (row) =>
              row.conversationId.equals(conversationId) &
              row.sequenceText.isBiggerThanValue(after),
        )
        ..orderBy([(row) => OrderingTerm.asc(row.sequenceText)])
        ..limit(limit);
      return (await query.get()).map(_decodeEvent).toList(growable: false);
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('event_list_failed');
    }
  }

  Stream<List<ClientEventRecord>> watchConversationEvents(
    String conversationId, {
    BigInt? afterSequence,
    int limit = 500,
  }) async* {
    _validateOpaque(conversationId, code: 'conversation_id_invalid');
    final after = _encodeUint64(
      afterSequence ?? BigInt.zero,
      allowZero: true,
      code: 'event_sequence_invalid',
    );
    _validateLimit(limit);
    final query = select(clientEvents)
      ..where(
        (row) =>
            row.conversationId.equals(conversationId) &
            row.sequenceText.isBiggerThanValue(after),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.sequenceText)])
      ..limit(limit);
    try {
      await for (final rows in query.watch()) {
        yield rows.map(_decodeEvent).toList(growable: false);
      }
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('event_watch_failed');
    }
  }

  Stream<List<TrackedClientRequest>> watchTrackedRequests() async* {
    final query = select(trackedRequests)
      ..orderBy([(row) => OrderingTerm.asc(row.requestId)]);
    try {
      await for (final rows in query.watch()) {
        yield rows.map(_decodeRequest).toList(growable: false);
      }
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('request_watch_failed');
    }
  }

  @override
  Future<void> commitNextEvent(
    ClientEventRecord event, {
    required BigInt expectedPreviousSequence,
  }) async {
    final expectedText = _encodeUint64(
      expectedPreviousSequence,
      allowZero: true,
      code: 'cursor_sequence_invalid',
    );
    if (event.sequence != expectedPreviousSequence + BigInt.one) {
      throw const DriftClientEventLedgerException('event_not_next');
    }
    final storedEvent = _encodeEvent(event);

    try {
      await transaction(() async {
        await _verifyRequestRoute(event);

        final cursor =
            await (select(conversationCursors)..where(
                  (row) => row.conversationId.equals(event.conversationId),
                ))
                .getSingleOrNull();
        if (cursor == null) {
          if (expectedPreviousSequence != BigInt.zero) {
            throw const DriftClientEventLedgerException('cursor_conflict');
          }
        } else {
          final current = _decodeUint64(
            cursor.sequenceText,
            allowZero: false,
            code: 'cursor_corrupt',
          );
          if (current != expectedPreviousSequence ||
              cursor.sequenceText != expectedText) {
            throw const DriftClientEventLedgerException('cursor_conflict');
          }
        }

        await into(clientEvents).insert(storedEvent);

        final nextText = _encodeUint64(
          event.sequence,
          allowZero: false,
          code: 'event_sequence_invalid',
        );
        if (cursor == null) {
          await into(conversationCursors).insert(
            _ConversationCursorsCompanion.insert(
              conversationId: event.conversationId,
              sequenceText: nextText,
            ),
          );
        } else {
          final affected =
              await (update(conversationCursors)..where(
                    (row) =>
                        row.conversationId.equals(event.conversationId) &
                        row.sequenceText.equals(expectedText),
                  ))
                  .write(
                    _ConversationCursorsCompanion(
                      sequenceText: Value(nextText),
                    ),
                  );
          if (affected != 1) {
            throw const DriftClientEventLedgerException('cursor_conflict');
          }
        }
      });
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      // Do not expose SQLite diagnostics: an event can contain full Agent text.
      throw const DriftClientEventLedgerException('event_commit_failed');
    }
  }

  Future<void> _verifyRequestRoute(ClientEventRecord event) async {
    final requestId = event.requestId;
    final row =
        await (select(trackedRequests)
              ..where((candidate) => candidate.requestId.equals(requestId)))
            .getSingleOrNull();
    if (row == null) {
      throw const DriftClientEventLedgerException('request_unknown');
    }
    if (row.requestId != requestId ||
        row.originDeviceId != event.originDeviceId ||
        row.conversationId != event.conversationId ||
        row.sessionId != event.sessionId) {
      throw const DriftClientEventLedgerException('request_identity_conflict');
    }

    final acceptedSequence = _decodeOptionalAcceptedSequence(row);
    if (event.kind == ClientEventKind.requestAccepted) {
      if (acceptedSequence == null) {
        final affected =
            await (update(trackedRequests)..where(
                  (candidate) =>
                      candidate.requestId.equals(requestId) &
                      candidate.acceptedSequenceText.isNull(),
                ))
                .write(
                  _TrackedRequestsCompanion(
                    acceptedSequenceText: Value(
                      _encodeUint64(
                        event.sequence,
                        allowZero: false,
                        code: 'accepted_sequence_invalid',
                      ),
                    ),
                  ),
                );
        if (affected != 1) {
          throw const DriftClientEventLedgerException(
            'accepted_sequence_conflict',
          );
        }
      } else if (acceptedSequence != event.sequence) {
        throw const DriftClientEventLedgerException(
          'accepted_sequence_conflict',
        );
      }
      await _reconcileLocalSubmissionAccepted(requestId);
      return;
    }
    if (acceptedSequence == null) {
      throw const DriftClientEventLedgerException('request_not_accepted');
    }
    if (event.sequence <= acceptedSequence) {
      throw const DriftClientEventLedgerException('event_precedes_acceptance');
    }
  }

  Future<_StoredClientEvent?> _readStoredEvent(
    String conversationId,
    String sequenceText,
  ) =>
      (select(clientEvents)..where(
            (row) =>
                row.conversationId.equals(conversationId) &
                row.sequenceText.equals(sequenceText),
          ))
          .getSingleOrNull();

  bool _sameRequestRoute(
    _StoredTrackedRequest stored,
    TrackedClientRequest request,
  ) =>
      stored.requestId == request.requestId &&
      stored.originDeviceId == request.originDeviceId &&
      stored.conversationId == request.conversationId &&
      stored.sessionId == request.sessionId &&
      stored.nodeId == request.nodeId &&
      stored.agentId == request.agentId &&
      stored.capabilityRevision == request.capabilityRevision;

  bool _sameLocalSubmissionIdentity(
    _StoredLocalSubmission stored,
    LocalClientSubmission submission,
  ) =>
      stored.requestId == submission.requestId &&
      stored.originDeviceId == submission.originDeviceId &&
      stored.commandId == submission.commandId &&
      stored.idempotencyKey == submission.idempotencyKey &&
      stored.confirmedTextSha256 == submission.confirmedTextSha256;

  LocalClientSubmission _decodeLocalSubmission(_StoredLocalSubmission row) {
    try {
      return LocalClientSubmission(
        requestId: row.requestId,
        originDeviceId: row.originDeviceId,
        commandId: row.commandId,
        idempotencyKey: row.idempotencyKey,
        confirmedTextSha256: row.confirmedTextSha256,
        disposition: _decodeSubmissionDisposition(row.disposition),
      );
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('submission_corrupt');
    }
  }

  LocalClientSubmissionDisposition _decodeSubmissionDisposition(String value) =>
      _decodeEnum(
        LocalClientSubmissionDisposition.values,
        value,
        code: 'submission_disposition_corrupt',
      );

  BigInt? _decodeOptionalAcceptedSequence(_StoredTrackedRequest row) {
    final value = row.acceptedSequenceText;
    return value == null
        ? null
        : _decodeUint64(
            value,
            allowZero: false,
            code: 'accepted_sequence_corrupt',
          );
  }

  TrackedClientRequest _decodeRequest(_StoredTrackedRequest row) {
    try {
      return TrackedClientRequest(
        originDeviceId: row.originDeviceId,
        conversationId: row.conversationId,
        sessionId: row.sessionId,
        requestId: row.requestId,
        nodeId: row.nodeId,
        agentId: row.agentId,
        capabilityRevision: row.capabilityRevision,
        acceptedSequence: _decodeOptionalAcceptedSequence(row),
      );
    } on Object {
      throw const DriftClientEventLedgerException('request_corrupt');
    }
  }

  Future<ConversationEventCursor> _decodeCursor(
    _StoredConversationCursor row,
  ) async {
    try {
      final event = await _readStoredEvent(
        row.conversationId,
        row.sequenceText,
      );
      if (event == null) {
        throw const DriftClientEventLedgerException('cursor_corrupt');
      }
      return ConversationEventCursor(
        conversationId: row.conversationId,
        sequence: _decodeUint64(
          row.sequenceText,
          allowZero: false,
          code: 'cursor_corrupt',
        ),
        eventId: event.eventId,
      );
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('cursor_corrupt');
    }
  }

  _ClientEventsCompanion _encodeEvent(ClientEventRecord event) {
    final payload = _encodePayload(event.kind, event.content);
    return _ClientEventsCompanion.insert(
      eventId: event.eventId,
      connectionId: event.connectionId,
      originDeviceId: event.originDeviceId,
      conversationId: event.conversationId,
      sessionId: Value(event.sessionId),
      requestId: event.requestId,
      sequenceText: _encodeUint64(
        event.sequence,
        allowZero: false,
        code: 'event_sequence_invalid',
      ),
      occurredAtMicros: event.occurredAt.microsecondsSinceEpoch,
      kind: event.kind.name,
      payloadSafeMessage: Value(payload.safeMessage),
      payloadText: Value(payload.text),
      payloadRevisionText: Value(payload.revisionText),
      payloadToolName: Value(payload.toolName),
      payloadToolStage: Value(payload.toolStage),
      payloadSafeSummary: Value(payload.safeSummary),
      payloadApprovalId: Value(payload.approvalId),
      payloadOperationSummarySha256: Value(payload.operationSummarySha256),
      payloadExpiresAtMicros: Value(payload.expiresAtMicros),
      payloadClarificationId: Value(payload.clarificationId),
      payloadSafePrompt: Value(payload.safePrompt),
      payloadFailureStage: Value(payload.failureStage),
      payloadFailureCategory: Value(payload.failureCategory),
      payloadFailureCode: Value(payload.failureCode),
      payloadFailureRetryable: Value(payload.failureRetryable),
      payloadNativeTypeNumber: Value(payload.nativeTypeNumber),
      envelopeSha256: event.envelopeSha256,
    );
  }

  ClientEventRecord _decodeEvent(_StoredClientEvent row) {
    try {
      final kind = _decodeEnum(
        ClientEventKind.values,
        row.kind,
        code: 'event_kind_corrupt',
      );
      final content = _decodePayload(kind, row);
      return ClientEventRecord(
        eventId: row.eventId,
        connectionId: row.connectionId,
        originDeviceId: row.originDeviceId,
        conversationId: row.conversationId,
        sessionId: row.sessionId,
        requestId: row.requestId,
        sequence: _decodeUint64(
          row.sequenceText,
          allowZero: false,
          code: 'event_sequence_corrupt',
        ),
        occurredAt: DateTime.fromMicrosecondsSinceEpoch(
          row.occurredAtMicros,
          isUtc: true,
        ),
        kind: kind,
        content: content,
        envelopeSha256: row.envelopeSha256,
      );
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('event_corrupt');
    }
  }

  _StoredPayload _encodePayload(
    ClientEventKind kind,
    ClientEventContent content,
  ) {
    try {
      return switch (content) {
        SafeMessageClientEventContent() => _StoredPayload(
          safeMessage: content.safeMessage,
          text: content.confirmedText,
        ),
        MessageClientEventContent() => _StoredPayload(
          text: content.text,
          revisionText: _encodeUint64(
            content.revision,
            allowZero: true,
            code: 'message_revision_invalid',
          ),
        ),
        ToolClientEventContent() => _StoredPayload(
          toolName: content.toolName,
          toolStage: content.stage,
          safeSummary: content.safeSummary,
        ),
        ApprovalClientEventContent() => _encodeApproval(content),
        ClarificationClientEventContent() => _encodeClarification(content),
        TerminalClientEventContent() => _encodeTerminal(content),
        UnsupportedClientEventContent() => _StoredPayload(
          nativeTypeNumber: content.nativeTypeNumber,
          safeMessage: content.safeMessage,
        ),
        EmptyClientEventContent() =>
          throw const DriftClientEventLedgerException('event_payload_invalid'),
      };
    } on DriftClientEventLedgerException {
      rethrow;
    } on Object {
      throw const DriftClientEventLedgerException('event_payload_invalid');
    }
  }

  _StoredPayload _encodeApproval(ApprovalClientEventContent content) {
    _validateOpaque(content.approvalId, code: 'approval_id_invalid');
    if (!content.expiresAt.isUtc ||
        !_sha256Pattern.hasMatch(content.operationSummarySha256)) {
      throw const DriftClientEventLedgerException('approval_payload_invalid');
    }
    return _StoredPayload(
      approvalId: content.approvalId,
      safeSummary: content.safeSummary,
      operationSummarySha256: content.operationSummarySha256,
      expiresAtMicros: content.expiresAt.microsecondsSinceEpoch,
    );
  }

  _StoredPayload _encodeClarification(ClarificationClientEventContent content) {
    _validateOpaque(content.clarificationId, code: 'clarification_id_invalid');
    if (!content.expiresAt.isUtc) {
      throw const DriftClientEventLedgerException(
        'clarification_payload_invalid',
      );
    }
    return _StoredPayload(
      clarificationId: content.clarificationId,
      safePrompt: content.safePrompt,
      expiresAtMicros: content.expiresAt.microsecondsSinceEpoch,
    );
  }

  _StoredPayload _encodeTerminal(TerminalClientEventContent content) {
    final failure = content.failure;
    if (failure == null) return const _StoredPayload();
    return _StoredPayload(
      safeMessage: failure.safeMessage,
      failureStage: failure.stage.name,
      failureCategory: failure.category.name,
      failureCode: failure.code,
      failureRetryable: failure.retryable,
    );
  }

  ClientEventContent _decodePayload(
    ClientEventKind kind,
    _StoredClientEvent row,
  ) {
    final fields = _PayloadFields.fromRow(row);
    return switch (kind) {
      ClientEventKind.requestAccepted => () {
        fields.requireOnly(const {'safeMessage', 'text'});
        return SafeMessageClientEventContent(
          fields.requireSafeMessage(),
          confirmedText: fields.text,
        );
      }(),
      ClientEventKind.connectionReady ||
      ClientEventKind.connectionLost ||
      ClientEventKind.agentWorking ||
      ClientEventKind.requestInterrupting => () {
        fields.requireOnly(const {'safeMessage'});
        return SafeMessageClientEventContent(fields.requireSafeMessage());
      }(),
      ClientEventKind.messageDelta || ClientEventKind.messageCompleted => () {
        fields.requireOnly(const {'text', 'revisionText'});
        return MessageClientEventContent(
          text: fields.requireText(),
          revision: _decodeUint64(
            fields.requireRevisionText(),
            allowZero: true,
            code: 'message_revision_corrupt',
          ),
        );
      }(),
      ClientEventKind.toolStarted ||
      ClientEventKind.toolCompleted ||
      ClientEventKind.toolFailed => () {
        fields.requireOnly(const {'toolName', 'toolStage', 'safeSummary'});
        return ToolClientEventContent(
          toolName: fields.requireToolName(),
          stage: fields.requireToolStage(),
          safeSummary: fields.requireSafeSummary(),
        );
      }(),
      ClientEventKind.approvalRequired ||
      ClientEventKind.approvalResolved ||
      ClientEventKind.approvalExpired ||
      ClientEventKind.approvalCancelled => () {
        fields.requireOnly(const {
          'approvalId',
          'safeSummary',
          'operationSummarySha256',
          'expiresAtMicros',
        });
        final hash = fields.requireOperationSummarySha256();
        if (!_sha256Pattern.hasMatch(hash)) {
          throw const DriftClientEventLedgerException(
            'approval_payload_corrupt',
          );
        }
        return ApprovalClientEventContent(
          approvalId: fields.requireApprovalId(),
          safeSummary: fields.requireSafeSummary(),
          operationSummarySha256: hash,
          expiresAt: DateTime.fromMicrosecondsSinceEpoch(
            fields.requireExpiresAtMicros(),
            isUtc: true,
          ),
        );
      }(),
      ClientEventKind.clarificationRequired ||
      ClientEventKind.clarificationResolved ||
      ClientEventKind.clarificationExpired ||
      ClientEventKind.clarificationCancelled => () {
        fields.requireOnly(const {
          'clarificationId',
          'safePrompt',
          'expiresAtMicros',
        });
        return ClarificationClientEventContent(
          clarificationId: fields.requireClarificationId(),
          safePrompt: fields.requireSafePrompt(),
          expiresAt: DateTime.fromMicrosecondsSinceEpoch(
            fields.requireExpiresAtMicros(),
            isUtc: true,
          ),
        );
      }(),
      ClientEventKind.requestCompleted ||
      ClientEventKind.requestFailed ||
      ClientEventKind.requestCancelled ||
      ClientEventKind.requestInterrupted => _decodeTerminal(fields),
      ClientEventKind.unsupported => () {
        fields.requireOnly(const {'nativeTypeNumber', 'safeMessage'});
        return UnsupportedClientEventContent(
          nativeTypeNumber: fields.requireNativeTypeNumber(),
          safeMessage: fields.requireSafeMessage(),
        );
      }(),
    };
  }

  TerminalClientEventContent _decodeTerminal(_PayloadFields fields) {
    final hasFailure =
        fields.failureStage != null ||
        fields.failureCategory != null ||
        fields.failureCode != null ||
        fields.safeMessage != null ||
        fields.failureRetryable != null;
    if (!hasFailure) {
      fields.requireOnly(const {});
      return const TerminalClientEventContent(null);
    }
    fields.requireOnly(const {
      'safeMessage',
      'failureStage',
      'failureCategory',
      'failureCode',
      'failureRetryable',
    });
    return TerminalClientEventContent(
      ClientStageFailure(
        stage: _decodeEnum(
          ClientFailureStage.values,
          fields.requireFailureStage(),
          code: 'failure_stage_corrupt',
        ),
        category: _decodeEnum(
          ClientFailureCategory.values,
          fields.requireFailureCategory(),
          code: 'failure_category_corrupt',
        ),
        code: fields.requireFailureCode(),
        safeMessage: fields.requireSafeMessage(),
        retryable: fields.requireFailureRetryable(),
      ),
    );
  }
}

/// Safe domain facade over the private generated Drift database. Generated
/// rows (including full Agent text) and table APIs stay library-private so
/// callers cannot accidentally stringify or log them.
