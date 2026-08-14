import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/client_event.dart';

part 'drift_client_event_ledger_tables.dart';
part 'drift_client_event_ledger_database.dart';
part 'drift_client_event_ledger.g.dart';

class DriftClientEventLedgerException implements Exception {
  const DriftClientEventLedgerException(this.code);

  final String code;

  @override
  String toString() => 'DriftClientEventLedgerException(code: $code)';
}

class DriftClientEventLedger implements ClientEventLedger {
  DriftClientEventLedger(QueryExecutor executor)
    : _database = _EventLedgerDatabase(executor);

  DriftClientEventLedger._(this._database);

  factory DriftClientEventLedger.inMemory() =>
      DriftClientEventLedger(NativeDatabase.memory());

  factory DriftClientEventLedger.openFile(File file) =>
      DriftClientEventLedger(NativeDatabase(file));

  /// Opens the production database under platform Application Support rather
  /// than user-selectable document storage.
  static Future<DriftClientEventLedger> forApplication() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}agent_talk_event_ledger.sqlite',
    );
    return DriftClientEventLedger._(
      _EventLedgerDatabase(NativeDatabase.createInBackground(file)),
    );
  }

  final _EventLedgerDatabase _database;

  Future<void> close() => _database.close();

  @override
  Future<void> trackRequest(TrackedClientRequest request) =>
      _database.trackRequest(request);

  @override
  Future<void> prepareLocalSubmission(
    TrackedClientRequest route,
    LocalClientSubmission submission,
  ) => _database.prepareLocalSubmission(route, submission);

  @override
  Future<LocalClientSubmission?> readLocalSubmission(String requestId) =>
      _database.readLocalSubmission(requestId);

  @override
  Future<void> advanceLocalSubmission(
    String requestId, {
    required LocalClientSubmissionDisposition expectedDisposition,
    required LocalClientSubmissionDisposition nextDisposition,
  }) => _database.advanceLocalSubmission(
    requestId,
    expectedDisposition: expectedDisposition,
    nextDisposition: nextDisposition,
  );

  @override
  Future<TrackedClientRequest?> readRequest(String requestId) =>
      _database.readRequest(requestId);

  @override
  Future<ConversationEventCursor?> readCursor(String conversationId) =>
      _database.readCursor(conversationId);

  @override
  Future<List<String>> listTrackedConversationIds() =>
      _database.listTrackedConversationIds();

  @override
  Future<ClientEventRecord?> readEvent(
    String conversationId,
    BigInt sequence,
  ) => _database.readEvent(conversationId, sequence);

  Future<List<ClientEventRecord>> listConversationEvents(
    String conversationId, {
    BigInt? afterSequence,
    int limit = 500,
  }) => _database.listConversationEvents(
    conversationId,
    afterSequence: afterSequence,
    limit: limit,
  );

  Stream<List<ClientEventRecord>> watchConversationEvents(
    String conversationId, {
    BigInt? afterSequence,
    int limit = 500,
  }) => _database.watchConversationEvents(
    conversationId,
    afterSequence: afterSequence,
    limit: limit,
  );

  Stream<List<TrackedClientRequest>> watchTrackedRequests() =>
      _database.watchTrackedRequests();

  @override
  Future<void> commitNextEvent(
    ClientEventRecord event, {
    required BigInt expectedPreviousSequence,
  }) => _database.commitNextEvent(
    event,
    expectedPreviousSequence: expectedPreviousSequence,
  );
}

const _maximumUint64Decimal = '18446744073709551615';
final BigInt _maximumUint64 = BigInt.parse(_maximumUint64Decimal);
final RegExp _uint64Pattern = RegExp(r'^[0-9]{20}$');
final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

String _encodeUint64(
  BigInt value, {
  required bool allowZero,
  required String code,
}) {
  if (value < BigInt.zero ||
      value > _maximumUint64 ||
      (!allowZero && value == BigInt.zero)) {
    throw DriftClientEventLedgerException(code);
  }
  return value.toString().padLeft(20, '0');
}

BigInt _decodeUint64(
  String value, {
  required bool allowZero,
  required String code,
}) {
  if (!_uint64Pattern.hasMatch(value)) {
    throw DriftClientEventLedgerException(code);
  }
  final decoded = BigInt.tryParse(value);
  if (decoded == null ||
      decoded > _maximumUint64 ||
      (!allowZero && decoded == BigInt.zero) ||
      _encodeUint64(decoded, allowZero: allowZero, code: code) != value) {
    throw DriftClientEventLedgerException(code);
  }
  return decoded;
}

T _decodeEnum<T extends Enum>(
  List<T> values,
  String stored, {
  required String code,
}) {
  for (final value in values) {
    if (value.name == stored) return value;
  }
  throw DriftClientEventLedgerException(code);
}

void _validateOpaque(String value, {required String code}) {
  if (value.isEmpty ||
      value.length > 256 ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw DriftClientEventLedgerException(code);
  }
}

