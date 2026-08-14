part of 'drift_client_event_ledger.dart';

@DataClassName('_StoredTrackedRequest')
class _TrackedRequests extends Table {
  @override
  String get tableName => 'tracked_requests';

  TextColumn get requestId => text().withLength(min: 1, max: 256)();

  TextColumn get originDeviceId => text().withLength(min: 1, max: 256)();

  TextColumn get conversationId => text().withLength(min: 1, max: 256)();

  TextColumn get sessionId => text().withLength(min: 1, max: 256).nullable()();

  TextColumn get nodeId => text().withLength(min: 1, max: 256)();

  TextColumn get agentId => text().withLength(min: 1, max: 256)();

  TextColumn get capabilityRevision => text().withLength(min: 1, max: 256)();

  TextColumn get acceptedSequenceText =>
      text().withLength(min: 20, max: 20).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {requestId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, acceptedSequenceText},
  ];

  @override
  List<String> get customConstraints => const [
    "CHECK (accepted_sequence_text IS NULL OR (length(accepted_sequence_text) = 20 AND accepted_sequence_text NOT GLOB '*[^0-9]*' AND accepted_sequence_text > '00000000000000000000' AND accepted_sequence_text <= '18446744073709551615'))",
  ];
}

@DataClassName('_StoredLocalSubmission')
class _LocalSubmissions extends Table {
  @override
  String get tableName => 'local_submissions';

  TextColumn get requestId => text()
      .withLength(min: 1, max: 256)
      .references(_TrackedRequests, #requestId, onDelete: KeyAction.cascade)();

  TextColumn get originDeviceId => text().withLength(min: 1, max: 256)();

  TextColumn get commandId => text().withLength(min: 1, max: 256)();

  TextColumn get idempotencyKey => text().withLength(min: 1, max: 256)();

  TextColumn get confirmedTextSha256 => text().withLength(min: 64, max: 64)();

  TextColumn get disposition => text().withLength(min: 1, max: 16)();

  @override
  Set<Column<Object>> get primaryKey => {requestId};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {originDeviceId, commandId},
    {originDeviceId, idempotencyKey},
  ];

  @override
  List<String> get customConstraints => const [
    "CHECK (length(confirmed_text_sha256) = 64 AND confirmed_text_sha256 NOT GLOB '*[^0-9a-f]*')",
    "CHECK (disposition IN ('prepared', 'outcomeUnknown', 'accepted', 'rejected'))",
  ];
}

@DataClassName('_StoredClientEvent')
class _ClientEvents extends Table {
  @override
  String get tableName => 'client_events';

  TextColumn get eventId => text().withLength(min: 1, max: 256).unique()();

  TextColumn get connectionId => text().withLength(min: 1, max: 256)();

  TextColumn get originDeviceId => text().withLength(min: 1, max: 256)();

  TextColumn get conversationId => text().withLength(min: 1, max: 256)();

  TextColumn get sessionId => text().withLength(min: 1, max: 256).nullable()();

  TextColumn get requestId => text()
      .withLength(min: 1, max: 256)
      .references(_TrackedRequests, #requestId)();

  /// Unsigned 64-bit values are stored as canonical, zero-padded decimal text.
  TextColumn get sequenceText => text().withLength(min: 20, max: 20)();

  IntColumn get occurredAtMicros => integer()();

  TextColumn get kind => text().withLength(min: 1, max: 64)();

  TextColumn get payloadSafeMessage => text().nullable()();

  TextColumn get payloadText => text().nullable()();

  TextColumn get payloadRevisionText =>
      text().withLength(min: 20, max: 20).nullable()();

  TextColumn get payloadToolName => text().nullable()();

  TextColumn get payloadToolStage => text().nullable()();

  TextColumn get payloadSafeSummary => text().nullable()();

  TextColumn get payloadApprovalId => text().nullable()();

  TextColumn get payloadOperationSummarySha256 =>
      text().withLength(min: 64, max: 64).nullable()();

  IntColumn get payloadExpiresAtMicros => integer().nullable()();

  TextColumn get payloadClarificationId => text().nullable()();

  TextColumn get payloadSafePrompt => text().nullable()();

  TextColumn get payloadFailureStage => text().nullable()();

  TextColumn get payloadFailureCategory => text().nullable()();

  TextColumn get payloadFailureCode => text().nullable()();

  BoolColumn get payloadFailureRetryable => boolean().nullable()();

  IntColumn get payloadNativeTypeNumber => integer().nullable()();

  TextColumn get envelopeSha256 => text().withLength(min: 64, max: 64)();

  @override
  Set<Column<Object>> get primaryKey => {conversationId, sequenceText};

  @override
  List<String> get customConstraints => const [
    "CHECK (length(sequence_text) = 20 AND sequence_text NOT GLOB '*[^0-9]*' AND sequence_text > '00000000000000000000' AND sequence_text <= '18446744073709551615')",
    "CHECK (payload_revision_text IS NULL OR (length(payload_revision_text) = 20 AND payload_revision_text NOT GLOB '*[^0-9]*' AND payload_revision_text <= '18446744073709551615'))",
    "CHECK (length(envelope_sha256) = 64 AND envelope_sha256 NOT GLOB '*[^0-9a-f]*')",
    "CHECK (payload_operation_summary_sha256 IS NULL OR (length(payload_operation_summary_sha256) = 64 AND payload_operation_summary_sha256 NOT GLOB '*[^0-9a-f]*'))",
  ];
}

@DataClassName('_StoredConversationCursor')
class _ConversationCursors extends Table {
  @override
  String get tableName => 'conversation_cursors';

  TextColumn get conversationId => text().withLength(min: 1, max: 256)();

  /// Unsigned 64-bit values are stored as canonical, zero-padded decimal text.
  TextColumn get sequenceText => text().withLength(min: 20, max: 20)();

  @override
  Set<Column<Object>> get primaryKey => {conversationId};

  @override
  List<String> get customConstraints => const [
    "CHECK (length(sequence_text) = 20 AND sequence_text NOT GLOB '*[^0-9]*' AND sequence_text > '00000000000000000000' AND sequence_text <= '18446744073709551615')",
    'FOREIGN KEY (conversation_id, sequence_text) REFERENCES client_events(conversation_id, sequence_text)',
  ];
}