void _validateLimit(int value) {
  if (value <= 0 || value > 1000) {
    throw const DriftClientEventLedgerException('event_limit_invalid');
  }
}

bool _safeSubmissionTransition(
  LocalClientSubmissionDisposition from,
  LocalClientSubmissionDisposition to,
) => switch ((from, to)) {
  (
    LocalClientSubmissionDisposition.prepared,
    LocalClientSubmissionDisposition.outcomeUnknown,
  ) =>
    true,
  (
    LocalClientSubmissionDisposition.outcomeUnknown,
    LocalClientSubmissionDisposition.accepted ||
        LocalClientSubmissionDisposition.rejected,
  ) =>
    true,
  _ => false,
};

class _StoredPayload {
  const _StoredPayload({
    this.safeMessage,
    this.text,
    this.revisionText,
    this.toolName,
    this.toolStage,
    this.safeSummary,
    this.approvalId,
    this.operationSummarySha256,
    this.expiresAtMicros,
    this.clarificationId,
    this.safePrompt,
    this.failureStage,
    this.failureCategory,
    this.failureCode,
    this.failureRetryable,
    this.nativeTypeNumber,
  });

  final String? safeMessage;
  final String? text;
  final String? revisionText;
  final String? toolName;
  final String? toolStage;
  final String? safeSummary;
  final String? approvalId;
  final String? operationSummarySha256;
  final int? expiresAtMicros;
  final String? clarificationId;
  final String? safePrompt;
  final String? failureStage;
  final String? failureCategory;
  final String? failureCode;
  final bool? failureRetryable;
  final int? nativeTypeNumber;
}

class _PayloadFields extends _StoredPayload {
  const _PayloadFields({
    super.safeMessage,
    super.text,
    super.revisionText,
    super.toolName,
    super.toolStage,
    super.safeSummary,
    super.approvalId,
    super.operationSummarySha256,
    super.expiresAtMicros,
    super.clarificationId,
    super.safePrompt,
    super.failureStage,
    super.failureCategory,
    super.failureCode,
    super.failureRetryable,
    super.nativeTypeNumber,
  });

  factory _PayloadFields.fromRow(_StoredClientEvent row) => _PayloadFields(
    safeMessage: row.payloadSafeMessage,
    text: row.payloadText,
    revisionText: row.payloadRevisionText,
    toolName: row.payloadToolName,
    toolStage: row.payloadToolStage,
    safeSummary: row.payloadSafeSummary,
    approvalId: row.payloadApprovalId,
    operationSummarySha256: row.payloadOperationSummarySha256,
    expiresAtMicros: row.payloadExpiresAtMicros,
    clarificationId: row.payloadClarificationId,
    safePrompt: row.payloadSafePrompt,
    failureStage: row.payloadFailureStage,
    failureCategory: row.payloadFailureCategory,
    failureCode: row.payloadFailureCode,
    failureRetryable: row.payloadFailureRetryable,
    nativeTypeNumber: row.payloadNativeTypeNumber,
  );

  Map<String, Object?> get _values => {
    'safeMessage': safeMessage,
    'text': text,
    'revisionText': revisionText,
    'toolName': toolName,
    'toolStage': toolStage,
    'safeSummary': safeSummary,
    'approvalId': approvalId,
    'operationSummarySha256': operationSummarySha256,
    'expiresAtMicros': expiresAtMicros,
    'clarificationId': clarificationId,
    'safePrompt': safePrompt,
    'failureStage': failureStage,
    'failureCategory': failureCategory,
    'failureCode': failureCode,
    'failureRetryable': failureRetryable,
    'nativeTypeNumber': nativeTypeNumber,
  };

  void requireOnly(Set<String> allowed) {
    for (final entry in _values.entries) {
      if (entry.value != null && !allowed.contains(entry.key)) {
        throw const DriftClientEventLedgerException('event_payload_corrupt');
      }
    }
  }

  String requireSafeMessage() => _required(safeMessage);
  String requireText() => _required(text);
  String requireRevisionText() => _required(revisionText);
  String requireToolName() => _required(toolName);
  String requireToolStage() => _required(toolStage);
  String requireSafeSummary() => _required(safeSummary);
  String requireApprovalId() => _required(approvalId);
  String requireOperationSummarySha256() => _required(operationSummarySha256);
  int requireExpiresAtMicros() => _required(expiresAtMicros);
  String requireClarificationId() => _required(clarificationId);
  String requireSafePrompt() => _required(safePrompt);
  String requireFailureStage() => _required(failureStage);
  String requireFailureCategory() => _required(failureCategory);
  String requireFailureCode() => _required(failureCode);
  bool requireFailureRetryable() => _required(failureRetryable);
  int requireNativeTypeNumber() => _required(nativeTypeNumber);

  T _required<T>(T? value) {
    if (value == null) {
      throw const DriftClientEventLedgerException('event_payload_corrupt');
    }
    return value;
  }
}
