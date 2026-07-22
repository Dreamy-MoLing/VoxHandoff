// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_client_event_ledger.dart';

// ignore_for_file: type=lint
class $_TrackedRequestsTable extends _TrackedRequests
    with TableInfo<$_TrackedRequestsTable, _StoredTrackedRequest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_TrackedRequestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capabilityRevisionMeta =
      const VerificationMeta('capabilityRevision');
  @override
  late final GeneratedColumn<String> capabilityRevision =
      GeneratedColumn<String>(
        'capability_revision',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 1,
          maxTextLength: 256,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _acceptedSequenceTextMeta =
      const VerificationMeta('acceptedSequenceText');
  @override
  late final GeneratedColumn<String> acceptedSequenceText =
      GeneratedColumn<String>(
        'accepted_sequence_text',
        aliasedName,
        true,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 20,
          maxTextLength: 20,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    originDeviceId,
    conversationId,
    sessionId,
    nodeId,
    agentId,
    capabilityRevision,
    acceptedSequenceText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracked_requests';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredTrackedRequest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originDeviceIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('capability_revision')) {
      context.handle(
        _capabilityRevisionMeta,
        capabilityRevision.isAcceptableOrUnknown(
          data['capability_revision']!,
          _capabilityRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilityRevisionMeta);
    }
    if (data.containsKey('accepted_sequence_text')) {
      context.handle(
        _acceptedSequenceTextMeta,
        acceptedSequenceText.isAcceptableOrUnknown(
          data['accepted_sequence_text']!,
          _acceptedSequenceTextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {conversationId, acceptedSequenceText},
  ];
  @override
  _StoredTrackedRequest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredTrackedRequest(
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      capabilityRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capability_revision'],
      )!,
      acceptedSequenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accepted_sequence_text'],
      ),
    );
  }

  @override
  $_TrackedRequestsTable createAlias(String alias) {
    return $_TrackedRequestsTable(attachedDatabase, alias);
  }
}

class _StoredTrackedRequest extends DataClass
    implements Insertable<_StoredTrackedRequest> {
  final String requestId;
  final String originDeviceId;
  final String conversationId;
  final String? sessionId;
  final String nodeId;
  final String agentId;
  final String capabilityRevision;
  final String? acceptedSequenceText;
  const _StoredTrackedRequest({
    required this.requestId,
    required this.originDeviceId,
    required this.conversationId,
    this.sessionId,
    required this.nodeId,
    required this.agentId,
    required this.capabilityRevision,
    this.acceptedSequenceText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['origin_device_id'] = Variable<String>(originDeviceId);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['node_id'] = Variable<String>(nodeId);
    map['agent_id'] = Variable<String>(agentId);
    map['capability_revision'] = Variable<String>(capabilityRevision);
    if (!nullToAbsent || acceptedSequenceText != null) {
      map['accepted_sequence_text'] = Variable<String>(acceptedSequenceText);
    }
    return map;
  }

  _TrackedRequestsCompanion toCompanion(bool nullToAbsent) {
    return _TrackedRequestsCompanion(
      requestId: Value(requestId),
      originDeviceId: Value(originDeviceId),
      conversationId: Value(conversationId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      nodeId: Value(nodeId),
      agentId: Value(agentId),
      capabilityRevision: Value(capabilityRevision),
      acceptedSequenceText: acceptedSequenceText == null && nullToAbsent
          ? const Value.absent()
          : Value(acceptedSequenceText),
    );
  }

  factory _StoredTrackedRequest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredTrackedRequest(
      requestId: serializer.fromJson<String>(json['requestId']),
      originDeviceId: serializer.fromJson<String>(json['originDeviceId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      agentId: serializer.fromJson<String>(json['agentId']),
      capabilityRevision: serializer.fromJson<String>(
        json['capabilityRevision'],
      ),
      acceptedSequenceText: serializer.fromJson<String?>(
        json['acceptedSequenceText'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'originDeviceId': serializer.toJson<String>(originDeviceId),
      'conversationId': serializer.toJson<String>(conversationId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'nodeId': serializer.toJson<String>(nodeId),
      'agentId': serializer.toJson<String>(agentId),
      'capabilityRevision': serializer.toJson<String>(capabilityRevision),
      'acceptedSequenceText': serializer.toJson<String?>(acceptedSequenceText),
    };
  }

  _StoredTrackedRequest copyWith({
    String? requestId,
    String? originDeviceId,
    String? conversationId,
    Value<String?> sessionId = const Value.absent(),
    String? nodeId,
    String? agentId,
    String? capabilityRevision,
    Value<String?> acceptedSequenceText = const Value.absent(),
  }) => _StoredTrackedRequest(
    requestId: requestId ?? this.requestId,
    originDeviceId: originDeviceId ?? this.originDeviceId,
    conversationId: conversationId ?? this.conversationId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    nodeId: nodeId ?? this.nodeId,
    agentId: agentId ?? this.agentId,
    capabilityRevision: capabilityRevision ?? this.capabilityRevision,
    acceptedSequenceText: acceptedSequenceText.present
        ? acceptedSequenceText.value
        : this.acceptedSequenceText,
  );
  _StoredTrackedRequest copyWithCompanion(_TrackedRequestsCompanion data) {
    return _StoredTrackedRequest(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      capabilityRevision: data.capabilityRevision.present
          ? data.capabilityRevision.value
          : this.capabilityRevision,
      acceptedSequenceText: data.acceptedSequenceText.present
          ? data.acceptedSequenceText.value
          : this.acceptedSequenceText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredTrackedRequest(')
          ..write('requestId: $requestId, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('conversationId: $conversationId, ')
          ..write('sessionId: $sessionId, ')
          ..write('nodeId: $nodeId, ')
          ..write('agentId: $agentId, ')
          ..write('capabilityRevision: $capabilityRevision, ')
          ..write('acceptedSequenceText: $acceptedSequenceText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    originDeviceId,
    conversationId,
    sessionId,
    nodeId,
    agentId,
    capabilityRevision,
    acceptedSequenceText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredTrackedRequest &&
          other.requestId == this.requestId &&
          other.originDeviceId == this.originDeviceId &&
          other.conversationId == this.conversationId &&
          other.sessionId == this.sessionId &&
          other.nodeId == this.nodeId &&
          other.agentId == this.agentId &&
          other.capabilityRevision == this.capabilityRevision &&
          other.acceptedSequenceText == this.acceptedSequenceText);
}

class _TrackedRequestsCompanion extends UpdateCompanion<_StoredTrackedRequest> {
  final Value<String> requestId;
  final Value<String> originDeviceId;
  final Value<String> conversationId;
  final Value<String?> sessionId;
  final Value<String> nodeId;
  final Value<String> agentId;
  final Value<String> capabilityRevision;
  final Value<String?> acceptedSequenceText;
  final Value<int> rowid;
  const _TrackedRequestsCompanion({
    this.requestId = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.agentId = const Value.absent(),
    this.capabilityRevision = const Value.absent(),
    this.acceptedSequenceText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _TrackedRequestsCompanion.insert({
    required String requestId,
    required String originDeviceId,
    required String conversationId,
    this.sessionId = const Value.absent(),
    required String nodeId,
    required String agentId,
    required String capabilityRevision,
    this.acceptedSequenceText = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       originDeviceId = Value(originDeviceId),
       conversationId = Value(conversationId),
       nodeId = Value(nodeId),
       agentId = Value(agentId),
       capabilityRevision = Value(capabilityRevision);
  static Insertable<_StoredTrackedRequest> custom({
    Expression<String>? requestId,
    Expression<String>? originDeviceId,
    Expression<String>? conversationId,
    Expression<String>? sessionId,
    Expression<String>? nodeId,
    Expression<String>? agentId,
    Expression<String>? capabilityRevision,
    Expression<String>? acceptedSequenceText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (sessionId != null) 'session_id': sessionId,
      if (nodeId != null) 'node_id': nodeId,
      if (agentId != null) 'agent_id': agentId,
      if (capabilityRevision != null) 'capability_revision': capabilityRevision,
      if (acceptedSequenceText != null)
        'accepted_sequence_text': acceptedSequenceText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _TrackedRequestsCompanion copyWith({
    Value<String>? requestId,
    Value<String>? originDeviceId,
    Value<String>? conversationId,
    Value<String?>? sessionId,
    Value<String>? nodeId,
    Value<String>? agentId,
    Value<String>? capabilityRevision,
    Value<String?>? acceptedSequenceText,
    Value<int>? rowid,
  }) {
    return _TrackedRequestsCompanion(
      requestId: requestId ?? this.requestId,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      conversationId: conversationId ?? this.conversationId,
      sessionId: sessionId ?? this.sessionId,
      nodeId: nodeId ?? this.nodeId,
      agentId: agentId ?? this.agentId,
      capabilityRevision: capabilityRevision ?? this.capabilityRevision,
      acceptedSequenceText: acceptedSequenceText ?? this.acceptedSequenceText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (capabilityRevision.present) {
      map['capability_revision'] = Variable<String>(capabilityRevision.value);
    }
    if (acceptedSequenceText.present) {
      map['accepted_sequence_text'] = Variable<String>(
        acceptedSequenceText.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_TrackedRequestsCompanion(')
          ..write('requestId: $requestId, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('conversationId: $conversationId, ')
          ..write('sessionId: $sessionId, ')
          ..write('nodeId: $nodeId, ')
          ..write('agentId: $agentId, ')
          ..write('capabilityRevision: $capabilityRevision, ')
          ..write('acceptedSequenceText: $acceptedSequenceText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $_LocalSubmissionsTable extends _LocalSubmissions
    with TableInfo<$_LocalSubmissionsTable, _StoredLocalSubmission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_LocalSubmissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracked_requests (request_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandIdMeta = const VerificationMeta(
    'commandId',
  );
  @override
  late final GeneratedColumn<String> commandId = GeneratedColumn<String>(
    'command_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedTextSha256Meta =
      const VerificationMeta('confirmedTextSha256');
  @override
  late final GeneratedColumn<String> confirmedTextSha256 =
      GeneratedColumn<String>(
        'confirmed_text_sha256',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 64,
          maxTextLength: 64,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dispositionMeta = const VerificationMeta(
    'disposition',
  );
  @override
  late final GeneratedColumn<String> disposition = GeneratedColumn<String>(
    'disposition',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    originDeviceId,
    commandId,
    idempotencyKey,
    confirmedTextSha256,
    disposition,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_submissions';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredLocalSubmission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originDeviceIdMeta);
    }
    if (data.containsKey('command_id')) {
      context.handle(
        _commandIdMeta,
        commandId.isAcceptableOrUnknown(data['command_id']!, _commandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_commandIdMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('confirmed_text_sha256')) {
      context.handle(
        _confirmedTextSha256Meta,
        confirmedTextSha256.isAcceptableOrUnknown(
          data['confirmed_text_sha256']!,
          _confirmedTextSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_confirmedTextSha256Meta);
    }
    if (data.containsKey('disposition')) {
      context.handle(
        _dispositionMeta,
        disposition.isAcceptableOrUnknown(
          data['disposition']!,
          _dispositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dispositionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {originDeviceId, commandId},
    {originDeviceId, idempotencyKey},
  ];
  @override
  _StoredLocalSubmission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredLocalSubmission(
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      )!,
      commandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      confirmedTextSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confirmed_text_sha256'],
      )!,
      disposition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disposition'],
      )!,
    );
  }

  @override
  $_LocalSubmissionsTable createAlias(String alias) {
    return $_LocalSubmissionsTable(attachedDatabase, alias);
  }
}

class _StoredLocalSubmission extends DataClass
    implements Insertable<_StoredLocalSubmission> {
  final String requestId;
  final String originDeviceId;
  final String commandId;
  final String idempotencyKey;
  final String confirmedTextSha256;
  final String disposition;
  const _StoredLocalSubmission({
    required this.requestId,
    required this.originDeviceId,
    required this.commandId,
    required this.idempotencyKey,
    required this.confirmedTextSha256,
    required this.disposition,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['origin_device_id'] = Variable<String>(originDeviceId);
    map['command_id'] = Variable<String>(commandId);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['confirmed_text_sha256'] = Variable<String>(confirmedTextSha256);
    map['disposition'] = Variable<String>(disposition);
    return map;
  }

  _LocalSubmissionsCompanion toCompanion(bool nullToAbsent) {
    return _LocalSubmissionsCompanion(
      requestId: Value(requestId),
      originDeviceId: Value(originDeviceId),
      commandId: Value(commandId),
      idempotencyKey: Value(idempotencyKey),
      confirmedTextSha256: Value(confirmedTextSha256),
      disposition: Value(disposition),
    );
  }

  factory _StoredLocalSubmission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredLocalSubmission(
      requestId: serializer.fromJson<String>(json['requestId']),
      originDeviceId: serializer.fromJson<String>(json['originDeviceId']),
      commandId: serializer.fromJson<String>(json['commandId']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      confirmedTextSha256: serializer.fromJson<String>(
        json['confirmedTextSha256'],
      ),
      disposition: serializer.fromJson<String>(json['disposition']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'originDeviceId': serializer.toJson<String>(originDeviceId),
      'commandId': serializer.toJson<String>(commandId),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'confirmedTextSha256': serializer.toJson<String>(confirmedTextSha256),
      'disposition': serializer.toJson<String>(disposition),
    };
  }

  _StoredLocalSubmission copyWith({
    String? requestId,
    String? originDeviceId,
    String? commandId,
    String? idempotencyKey,
    String? confirmedTextSha256,
    String? disposition,
  }) => _StoredLocalSubmission(
    requestId: requestId ?? this.requestId,
    originDeviceId: originDeviceId ?? this.originDeviceId,
    commandId: commandId ?? this.commandId,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    confirmedTextSha256: confirmedTextSha256 ?? this.confirmedTextSha256,
    disposition: disposition ?? this.disposition,
  );
  _StoredLocalSubmission copyWithCompanion(_LocalSubmissionsCompanion data) {
    return _StoredLocalSubmission(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      commandId: data.commandId.present ? data.commandId.value : this.commandId,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      confirmedTextSha256: data.confirmedTextSha256.present
          ? data.confirmedTextSha256.value
          : this.confirmedTextSha256,
      disposition: data.disposition.present
          ? data.disposition.value
          : this.disposition,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredLocalSubmission(')
          ..write('requestId: $requestId, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('commandId: $commandId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('confirmedTextSha256: $confirmedTextSha256, ')
          ..write('disposition: $disposition')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    originDeviceId,
    commandId,
    idempotencyKey,
    confirmedTextSha256,
    disposition,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredLocalSubmission &&
          other.requestId == this.requestId &&
          other.originDeviceId == this.originDeviceId &&
          other.commandId == this.commandId &&
          other.idempotencyKey == this.idempotencyKey &&
          other.confirmedTextSha256 == this.confirmedTextSha256 &&
          other.disposition == this.disposition);
}

class _LocalSubmissionsCompanion
    extends UpdateCompanion<_StoredLocalSubmission> {
  final Value<String> requestId;
  final Value<String> originDeviceId;
  final Value<String> commandId;
  final Value<String> idempotencyKey;
  final Value<String> confirmedTextSha256;
  final Value<String> disposition;
  final Value<int> rowid;
  const _LocalSubmissionsCompanion({
    this.requestId = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.commandId = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.confirmedTextSha256 = const Value.absent(),
    this.disposition = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _LocalSubmissionsCompanion.insert({
    required String requestId,
    required String originDeviceId,
    required String commandId,
    required String idempotencyKey,
    required String confirmedTextSha256,
    required String disposition,
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       originDeviceId = Value(originDeviceId),
       commandId = Value(commandId),
       idempotencyKey = Value(idempotencyKey),
       confirmedTextSha256 = Value(confirmedTextSha256),
       disposition = Value(disposition);
  static Insertable<_StoredLocalSubmission> custom({
    Expression<String>? requestId,
    Expression<String>? originDeviceId,
    Expression<String>? commandId,
    Expression<String>? idempotencyKey,
    Expression<String>? confirmedTextSha256,
    Expression<String>? disposition,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (commandId != null) 'command_id': commandId,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (confirmedTextSha256 != null)
        'confirmed_text_sha256': confirmedTextSha256,
      if (disposition != null) 'disposition': disposition,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _LocalSubmissionsCompanion copyWith({
    Value<String>? requestId,
    Value<String>? originDeviceId,
    Value<String>? commandId,
    Value<String>? idempotencyKey,
    Value<String>? confirmedTextSha256,
    Value<String>? disposition,
    Value<int>? rowid,
  }) {
    return _LocalSubmissionsCompanion(
      requestId: requestId ?? this.requestId,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      commandId: commandId ?? this.commandId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      confirmedTextSha256: confirmedTextSha256 ?? this.confirmedTextSha256,
      disposition: disposition ?? this.disposition,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (commandId.present) {
      map['command_id'] = Variable<String>(commandId.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (confirmedTextSha256.present) {
      map['confirmed_text_sha256'] = Variable<String>(
        confirmedTextSha256.value,
      );
    }
    if (disposition.present) {
      map['disposition'] = Variable<String>(disposition.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_LocalSubmissionsCompanion(')
          ..write('requestId: $requestId, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('commandId: $commandId, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('confirmedTextSha256: $confirmedTextSha256, ')
          ..write('disposition: $disposition, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $_ClientEventsTable extends _ClientEvents
    with TableInfo<$_ClientEventsTable, _StoredClientEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_ClientEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<String> connectionId = GeneratedColumn<String>(
    'connection_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originDeviceIdMeta = const VerificationMeta(
    'originDeviceId',
  );
  @override
  late final GeneratedColumn<String> originDeviceId = GeneratedColumn<String>(
    'origin_device_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracked_requests (request_id)',
    ),
  );
  static const VerificationMeta _sequenceTextMeta = const VerificationMeta(
    'sequenceText',
  );
  @override
  late final GeneratedColumn<String> sequenceText = GeneratedColumn<String>(
    'sequence_text',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 20,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMicrosMeta = const VerificationMeta(
    'occurredAtMicros',
  );
  @override
  late final GeneratedColumn<int> occurredAtMicros = GeneratedColumn<int>(
    'occurred_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadSafeMessageMeta =
      const VerificationMeta('payloadSafeMessage');
  @override
  late final GeneratedColumn<String> payloadSafeMessage =
      GeneratedColumn<String>(
        'payload_safe_message',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadTextMeta = const VerificationMeta(
    'payloadText',
  );
  @override
  late final GeneratedColumn<String> payloadText = GeneratedColumn<String>(
    'payload_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadRevisionTextMeta =
      const VerificationMeta('payloadRevisionText');
  @override
  late final GeneratedColumn<String> payloadRevisionText =
      GeneratedColumn<String>(
        'payload_revision_text',
        aliasedName,
        true,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 20,
          maxTextLength: 20,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadToolNameMeta = const VerificationMeta(
    'payloadToolName',
  );
  @override
  late final GeneratedColumn<String> payloadToolName = GeneratedColumn<String>(
    'payload_tool_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadToolStageMeta = const VerificationMeta(
    'payloadToolStage',
  );
  @override
  late final GeneratedColumn<String> payloadToolStage = GeneratedColumn<String>(
    'payload_tool_stage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadSafeSummaryMeta =
      const VerificationMeta('payloadSafeSummary');
  @override
  late final GeneratedColumn<String> payloadSafeSummary =
      GeneratedColumn<String>(
        'payload_safe_summary',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadApprovalIdMeta = const VerificationMeta(
    'payloadApprovalId',
  );
  @override
  late final GeneratedColumn<String> payloadApprovalId =
      GeneratedColumn<String>(
        'payload_approval_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadOperationSummarySha256Meta =
      const VerificationMeta('payloadOperationSummarySha256');
  @override
  late final GeneratedColumn<String> payloadOperationSummarySha256 =
      GeneratedColumn<String>(
        'payload_operation_summary_sha256',
        aliasedName,
        true,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 64,
          maxTextLength: 64,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadExpiresAtMicrosMeta =
      const VerificationMeta('payloadExpiresAtMicros');
  @override
  late final GeneratedColumn<int> payloadExpiresAtMicros = GeneratedColumn<int>(
    'payload_expires_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadClarificationIdMeta =
      const VerificationMeta('payloadClarificationId');
  @override
  late final GeneratedColumn<String> payloadClarificationId =
      GeneratedColumn<String>(
        'payload_clarification_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadSafePromptMeta = const VerificationMeta(
    'payloadSafePrompt',
  );
  @override
  late final GeneratedColumn<String> payloadSafePrompt =
      GeneratedColumn<String>(
        'payload_safe_prompt',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadFailureStageMeta =
      const VerificationMeta('payloadFailureStage');
  @override
  late final GeneratedColumn<String> payloadFailureStage =
      GeneratedColumn<String>(
        'payload_failure_stage',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadFailureCategoryMeta =
      const VerificationMeta('payloadFailureCategory');
  @override
  late final GeneratedColumn<String> payloadFailureCategory =
      GeneratedColumn<String>(
        'payload_failure_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadFailureCodeMeta =
      const VerificationMeta('payloadFailureCode');
  @override
  late final GeneratedColumn<String> payloadFailureCode =
      GeneratedColumn<String>(
        'payload_failure_code',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadFailureRetryableMeta =
      const VerificationMeta('payloadFailureRetryable');
  @override
  late final GeneratedColumn<bool> payloadFailureRetryable =
      GeneratedColumn<bool>(
        'payload_failure_retryable',
        aliasedName,
        true,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("payload_failure_retryable" IN (0, 1))',
        ),
      );
  static const VerificationMeta _payloadNativeTypeNumberMeta =
      const VerificationMeta('payloadNativeTypeNumber');
  @override
  late final GeneratedColumn<int> payloadNativeTypeNumber =
      GeneratedColumn<int>(
        'payload_native_type_number',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _envelopeSha256Meta = const VerificationMeta(
    'envelopeSha256',
  );
  @override
  late final GeneratedColumn<String> envelopeSha256 = GeneratedColumn<String>(
    'envelope_sha256',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    connectionId,
    originDeviceId,
    conversationId,
    sessionId,
    requestId,
    sequenceText,
    occurredAtMicros,
    kind,
    payloadSafeMessage,
    payloadText,
    payloadRevisionText,
    payloadToolName,
    payloadToolStage,
    payloadSafeSummary,
    payloadApprovalId,
    payloadOperationSummarySha256,
    payloadExpiresAtMicros,
    payloadClarificationId,
    payloadSafePrompt,
    payloadFailureStage,
    payloadFailureCategory,
    payloadFailureCode,
    payloadFailureRetryable,
    payloadNativeTypeNumber,
    envelopeSha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'client_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredClientEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_connectionIdMeta);
    }
    if (data.containsKey('origin_device_id')) {
      context.handle(
        _originDeviceIdMeta,
        originDeviceId.isAcceptableOrUnknown(
          data['origin_device_id']!,
          _originDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originDeviceIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('sequence_text')) {
      context.handle(
        _sequenceTextMeta,
        sequenceText.isAcceptableOrUnknown(
          data['sequence_text']!,
          _sequenceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceTextMeta);
    }
    if (data.containsKey('occurred_at_micros')) {
      context.handle(
        _occurredAtMicrosMeta,
        occurredAtMicros.isAcceptableOrUnknown(
          data['occurred_at_micros']!,
          _occurredAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMicrosMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payload_safe_message')) {
      context.handle(
        _payloadSafeMessageMeta,
        payloadSafeMessage.isAcceptableOrUnknown(
          data['payload_safe_message']!,
          _payloadSafeMessageMeta,
        ),
      );
    }
    if (data.containsKey('payload_text')) {
      context.handle(
        _payloadTextMeta,
        payloadText.isAcceptableOrUnknown(
          data['payload_text']!,
          _payloadTextMeta,
        ),
      );
    }
    if (data.containsKey('payload_revision_text')) {
      context.handle(
        _payloadRevisionTextMeta,
        payloadRevisionText.isAcceptableOrUnknown(
          data['payload_revision_text']!,
          _payloadRevisionTextMeta,
        ),
      );
    }
    if (data.containsKey('payload_tool_name')) {
      context.handle(
        _payloadToolNameMeta,
        payloadToolName.isAcceptableOrUnknown(
          data['payload_tool_name']!,
          _payloadToolNameMeta,
        ),
      );
    }
    if (data.containsKey('payload_tool_stage')) {
      context.handle(
        _payloadToolStageMeta,
        payloadToolStage.isAcceptableOrUnknown(
          data['payload_tool_stage']!,
          _payloadToolStageMeta,
        ),
      );
    }
    if (data.containsKey('payload_safe_summary')) {
      context.handle(
        _payloadSafeSummaryMeta,
        payloadSafeSummary.isAcceptableOrUnknown(
          data['payload_safe_summary']!,
          _payloadSafeSummaryMeta,
        ),
      );
    }
    if (data.containsKey('payload_approval_id')) {
      context.handle(
        _payloadApprovalIdMeta,
        payloadApprovalId.isAcceptableOrUnknown(
          data['payload_approval_id']!,
          _payloadApprovalIdMeta,
        ),
      );
    }
    if (data.containsKey('payload_operation_summary_sha256')) {
      context.handle(
        _payloadOperationSummarySha256Meta,
        payloadOperationSummarySha256.isAcceptableOrUnknown(
          data['payload_operation_summary_sha256']!,
          _payloadOperationSummarySha256Meta,
        ),
      );
    }
    if (data.containsKey('payload_expires_at_micros')) {
      context.handle(
        _payloadExpiresAtMicrosMeta,
        payloadExpiresAtMicros.isAcceptableOrUnknown(
          data['payload_expires_at_micros']!,
          _payloadExpiresAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('payload_clarification_id')) {
      context.handle(
        _payloadClarificationIdMeta,
        payloadClarificationId.isAcceptableOrUnknown(
          data['payload_clarification_id']!,
          _payloadClarificationIdMeta,
        ),
      );
    }
    if (data.containsKey('payload_safe_prompt')) {
      context.handle(
        _payloadSafePromptMeta,
        payloadSafePrompt.isAcceptableOrUnknown(
          data['payload_safe_prompt']!,
          _payloadSafePromptMeta,
        ),
      );
    }
    if (data.containsKey('payload_failure_stage')) {
      context.handle(
        _payloadFailureStageMeta,
        payloadFailureStage.isAcceptableOrUnknown(
          data['payload_failure_stage']!,
          _payloadFailureStageMeta,
        ),
      );
    }
    if (data.containsKey('payload_failure_category')) {
      context.handle(
        _payloadFailureCategoryMeta,
        payloadFailureCategory.isAcceptableOrUnknown(
          data['payload_failure_category']!,
          _payloadFailureCategoryMeta,
        ),
      );
    }
    if (data.containsKey('payload_failure_code')) {
      context.handle(
        _payloadFailureCodeMeta,
        payloadFailureCode.isAcceptableOrUnknown(
          data['payload_failure_code']!,
          _payloadFailureCodeMeta,
        ),
      );
    }
    if (data.containsKey('payload_failure_retryable')) {
      context.handle(
        _payloadFailureRetryableMeta,
        payloadFailureRetryable.isAcceptableOrUnknown(
          data['payload_failure_retryable']!,
          _payloadFailureRetryableMeta,
        ),
      );
    }
    if (data.containsKey('payload_native_type_number')) {
      context.handle(
        _payloadNativeTypeNumberMeta,
        payloadNativeTypeNumber.isAcceptableOrUnknown(
          data['payload_native_type_number']!,
          _payloadNativeTypeNumberMeta,
        ),
      );
    }
    if (data.containsKey('envelope_sha256')) {
      context.handle(
        _envelopeSha256Meta,
        envelopeSha256.isAcceptableOrUnknown(
          data['envelope_sha256']!,
          _envelopeSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_envelopeSha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, sequenceText};
  @override
  _StoredClientEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredClientEvent(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_id'],
      )!,
      originDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_device_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      sequenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sequence_text'],
      )!,
      occurredAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurred_at_micros'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      payloadSafeMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_safe_message'],
      ),
      payloadText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_text'],
      ),
      payloadRevisionText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_revision_text'],
      ),
      payloadToolName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_tool_name'],
      ),
      payloadToolStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_tool_stage'],
      ),
      payloadSafeSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_safe_summary'],
      ),
      payloadApprovalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_approval_id'],
      ),
      payloadOperationSummarySha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_operation_summary_sha256'],
      ),
      payloadExpiresAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_expires_at_micros'],
      ),
      payloadClarificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_clarification_id'],
      ),
      payloadSafePrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_safe_prompt'],
      ),
      payloadFailureStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_failure_stage'],
      ),
      payloadFailureCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_failure_category'],
      ),
      payloadFailureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_failure_code'],
      ),
      payloadFailureRetryable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}payload_failure_retryable'],
      ),
      payloadNativeTypeNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payload_native_type_number'],
      ),
      envelopeSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}envelope_sha256'],
      )!,
    );
  }

  @override
  $_ClientEventsTable createAlias(String alias) {
    return $_ClientEventsTable(attachedDatabase, alias);
  }
}

class _StoredClientEvent extends DataClass
    implements Insertable<_StoredClientEvent> {
  final String eventId;
  final String connectionId;
  final String originDeviceId;
  final String conversationId;
  final String? sessionId;
  final String requestId;

  /// Unsigned 64-bit values are stored as canonical, zero-padded decimal text.
  final String sequenceText;
  final int occurredAtMicros;
  final String kind;
  final String? payloadSafeMessage;
  final String? payloadText;
  final String? payloadRevisionText;
  final String? payloadToolName;
  final String? payloadToolStage;
  final String? payloadSafeSummary;
  final String? payloadApprovalId;
  final String? payloadOperationSummarySha256;
  final int? payloadExpiresAtMicros;
  final String? payloadClarificationId;
  final String? payloadSafePrompt;
  final String? payloadFailureStage;
  final String? payloadFailureCategory;
  final String? payloadFailureCode;
  final bool? payloadFailureRetryable;
  final int? payloadNativeTypeNumber;
  final String envelopeSha256;
  const _StoredClientEvent({
    required this.eventId,
    required this.connectionId,
    required this.originDeviceId,
    required this.conversationId,
    this.sessionId,
    required this.requestId,
    required this.sequenceText,
    required this.occurredAtMicros,
    required this.kind,
    this.payloadSafeMessage,
    this.payloadText,
    this.payloadRevisionText,
    this.payloadToolName,
    this.payloadToolStage,
    this.payloadSafeSummary,
    this.payloadApprovalId,
    this.payloadOperationSummarySha256,
    this.payloadExpiresAtMicros,
    this.payloadClarificationId,
    this.payloadSafePrompt,
    this.payloadFailureStage,
    this.payloadFailureCategory,
    this.payloadFailureCode,
    this.payloadFailureRetryable,
    this.payloadNativeTypeNumber,
    required this.envelopeSha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['connection_id'] = Variable<String>(connectionId);
    map['origin_device_id'] = Variable<String>(originDeviceId);
    map['conversation_id'] = Variable<String>(conversationId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['request_id'] = Variable<String>(requestId);
    map['sequence_text'] = Variable<String>(sequenceText);
    map['occurred_at_micros'] = Variable<int>(occurredAtMicros);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || payloadSafeMessage != null) {
      map['payload_safe_message'] = Variable<String>(payloadSafeMessage);
    }
    if (!nullToAbsent || payloadText != null) {
      map['payload_text'] = Variable<String>(payloadText);
    }
    if (!nullToAbsent || payloadRevisionText != null) {
      map['payload_revision_text'] = Variable<String>(payloadRevisionText);
    }
    if (!nullToAbsent || payloadToolName != null) {
      map['payload_tool_name'] = Variable<String>(payloadToolName);
    }
    if (!nullToAbsent || payloadToolStage != null) {
      map['payload_tool_stage'] = Variable<String>(payloadToolStage);
    }
    if (!nullToAbsent || payloadSafeSummary != null) {
      map['payload_safe_summary'] = Variable<String>(payloadSafeSummary);
    }
    if (!nullToAbsent || payloadApprovalId != null) {
      map['payload_approval_id'] = Variable<String>(payloadApprovalId);
    }
    if (!nullToAbsent || payloadOperationSummarySha256 != null) {
      map['payload_operation_summary_sha256'] = Variable<String>(
        payloadOperationSummarySha256,
      );
    }
    if (!nullToAbsent || payloadExpiresAtMicros != null) {
      map['payload_expires_at_micros'] = Variable<int>(payloadExpiresAtMicros);
    }
    if (!nullToAbsent || payloadClarificationId != null) {
      map['payload_clarification_id'] = Variable<String>(
        payloadClarificationId,
      );
    }
    if (!nullToAbsent || payloadSafePrompt != null) {
      map['payload_safe_prompt'] = Variable<String>(payloadSafePrompt);
    }
    if (!nullToAbsent || payloadFailureStage != null) {
      map['payload_failure_stage'] = Variable<String>(payloadFailureStage);
    }
    if (!nullToAbsent || payloadFailureCategory != null) {
      map['payload_failure_category'] = Variable<String>(
        payloadFailureCategory,
      );
    }
    if (!nullToAbsent || payloadFailureCode != null) {
      map['payload_failure_code'] = Variable<String>(payloadFailureCode);
    }
    if (!nullToAbsent || payloadFailureRetryable != null) {
      map['payload_failure_retryable'] = Variable<bool>(
        payloadFailureRetryable,
      );
    }
    if (!nullToAbsent || payloadNativeTypeNumber != null) {
      map['payload_native_type_number'] = Variable<int>(
        payloadNativeTypeNumber,
      );
    }
    map['envelope_sha256'] = Variable<String>(envelopeSha256);
    return map;
  }

  _ClientEventsCompanion toCompanion(bool nullToAbsent) {
    return _ClientEventsCompanion(
      eventId: Value(eventId),
      connectionId: Value(connectionId),
      originDeviceId: Value(originDeviceId),
      conversationId: Value(conversationId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      requestId: Value(requestId),
      sequenceText: Value(sequenceText),
      occurredAtMicros: Value(occurredAtMicros),
      kind: Value(kind),
      payloadSafeMessage: payloadSafeMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadSafeMessage),
      payloadText: payloadText == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadText),
      payloadRevisionText: payloadRevisionText == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadRevisionText),
      payloadToolName: payloadToolName == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadToolName),
      payloadToolStage: payloadToolStage == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadToolStage),
      payloadSafeSummary: payloadSafeSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadSafeSummary),
      payloadApprovalId: payloadApprovalId == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadApprovalId),
      payloadOperationSummarySha256:
          payloadOperationSummarySha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadOperationSummarySha256),
      payloadExpiresAtMicros: payloadExpiresAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadExpiresAtMicros),
      payloadClarificationId: payloadClarificationId == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadClarificationId),
      payloadSafePrompt: payloadSafePrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadSafePrompt),
      payloadFailureStage: payloadFailureStage == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadFailureStage),
      payloadFailureCategory: payloadFailureCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadFailureCategory),
      payloadFailureCode: payloadFailureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadFailureCode),
      payloadFailureRetryable: payloadFailureRetryable == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadFailureRetryable),
      payloadNativeTypeNumber: payloadNativeTypeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadNativeTypeNumber),
      envelopeSha256: Value(envelopeSha256),
    );
  }

  factory _StoredClientEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredClientEvent(
      eventId: serializer.fromJson<String>(json['eventId']),
      connectionId: serializer.fromJson<String>(json['connectionId']),
      originDeviceId: serializer.fromJson<String>(json['originDeviceId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      requestId: serializer.fromJson<String>(json['requestId']),
      sequenceText: serializer.fromJson<String>(json['sequenceText']),
      occurredAtMicros: serializer.fromJson<int>(json['occurredAtMicros']),
      kind: serializer.fromJson<String>(json['kind']),
      payloadSafeMessage: serializer.fromJson<String?>(
        json['payloadSafeMessage'],
      ),
      payloadText: serializer.fromJson<String?>(json['payloadText']),
      payloadRevisionText: serializer.fromJson<String?>(
        json['payloadRevisionText'],
      ),
      payloadToolName: serializer.fromJson<String?>(json['payloadToolName']),
      payloadToolStage: serializer.fromJson<String?>(json['payloadToolStage']),
      payloadSafeSummary: serializer.fromJson<String?>(
        json['payloadSafeSummary'],
      ),
      payloadApprovalId: serializer.fromJson<String?>(
        json['payloadApprovalId'],
      ),
      payloadOperationSummarySha256: serializer.fromJson<String?>(
        json['payloadOperationSummarySha256'],
      ),
      payloadExpiresAtMicros: serializer.fromJson<int?>(
        json['payloadExpiresAtMicros'],
      ),
      payloadClarificationId: serializer.fromJson<String?>(
        json['payloadClarificationId'],
      ),
      payloadSafePrompt: serializer.fromJson<String?>(
        json['payloadSafePrompt'],
      ),
      payloadFailureStage: serializer.fromJson<String?>(
        json['payloadFailureStage'],
      ),
      payloadFailureCategory: serializer.fromJson<String?>(
        json['payloadFailureCategory'],
      ),
      payloadFailureCode: serializer.fromJson<String?>(
        json['payloadFailureCode'],
      ),
      payloadFailureRetryable: serializer.fromJson<bool?>(
        json['payloadFailureRetryable'],
      ),
      payloadNativeTypeNumber: serializer.fromJson<int?>(
        json['payloadNativeTypeNumber'],
      ),
      envelopeSha256: serializer.fromJson<String>(json['envelopeSha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'connectionId': serializer.toJson<String>(connectionId),
      'originDeviceId': serializer.toJson<String>(originDeviceId),
      'conversationId': serializer.toJson<String>(conversationId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'requestId': serializer.toJson<String>(requestId),
      'sequenceText': serializer.toJson<String>(sequenceText),
      'occurredAtMicros': serializer.toJson<int>(occurredAtMicros),
      'kind': serializer.toJson<String>(kind),
      'payloadSafeMessage': serializer.toJson<String?>(payloadSafeMessage),
      'payloadText': serializer.toJson<String?>(payloadText),
      'payloadRevisionText': serializer.toJson<String?>(payloadRevisionText),
      'payloadToolName': serializer.toJson<String?>(payloadToolName),
      'payloadToolStage': serializer.toJson<String?>(payloadToolStage),
      'payloadSafeSummary': serializer.toJson<String?>(payloadSafeSummary),
      'payloadApprovalId': serializer.toJson<String?>(payloadApprovalId),
      'payloadOperationSummarySha256': serializer.toJson<String?>(
        payloadOperationSummarySha256,
      ),
      'payloadExpiresAtMicros': serializer.toJson<int?>(payloadExpiresAtMicros),
      'payloadClarificationId': serializer.toJson<String?>(
        payloadClarificationId,
      ),
      'payloadSafePrompt': serializer.toJson<String?>(payloadSafePrompt),
      'payloadFailureStage': serializer.toJson<String?>(payloadFailureStage),
      'payloadFailureCategory': serializer.toJson<String?>(
        payloadFailureCategory,
      ),
      'payloadFailureCode': serializer.toJson<String?>(payloadFailureCode),
      'payloadFailureRetryable': serializer.toJson<bool?>(
        payloadFailureRetryable,
      ),
      'payloadNativeTypeNumber': serializer.toJson<int?>(
        payloadNativeTypeNumber,
      ),
      'envelopeSha256': serializer.toJson<String>(envelopeSha256),
    };
  }

  _StoredClientEvent copyWith({
    String? eventId,
    String? connectionId,
    String? originDeviceId,
    String? conversationId,
    Value<String?> sessionId = const Value.absent(),
    String? requestId,
    String? sequenceText,
    int? occurredAtMicros,
    String? kind,
    Value<String?> payloadSafeMessage = const Value.absent(),
    Value<String?> payloadText = const Value.absent(),
    Value<String?> payloadRevisionText = const Value.absent(),
    Value<String?> payloadToolName = const Value.absent(),
    Value<String?> payloadToolStage = const Value.absent(),
    Value<String?> payloadSafeSummary = const Value.absent(),
    Value<String?> payloadApprovalId = const Value.absent(),
    Value<String?> payloadOperationSummarySha256 = const Value.absent(),
    Value<int?> payloadExpiresAtMicros = const Value.absent(),
    Value<String?> payloadClarificationId = const Value.absent(),
    Value<String?> payloadSafePrompt = const Value.absent(),
    Value<String?> payloadFailureStage = const Value.absent(),
    Value<String?> payloadFailureCategory = const Value.absent(),
    Value<String?> payloadFailureCode = const Value.absent(),
    Value<bool?> payloadFailureRetryable = const Value.absent(),
    Value<int?> payloadNativeTypeNumber = const Value.absent(),
    String? envelopeSha256,
  }) => _StoredClientEvent(
    eventId: eventId ?? this.eventId,
    connectionId: connectionId ?? this.connectionId,
    originDeviceId: originDeviceId ?? this.originDeviceId,
    conversationId: conversationId ?? this.conversationId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    requestId: requestId ?? this.requestId,
    sequenceText: sequenceText ?? this.sequenceText,
    occurredAtMicros: occurredAtMicros ?? this.occurredAtMicros,
    kind: kind ?? this.kind,
    payloadSafeMessage: payloadSafeMessage.present
        ? payloadSafeMessage.value
        : this.payloadSafeMessage,
    payloadText: payloadText.present ? payloadText.value : this.payloadText,
    payloadRevisionText: payloadRevisionText.present
        ? payloadRevisionText.value
        : this.payloadRevisionText,
    payloadToolName: payloadToolName.present
        ? payloadToolName.value
        : this.payloadToolName,
    payloadToolStage: payloadToolStage.present
        ? payloadToolStage.value
        : this.payloadToolStage,
    payloadSafeSummary: payloadSafeSummary.present
        ? payloadSafeSummary.value
        : this.payloadSafeSummary,
    payloadApprovalId: payloadApprovalId.present
        ? payloadApprovalId.value
        : this.payloadApprovalId,
    payloadOperationSummarySha256: payloadOperationSummarySha256.present
        ? payloadOperationSummarySha256.value
        : this.payloadOperationSummarySha256,
    payloadExpiresAtMicros: payloadExpiresAtMicros.present
        ? payloadExpiresAtMicros.value
        : this.payloadExpiresAtMicros,
    payloadClarificationId: payloadClarificationId.present
        ? payloadClarificationId.value
        : this.payloadClarificationId,
    payloadSafePrompt: payloadSafePrompt.present
        ? payloadSafePrompt.value
        : this.payloadSafePrompt,
    payloadFailureStage: payloadFailureStage.present
        ? payloadFailureStage.value
        : this.payloadFailureStage,
    payloadFailureCategory: payloadFailureCategory.present
        ? payloadFailureCategory.value
        : this.payloadFailureCategory,
    payloadFailureCode: payloadFailureCode.present
        ? payloadFailureCode.value
        : this.payloadFailureCode,
    payloadFailureRetryable: payloadFailureRetryable.present
        ? payloadFailureRetryable.value
        : this.payloadFailureRetryable,
    payloadNativeTypeNumber: payloadNativeTypeNumber.present
        ? payloadNativeTypeNumber.value
        : this.payloadNativeTypeNumber,
    envelopeSha256: envelopeSha256 ?? this.envelopeSha256,
  );
  _StoredClientEvent copyWithCompanion(_ClientEventsCompanion data) {
    return _StoredClientEvent(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      originDeviceId: data.originDeviceId.present
          ? data.originDeviceId.value
          : this.originDeviceId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      sequenceText: data.sequenceText.present
          ? data.sequenceText.value
          : this.sequenceText,
      occurredAtMicros: data.occurredAtMicros.present
          ? data.occurredAtMicros.value
          : this.occurredAtMicros,
      kind: data.kind.present ? data.kind.value : this.kind,
      payloadSafeMessage: data.payloadSafeMessage.present
          ? data.payloadSafeMessage.value
          : this.payloadSafeMessage,
      payloadText: data.payloadText.present
          ? data.payloadText.value
          : this.payloadText,
      payloadRevisionText: data.payloadRevisionText.present
          ? data.payloadRevisionText.value
          : this.payloadRevisionText,
      payloadToolName: data.payloadToolName.present
          ? data.payloadToolName.value
          : this.payloadToolName,
      payloadToolStage: data.payloadToolStage.present
          ? data.payloadToolStage.value
          : this.payloadToolStage,
      payloadSafeSummary: data.payloadSafeSummary.present
          ? data.payloadSafeSummary.value
          : this.payloadSafeSummary,
      payloadApprovalId: data.payloadApprovalId.present
          ? data.payloadApprovalId.value
          : this.payloadApprovalId,
      payloadOperationSummarySha256: data.payloadOperationSummarySha256.present
          ? data.payloadOperationSummarySha256.value
          : this.payloadOperationSummarySha256,
      payloadExpiresAtMicros: data.payloadExpiresAtMicros.present
          ? data.payloadExpiresAtMicros.value
          : this.payloadExpiresAtMicros,
      payloadClarificationId: data.payloadClarificationId.present
          ? data.payloadClarificationId.value
          : this.payloadClarificationId,
      payloadSafePrompt: data.payloadSafePrompt.present
          ? data.payloadSafePrompt.value
          : this.payloadSafePrompt,
      payloadFailureStage: data.payloadFailureStage.present
          ? data.payloadFailureStage.value
          : this.payloadFailureStage,
      payloadFailureCategory: data.payloadFailureCategory.present
          ? data.payloadFailureCategory.value
          : this.payloadFailureCategory,
      payloadFailureCode: data.payloadFailureCode.present
          ? data.payloadFailureCode.value
          : this.payloadFailureCode,
      payloadFailureRetryable: data.payloadFailureRetryable.present
          ? data.payloadFailureRetryable.value
          : this.payloadFailureRetryable,
      payloadNativeTypeNumber: data.payloadNativeTypeNumber.present
          ? data.payloadNativeTypeNumber.value
          : this.payloadNativeTypeNumber,
      envelopeSha256: data.envelopeSha256.present
          ? data.envelopeSha256.value
          : this.envelopeSha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredClientEvent(')
          ..write('eventId: $eventId, ')
          ..write('connectionId: $connectionId, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('conversationId: $conversationId, ')
          ..write('sessionId: $sessionId, ')
          ..write('requestId: $requestId, ')
          ..write('sequenceText: $sequenceText, ')
          ..write('occurredAtMicros: $occurredAtMicros, ')
          ..write('kind: $kind, ')
          ..write('payloadSafeMessage: $payloadSafeMessage, ')
          ..write('payloadText: $payloadText, ')
          ..write('payloadRevisionText: $payloadRevisionText, ')
          ..write('payloadToolName: $payloadToolName, ')
          ..write('payloadToolStage: $payloadToolStage, ')
          ..write('payloadSafeSummary: $payloadSafeSummary, ')
          ..write('payloadApprovalId: $payloadApprovalId, ')
          ..write(
            'payloadOperationSummarySha256: $payloadOperationSummarySha256, ',
          )
          ..write('payloadExpiresAtMicros: $payloadExpiresAtMicros, ')
          ..write('payloadClarificationId: $payloadClarificationId, ')
          ..write('payloadSafePrompt: $payloadSafePrompt, ')
          ..write('payloadFailureStage: $payloadFailureStage, ')
          ..write('payloadFailureCategory: $payloadFailureCategory, ')
          ..write('payloadFailureCode: $payloadFailureCode, ')
          ..write('payloadFailureRetryable: $payloadFailureRetryable, ')
          ..write('payloadNativeTypeNumber: $payloadNativeTypeNumber, ')
          ..write('envelopeSha256: $envelopeSha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    eventId,
    connectionId,
    originDeviceId,
    conversationId,
    sessionId,
    requestId,
    sequenceText,
    occurredAtMicros,
    kind,
    payloadSafeMessage,
    payloadText,
    payloadRevisionText,
    payloadToolName,
    payloadToolStage,
    payloadSafeSummary,
    payloadApprovalId,
    payloadOperationSummarySha256,
    payloadExpiresAtMicros,
    payloadClarificationId,
    payloadSafePrompt,
    payloadFailureStage,
    payloadFailureCategory,
    payloadFailureCode,
    payloadFailureRetryable,
    payloadNativeTypeNumber,
    envelopeSha256,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredClientEvent &&
          other.eventId == this.eventId &&
          other.connectionId == this.connectionId &&
          other.originDeviceId == this.originDeviceId &&
          other.conversationId == this.conversationId &&
          other.sessionId == this.sessionId &&
          other.requestId == this.requestId &&
          other.sequenceText == this.sequenceText &&
          other.occurredAtMicros == this.occurredAtMicros &&
          other.kind == this.kind &&
          other.payloadSafeMessage == this.payloadSafeMessage &&
          other.payloadText == this.payloadText &&
          other.payloadRevisionText == this.payloadRevisionText &&
          other.payloadToolName == this.payloadToolName &&
          other.payloadToolStage == this.payloadToolStage &&
          other.payloadSafeSummary == this.payloadSafeSummary &&
          other.payloadApprovalId == this.payloadApprovalId &&
          other.payloadOperationSummarySha256 ==
              this.payloadOperationSummarySha256 &&
          other.payloadExpiresAtMicros == this.payloadExpiresAtMicros &&
          other.payloadClarificationId == this.payloadClarificationId &&
          other.payloadSafePrompt == this.payloadSafePrompt &&
          other.payloadFailureStage == this.payloadFailureStage &&
          other.payloadFailureCategory == this.payloadFailureCategory &&
          other.payloadFailureCode == this.payloadFailureCode &&
          other.payloadFailureRetryable == this.payloadFailureRetryable &&
          other.payloadNativeTypeNumber == this.payloadNativeTypeNumber &&
          other.envelopeSha256 == this.envelopeSha256);
}

class _ClientEventsCompanion extends UpdateCompanion<_StoredClientEvent> {
  final Value<String> eventId;
  final Value<String> connectionId;
  final Value<String> originDeviceId;
  final Value<String> conversationId;
  final Value<String?> sessionId;
  final Value<String> requestId;
  final Value<String> sequenceText;
  final Value<int> occurredAtMicros;
  final Value<String> kind;
  final Value<String?> payloadSafeMessage;
  final Value<String?> payloadText;
  final Value<String?> payloadRevisionText;
  final Value<String?> payloadToolName;
  final Value<String?> payloadToolStage;
  final Value<String?> payloadSafeSummary;
  final Value<String?> payloadApprovalId;
  final Value<String?> payloadOperationSummarySha256;
  final Value<int?> payloadExpiresAtMicros;
  final Value<String?> payloadClarificationId;
  final Value<String?> payloadSafePrompt;
  final Value<String?> payloadFailureStage;
  final Value<String?> payloadFailureCategory;
  final Value<String?> payloadFailureCode;
  final Value<bool?> payloadFailureRetryable;
  final Value<int?> payloadNativeTypeNumber;
  final Value<String> envelopeSha256;
  final Value<int> rowid;
  const _ClientEventsCompanion({
    this.eventId = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.originDeviceId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.requestId = const Value.absent(),
    this.sequenceText = const Value.absent(),
    this.occurredAtMicros = const Value.absent(),
    this.kind = const Value.absent(),
    this.payloadSafeMessage = const Value.absent(),
    this.payloadText = const Value.absent(),
    this.payloadRevisionText = const Value.absent(),
    this.payloadToolName = const Value.absent(),
    this.payloadToolStage = const Value.absent(),
    this.payloadSafeSummary = const Value.absent(),
    this.payloadApprovalId = const Value.absent(),
    this.payloadOperationSummarySha256 = const Value.absent(),
    this.payloadExpiresAtMicros = const Value.absent(),
    this.payloadClarificationId = const Value.absent(),
    this.payloadSafePrompt = const Value.absent(),
    this.payloadFailureStage = const Value.absent(),
    this.payloadFailureCategory = const Value.absent(),
    this.payloadFailureCode = const Value.absent(),
    this.payloadFailureRetryable = const Value.absent(),
    this.payloadNativeTypeNumber = const Value.absent(),
    this.envelopeSha256 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _ClientEventsCompanion.insert({
    required String eventId,
    required String connectionId,
    required String originDeviceId,
    required String conversationId,
    this.sessionId = const Value.absent(),
    required String requestId,
    required String sequenceText,
    required int occurredAtMicros,
    required String kind,
    this.payloadSafeMessage = const Value.absent(),
    this.payloadText = const Value.absent(),
    this.payloadRevisionText = const Value.absent(),
    this.payloadToolName = const Value.absent(),
    this.payloadToolStage = const Value.absent(),
    this.payloadSafeSummary = const Value.absent(),
    this.payloadApprovalId = const Value.absent(),
    this.payloadOperationSummarySha256 = const Value.absent(),
    this.payloadExpiresAtMicros = const Value.absent(),
    this.payloadClarificationId = const Value.absent(),
    this.payloadSafePrompt = const Value.absent(),
    this.payloadFailureStage = const Value.absent(),
    this.payloadFailureCategory = const Value.absent(),
    this.payloadFailureCode = const Value.absent(),
    this.payloadFailureRetryable = const Value.absent(),
    this.payloadNativeTypeNumber = const Value.absent(),
    required String envelopeSha256,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       connectionId = Value(connectionId),
       originDeviceId = Value(originDeviceId),
       conversationId = Value(conversationId),
       requestId = Value(requestId),
       sequenceText = Value(sequenceText),
       occurredAtMicros = Value(occurredAtMicros),
       kind = Value(kind),
       envelopeSha256 = Value(envelopeSha256);
  static Insertable<_StoredClientEvent> custom({
    Expression<String>? eventId,
    Expression<String>? connectionId,
    Expression<String>? originDeviceId,
    Expression<String>? conversationId,
    Expression<String>? sessionId,
    Expression<String>? requestId,
    Expression<String>? sequenceText,
    Expression<int>? occurredAtMicros,
    Expression<String>? kind,
    Expression<String>? payloadSafeMessage,
    Expression<String>? payloadText,
    Expression<String>? payloadRevisionText,
    Expression<String>? payloadToolName,
    Expression<String>? payloadToolStage,
    Expression<String>? payloadSafeSummary,
    Expression<String>? payloadApprovalId,
    Expression<String>? payloadOperationSummarySha256,
    Expression<int>? payloadExpiresAtMicros,
    Expression<String>? payloadClarificationId,
    Expression<String>? payloadSafePrompt,
    Expression<String>? payloadFailureStage,
    Expression<String>? payloadFailureCategory,
    Expression<String>? payloadFailureCode,
    Expression<bool>? payloadFailureRetryable,
    Expression<int>? payloadNativeTypeNumber,
    Expression<String>? envelopeSha256,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (connectionId != null) 'connection_id': connectionId,
      if (originDeviceId != null) 'origin_device_id': originDeviceId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (sessionId != null) 'session_id': sessionId,
      if (requestId != null) 'request_id': requestId,
      if (sequenceText != null) 'sequence_text': sequenceText,
      if (occurredAtMicros != null) 'occurred_at_micros': occurredAtMicros,
      if (kind != null) 'kind': kind,
      if (payloadSafeMessage != null)
        'payload_safe_message': payloadSafeMessage,
      if (payloadText != null) 'payload_text': payloadText,
      if (payloadRevisionText != null)
        'payload_revision_text': payloadRevisionText,
      if (payloadToolName != null) 'payload_tool_name': payloadToolName,
      if (payloadToolStage != null) 'payload_tool_stage': payloadToolStage,
      if (payloadSafeSummary != null)
        'payload_safe_summary': payloadSafeSummary,
      if (payloadApprovalId != null) 'payload_approval_id': payloadApprovalId,
      if (payloadOperationSummarySha256 != null)
        'payload_operation_summary_sha256': payloadOperationSummarySha256,
      if (payloadExpiresAtMicros != null)
        'payload_expires_at_micros': payloadExpiresAtMicros,
      if (payloadClarificationId != null)
        'payload_clarification_id': payloadClarificationId,
      if (payloadSafePrompt != null) 'payload_safe_prompt': payloadSafePrompt,
      if (payloadFailureStage != null)
        'payload_failure_stage': payloadFailureStage,
      if (payloadFailureCategory != null)
        'payload_failure_category': payloadFailureCategory,
      if (payloadFailureCode != null)
        'payload_failure_code': payloadFailureCode,
      if (payloadFailureRetryable != null)
        'payload_failure_retryable': payloadFailureRetryable,
      if (payloadNativeTypeNumber != null)
        'payload_native_type_number': payloadNativeTypeNumber,
      if (envelopeSha256 != null) 'envelope_sha256': envelopeSha256,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _ClientEventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? connectionId,
    Value<String>? originDeviceId,
    Value<String>? conversationId,
    Value<String?>? sessionId,
    Value<String>? requestId,
    Value<String>? sequenceText,
    Value<int>? occurredAtMicros,
    Value<String>? kind,
    Value<String?>? payloadSafeMessage,
    Value<String?>? payloadText,
    Value<String?>? payloadRevisionText,
    Value<String?>? payloadToolName,
    Value<String?>? payloadToolStage,
    Value<String?>? payloadSafeSummary,
    Value<String?>? payloadApprovalId,
    Value<String?>? payloadOperationSummarySha256,
    Value<int?>? payloadExpiresAtMicros,
    Value<String?>? payloadClarificationId,
    Value<String?>? payloadSafePrompt,
    Value<String?>? payloadFailureStage,
    Value<String?>? payloadFailureCategory,
    Value<String?>? payloadFailureCode,
    Value<bool?>? payloadFailureRetryable,
    Value<int?>? payloadNativeTypeNumber,
    Value<String>? envelopeSha256,
    Value<int>? rowid,
  }) {
    return _ClientEventsCompanion(
      eventId: eventId ?? this.eventId,
      connectionId: connectionId ?? this.connectionId,
      originDeviceId: originDeviceId ?? this.originDeviceId,
      conversationId: conversationId ?? this.conversationId,
      sessionId: sessionId ?? this.sessionId,
      requestId: requestId ?? this.requestId,
      sequenceText: sequenceText ?? this.sequenceText,
      occurredAtMicros: occurredAtMicros ?? this.occurredAtMicros,
      kind: kind ?? this.kind,
      payloadSafeMessage: payloadSafeMessage ?? this.payloadSafeMessage,
      payloadText: payloadText ?? this.payloadText,
      payloadRevisionText: payloadRevisionText ?? this.payloadRevisionText,
      payloadToolName: payloadToolName ?? this.payloadToolName,
      payloadToolStage: payloadToolStage ?? this.payloadToolStage,
      payloadSafeSummary: payloadSafeSummary ?? this.payloadSafeSummary,
      payloadApprovalId: payloadApprovalId ?? this.payloadApprovalId,
      payloadOperationSummarySha256:
          payloadOperationSummarySha256 ?? this.payloadOperationSummarySha256,
      payloadExpiresAtMicros:
          payloadExpiresAtMicros ?? this.payloadExpiresAtMicros,
      payloadClarificationId:
          payloadClarificationId ?? this.payloadClarificationId,
      payloadSafePrompt: payloadSafePrompt ?? this.payloadSafePrompt,
      payloadFailureStage: payloadFailureStage ?? this.payloadFailureStage,
      payloadFailureCategory:
          payloadFailureCategory ?? this.payloadFailureCategory,
      payloadFailureCode: payloadFailureCode ?? this.payloadFailureCode,
      payloadFailureRetryable:
          payloadFailureRetryable ?? this.payloadFailureRetryable,
      payloadNativeTypeNumber:
          payloadNativeTypeNumber ?? this.payloadNativeTypeNumber,
      envelopeSha256: envelopeSha256 ?? this.envelopeSha256,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<String>(connectionId.value);
    }
    if (originDeviceId.present) {
      map['origin_device_id'] = Variable<String>(originDeviceId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (sequenceText.present) {
      map['sequence_text'] = Variable<String>(sequenceText.value);
    }
    if (occurredAtMicros.present) {
      map['occurred_at_micros'] = Variable<int>(occurredAtMicros.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payloadSafeMessage.present) {
      map['payload_safe_message'] = Variable<String>(payloadSafeMessage.value);
    }
    if (payloadText.present) {
      map['payload_text'] = Variable<String>(payloadText.value);
    }
    if (payloadRevisionText.present) {
      map['payload_revision_text'] = Variable<String>(
        payloadRevisionText.value,
      );
    }
    if (payloadToolName.present) {
      map['payload_tool_name'] = Variable<String>(payloadToolName.value);
    }
    if (payloadToolStage.present) {
      map['payload_tool_stage'] = Variable<String>(payloadToolStage.value);
    }
    if (payloadSafeSummary.present) {
      map['payload_safe_summary'] = Variable<String>(payloadSafeSummary.value);
    }
    if (payloadApprovalId.present) {
      map['payload_approval_id'] = Variable<String>(payloadApprovalId.value);
    }
    if (payloadOperationSummarySha256.present) {
      map['payload_operation_summary_sha256'] = Variable<String>(
        payloadOperationSummarySha256.value,
      );
    }
    if (payloadExpiresAtMicros.present) {
      map['payload_expires_at_micros'] = Variable<int>(
        payloadExpiresAtMicros.value,
      );
    }
    if (payloadClarificationId.present) {
      map['payload_clarification_id'] = Variable<String>(
        payloadClarificationId.value,
      );
    }
    if (payloadSafePrompt.present) {
      map['payload_safe_prompt'] = Variable<String>(payloadSafePrompt.value);
    }
    if (payloadFailureStage.present) {
      map['payload_failure_stage'] = Variable<String>(
        payloadFailureStage.value,
      );
    }
    if (payloadFailureCategory.present) {
      map['payload_failure_category'] = Variable<String>(
        payloadFailureCategory.value,
      );
    }
    if (payloadFailureCode.present) {
      map['payload_failure_code'] = Variable<String>(payloadFailureCode.value);
    }
    if (payloadFailureRetryable.present) {
      map['payload_failure_retryable'] = Variable<bool>(
        payloadFailureRetryable.value,
      );
    }
    if (payloadNativeTypeNumber.present) {
      map['payload_native_type_number'] = Variable<int>(
        payloadNativeTypeNumber.value,
      );
    }
    if (envelopeSha256.present) {
      map['envelope_sha256'] = Variable<String>(envelopeSha256.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_ClientEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('connectionId: $connectionId, ')
          ..write('originDeviceId: $originDeviceId, ')
          ..write('conversationId: $conversationId, ')
          ..write('sessionId: $sessionId, ')
          ..write('requestId: $requestId, ')
          ..write('sequenceText: $sequenceText, ')
          ..write('occurredAtMicros: $occurredAtMicros, ')
          ..write('kind: $kind, ')
          ..write('payloadSafeMessage: $payloadSafeMessage, ')
          ..write('payloadText: $payloadText, ')
          ..write('payloadRevisionText: $payloadRevisionText, ')
          ..write('payloadToolName: $payloadToolName, ')
          ..write('payloadToolStage: $payloadToolStage, ')
          ..write('payloadSafeSummary: $payloadSafeSummary, ')
          ..write('payloadApprovalId: $payloadApprovalId, ')
          ..write(
            'payloadOperationSummarySha256: $payloadOperationSummarySha256, ',
          )
          ..write('payloadExpiresAtMicros: $payloadExpiresAtMicros, ')
          ..write('payloadClarificationId: $payloadClarificationId, ')
          ..write('payloadSafePrompt: $payloadSafePrompt, ')
          ..write('payloadFailureStage: $payloadFailureStage, ')
          ..write('payloadFailureCategory: $payloadFailureCategory, ')
          ..write('payloadFailureCode: $payloadFailureCode, ')
          ..write('payloadFailureRetryable: $payloadFailureRetryable, ')
          ..write('payloadNativeTypeNumber: $payloadNativeTypeNumber, ')
          ..write('envelopeSha256: $envelopeSha256, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $_ConversationCursorsTable extends _ConversationCursors
    with TableInfo<$_ConversationCursorsTable, _StoredConversationCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_ConversationCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceTextMeta = const VerificationMeta(
    'sequenceText',
  );
  @override
  late final GeneratedColumn<String> sequenceText = GeneratedColumn<String>(
    'sequence_text',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 20,
      maxTextLength: 20,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [conversationId, sequenceText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredConversationCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sequence_text')) {
      context.handle(
        _sequenceTextMeta,
        sequenceText.isAcceptableOrUnknown(
          data['sequence_text']!,
          _sequenceTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId};
  @override
  _StoredConversationCursor map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredConversationCursor(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      sequenceText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sequence_text'],
      )!,
    );
  }

  @override
  $_ConversationCursorsTable createAlias(String alias) {
    return $_ConversationCursorsTable(attachedDatabase, alias);
  }
}

class _StoredConversationCursor extends DataClass
    implements Insertable<_StoredConversationCursor> {
  final String conversationId;

  /// Unsigned 64-bit values are stored as canonical, zero-padded decimal text.
  final String sequenceText;
  const _StoredConversationCursor({
    required this.conversationId,
    required this.sequenceText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['sequence_text'] = Variable<String>(sequenceText);
    return map;
  }

  _ConversationCursorsCompanion toCompanion(bool nullToAbsent) {
    return _ConversationCursorsCompanion(
      conversationId: Value(conversationId),
      sequenceText: Value(sequenceText),
    );
  }

  factory _StoredConversationCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredConversationCursor(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      sequenceText: serializer.fromJson<String>(json['sequenceText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'sequenceText': serializer.toJson<String>(sequenceText),
    };
  }

  _StoredConversationCursor copyWith({
    String? conversationId,
    String? sequenceText,
  }) => _StoredConversationCursor(
    conversationId: conversationId ?? this.conversationId,
    sequenceText: sequenceText ?? this.sequenceText,
  );
  _StoredConversationCursor copyWithCompanion(
    _ConversationCursorsCompanion data,
  ) {
    return _StoredConversationCursor(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      sequenceText: data.sequenceText.present
          ? data.sequenceText.value
          : this.sequenceText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredConversationCursor(')
          ..write('conversationId: $conversationId, ')
          ..write('sequenceText: $sequenceText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, sequenceText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredConversationCursor &&
          other.conversationId == this.conversationId &&
          other.sequenceText == this.sequenceText);
}

class _ConversationCursorsCompanion
    extends UpdateCompanion<_StoredConversationCursor> {
  final Value<String> conversationId;
  final Value<String> sequenceText;
  final Value<int> rowid;
  const _ConversationCursorsCompanion({
    this.conversationId = const Value.absent(),
    this.sequenceText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _ConversationCursorsCompanion.insert({
    required String conversationId,
    required String sequenceText,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       sequenceText = Value(sequenceText);
  static Insertable<_StoredConversationCursor> custom({
    Expression<String>? conversationId,
    Expression<String>? sequenceText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (sequenceText != null) 'sequence_text': sequenceText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _ConversationCursorsCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? sequenceText,
    Value<int>? rowid,
  }) {
    return _ConversationCursorsCompanion(
      conversationId: conversationId ?? this.conversationId,
      sequenceText: sequenceText ?? this.sequenceText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (sequenceText.present) {
      map['sequence_text'] = Variable<String>(sequenceText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_ConversationCursorsCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('sequenceText: $sequenceText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_EventLedgerDatabase extends GeneratedDatabase {
  _$_EventLedgerDatabase(QueryExecutor e) : super(e);
  $_EventLedgerDatabaseManager get managers =>
      $_EventLedgerDatabaseManager(this);
  late final $_TrackedRequestsTable trackedRequests = $_TrackedRequestsTable(
    this,
  );
  late final $_LocalSubmissionsTable localSubmissions = $_LocalSubmissionsTable(
    this,
  );
  late final $_ClientEventsTable clientEvents = $_ClientEventsTable(this);
  late final $_ConversationCursorsTable conversationCursors =
      $_ConversationCursorsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    trackedRequests,
    localSubmissions,
    clientEvents,
    conversationCursors,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracked_requests',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_submissions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$_TrackedRequestsTableCreateCompanionBuilder =
    _TrackedRequestsCompanion Function({
      required String requestId,
      required String originDeviceId,
      required String conversationId,
      Value<String?> sessionId,
      required String nodeId,
      required String agentId,
      required String capabilityRevision,
      Value<String?> acceptedSequenceText,
      Value<int> rowid,
    });
typedef $$_TrackedRequestsTableUpdateCompanionBuilder =
    _TrackedRequestsCompanion Function({
      Value<String> requestId,
      Value<String> originDeviceId,
      Value<String> conversationId,
      Value<String?> sessionId,
      Value<String> nodeId,
      Value<String> agentId,
      Value<String> capabilityRevision,
      Value<String?> acceptedSequenceText,
      Value<int> rowid,
    });

final class $$_TrackedRequestsTableReferences
    extends
        BaseReferences<
          _$_EventLedgerDatabase,
          $_TrackedRequestsTable,
          _StoredTrackedRequest
        > {
  $$_TrackedRequestsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $_LocalSubmissionsTable,
    List<_StoredLocalSubmission>
  >
  _localSubmissionsRefsTable(_$_EventLedgerDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.localSubmissions,
        aliasName:
            'tracked_requests__request_id__local_submissions__request_id',
      );

  $$_LocalSubmissionsTableProcessedTableManager get localSubmissionsRefs {
    final manager =
        $$_LocalSubmissionsTableTableManager(
          $_db,
          $_db.localSubmissions,
        ).filter(
          (f) => f.requestId.requestId.sqlEquals(
            $_itemColumn<String>('request_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _localSubmissionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$_ClientEventsTable, List<_StoredClientEvent>>
  _clientEventsRefsTable(_$_EventLedgerDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.clientEvents,
        aliasName: 'tracked_requests__request_id__client_events__request_id',
      );

  $$_ClientEventsTableProcessedTableManager get clientEventsRefs {
    final manager = $$_ClientEventsTableTableManager($_db, $_db.clientEvents)
        .filter(
          (f) => f.requestId.requestId.sqlEquals(
            $_itemColumn<String>('request_id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_clientEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$_TrackedRequestsTableFilterComposer
    extends Composer<_$_EventLedgerDatabase, $_TrackedRequestsTable> {
  $$_TrackedRequestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilityRevision => $composableBuilder(
    column: $table.capabilityRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptedSequenceText => $composableBuilder(
    column: $table.acceptedSequenceText,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localSubmissionsRefs(
    Expression<bool> Function($$_LocalSubmissionsTableFilterComposer f) f,
  ) {
    final $$_LocalSubmissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.localSubmissions,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_LocalSubmissionsTableFilterComposer(
            $db: $db,
            $table: $db.localSubmissions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> clientEventsRefs(
    Expression<bool> Function($$_ClientEventsTableFilterComposer f) f,
  ) {
    final $$_ClientEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.clientEvents,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_ClientEventsTableFilterComposer(
            $db: $db,
            $table: $db.clientEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$_TrackedRequestsTableOrderingComposer
    extends Composer<_$_EventLedgerDatabase, $_TrackedRequestsTable> {
  $$_TrackedRequestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilityRevision => $composableBuilder(
    column: $table.capabilityRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptedSequenceText => $composableBuilder(
    column: $table.acceptedSequenceText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$_TrackedRequestsTableAnnotationComposer
    extends Composer<_$_EventLedgerDatabase, $_TrackedRequestsTable> {
  $$_TrackedRequestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get capabilityRevision => $composableBuilder(
    column: $table.capabilityRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acceptedSequenceText => $composableBuilder(
    column: $table.acceptedSequenceText,
    builder: (column) => column,
  );

  Expression<T> localSubmissionsRefs<T extends Object>(
    Expression<T> Function($$_LocalSubmissionsTableAnnotationComposer a) f,
  ) {
    final $$_LocalSubmissionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.requestId,
          referencedTable: $db.localSubmissions,
          getReferencedColumn: (t) => t.requestId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$_LocalSubmissionsTableAnnotationComposer(
                $db: $db,
                $table: $db.localSubmissions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> clientEventsRefs<T extends Object>(
    Expression<T> Function($$_ClientEventsTableAnnotationComposer a) f,
  ) {
    final $$_ClientEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.clientEvents,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_ClientEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.clientEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$_TrackedRequestsTableTableManager
    extends
        RootTableManager<
          _$_EventLedgerDatabase,
          $_TrackedRequestsTable,
          _StoredTrackedRequest,
          $$_TrackedRequestsTableFilterComposer,
          $$_TrackedRequestsTableOrderingComposer,
          $$_TrackedRequestsTableAnnotationComposer,
          $$_TrackedRequestsTableCreateCompanionBuilder,
          $$_TrackedRequestsTableUpdateCompanionBuilder,
          (_StoredTrackedRequest, $$_TrackedRequestsTableReferences),
          _StoredTrackedRequest,
          PrefetchHooks Function({
            bool localSubmissionsRefs,
            bool clientEventsRefs,
          })
        > {
  $$_TrackedRequestsTableTableManager(
    _$_EventLedgerDatabase db,
    $_TrackedRequestsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_TrackedRequestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$_TrackedRequestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$_TrackedRequestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> originDeviceId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> nodeId = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> capabilityRevision = const Value.absent(),
                Value<String?> acceptedSequenceText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _TrackedRequestsCompanion(
                requestId: requestId,
                originDeviceId: originDeviceId,
                conversationId: conversationId,
                sessionId: sessionId,
                nodeId: nodeId,
                agentId: agentId,
                capabilityRevision: capabilityRevision,
                acceptedSequenceText: acceptedSequenceText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String originDeviceId,
                required String conversationId,
                Value<String?> sessionId = const Value.absent(),
                required String nodeId,
                required String agentId,
                required String capabilityRevision,
                Value<String?> acceptedSequenceText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _TrackedRequestsCompanion.insert(
                requestId: requestId,
                originDeviceId: originDeviceId,
                conversationId: conversationId,
                sessionId: sessionId,
                nodeId: nodeId,
                agentId: agentId,
                capabilityRevision: capabilityRevision,
                acceptedSequenceText: acceptedSequenceText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$_TrackedRequestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({localSubmissionsRefs = false, clientEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localSubmissionsRefs) db.localSubmissions,
                    if (clientEventsRefs) db.clientEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localSubmissionsRefs)
                        await $_getPrefetchedData<
                          _StoredTrackedRequest,
                          $_TrackedRequestsTable,
                          _StoredLocalSubmission
                        >(
                          currentTable: table,
                          referencedTable: $$_TrackedRequestsTableReferences
                              ._localSubmissionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$_TrackedRequestsTableReferences(
                                db,
                                table,
                                p0,
                              ).localSubmissionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.requestId == item.requestId,
                              ),
                          typedResults: items,
                        ),
                      if (clientEventsRefs)
                        await $_getPrefetchedData<
                          _StoredTrackedRequest,
                          $_TrackedRequestsTable,
                          _StoredClientEvent
                        >(
                          currentTable: table,
                          referencedTable: $$_TrackedRequestsTableReferences
                              ._clientEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$_TrackedRequestsTableReferences(
                                db,
                                table,
                                p0,
                              ).clientEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.requestId == item.requestId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$_TrackedRequestsTableProcessedTableManager =
    ProcessedTableManager<
      _$_EventLedgerDatabase,
      $_TrackedRequestsTable,
      _StoredTrackedRequest,
      $$_TrackedRequestsTableFilterComposer,
      $$_TrackedRequestsTableOrderingComposer,
      $$_TrackedRequestsTableAnnotationComposer,
      $$_TrackedRequestsTableCreateCompanionBuilder,
      $$_TrackedRequestsTableUpdateCompanionBuilder,
      (_StoredTrackedRequest, $$_TrackedRequestsTableReferences),
      _StoredTrackedRequest,
      PrefetchHooks Function({bool localSubmissionsRefs, bool clientEventsRefs})
    >;
typedef $$_LocalSubmissionsTableCreateCompanionBuilder =
    _LocalSubmissionsCompanion Function({
      required String requestId,
      required String originDeviceId,
      required String commandId,
      required String idempotencyKey,
      required String confirmedTextSha256,
      required String disposition,
      Value<int> rowid,
    });
typedef $$_LocalSubmissionsTableUpdateCompanionBuilder =
    _LocalSubmissionsCompanion Function({
      Value<String> requestId,
      Value<String> originDeviceId,
      Value<String> commandId,
      Value<String> idempotencyKey,
      Value<String> confirmedTextSha256,
      Value<String> disposition,
      Value<int> rowid,
    });

final class $$_LocalSubmissionsTableReferences
    extends
        BaseReferences<
          _$_EventLedgerDatabase,
          $_LocalSubmissionsTable,
          _StoredLocalSubmission
        > {
  $$_LocalSubmissionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $_TrackedRequestsTable _requestIdTable(_$_EventLedgerDatabase db) =>
      db.trackedRequests.createAlias(
        'local_submissions__request_id__tracked_requests__request_id',
      );

  $$_TrackedRequestsTableProcessedTableManager get requestId {
    final $_column = $_itemColumn<String>('request_id')!;

    final manager = $$_TrackedRequestsTableTableManager(
      $_db,
      $_db.trackedRequests,
    ).filter((f) => f.requestId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_requestIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$_LocalSubmissionsTableFilterComposer
    extends Composer<_$_EventLedgerDatabase, $_LocalSubmissionsTable> {
  $$_LocalSubmissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confirmedTextSha256 => $composableBuilder(
    column: $table.confirmedTextSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get disposition => $composableBuilder(
    column: $table.disposition,
    builder: (column) => ColumnFilters(column),
  );

  $$_TrackedRequestsTableFilterComposer get requestId {
    final $$_TrackedRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.trackedRequests,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_TrackedRequestsTableFilterComposer(
            $db: $db,
            $table: $db.trackedRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$_LocalSubmissionsTableOrderingComposer
    extends Composer<_$_EventLedgerDatabase, $_LocalSubmissionsTable> {
  $$_LocalSubmissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandId => $composableBuilder(
    column: $table.commandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confirmedTextSha256 => $composableBuilder(
    column: $table.confirmedTextSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disposition => $composableBuilder(
    column: $table.disposition,
    builder: (column) => ColumnOrderings(column),
  );

  $$_TrackedRequestsTableOrderingComposer get requestId {
    final $$_TrackedRequestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.trackedRequests,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_TrackedRequestsTableOrderingComposer(
            $db: $db,
            $table: $db.trackedRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$_LocalSubmissionsTableAnnotationComposer
    extends Composer<_$_EventLedgerDatabase, $_LocalSubmissionsTable> {
  $$_LocalSubmissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commandId =>
      $composableBuilder(column: $table.commandId, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confirmedTextSha256 => $composableBuilder(
    column: $table.confirmedTextSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get disposition => $composableBuilder(
    column: $table.disposition,
    builder: (column) => column,
  );

  $$_TrackedRequestsTableAnnotationComposer get requestId {
    final $$_TrackedRequestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.trackedRequests,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_TrackedRequestsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackedRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$_LocalSubmissionsTableTableManager
    extends
        RootTableManager<
          _$_EventLedgerDatabase,
          $_LocalSubmissionsTable,
          _StoredLocalSubmission,
          $$_LocalSubmissionsTableFilterComposer,
          $$_LocalSubmissionsTableOrderingComposer,
          $$_LocalSubmissionsTableAnnotationComposer,
          $$_LocalSubmissionsTableCreateCompanionBuilder,
          $$_LocalSubmissionsTableUpdateCompanionBuilder,
          (_StoredLocalSubmission, $$_LocalSubmissionsTableReferences),
          _StoredLocalSubmission,
          PrefetchHooks Function({bool requestId})
        > {
  $$_LocalSubmissionsTableTableManager(
    _$_EventLedgerDatabase db,
    $_LocalSubmissionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_LocalSubmissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$_LocalSubmissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$_LocalSubmissionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> originDeviceId = const Value.absent(),
                Value<String> commandId = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> confirmedTextSha256 = const Value.absent(),
                Value<String> disposition = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _LocalSubmissionsCompanion(
                requestId: requestId,
                originDeviceId: originDeviceId,
                commandId: commandId,
                idempotencyKey: idempotencyKey,
                confirmedTextSha256: confirmedTextSha256,
                disposition: disposition,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String originDeviceId,
                required String commandId,
                required String idempotencyKey,
                required String confirmedTextSha256,
                required String disposition,
                Value<int> rowid = const Value.absent(),
              }) => _LocalSubmissionsCompanion.insert(
                requestId: requestId,
                originDeviceId: originDeviceId,
                commandId: commandId,
                idempotencyKey: idempotencyKey,
                confirmedTextSha256: confirmedTextSha256,
                disposition: disposition,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$_LocalSubmissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({requestId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (requestId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.requestId,
                                referencedTable:
                                    $$_LocalSubmissionsTableReferences
                                        ._requestIdTable(db),
                                referencedColumn:
                                    $$_LocalSubmissionsTableReferences
                                        ._requestIdTable(db)
                                        .requestId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$_LocalSubmissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$_EventLedgerDatabase,
      $_LocalSubmissionsTable,
      _StoredLocalSubmission,
      $$_LocalSubmissionsTableFilterComposer,
      $$_LocalSubmissionsTableOrderingComposer,
      $$_LocalSubmissionsTableAnnotationComposer,
      $$_LocalSubmissionsTableCreateCompanionBuilder,
      $$_LocalSubmissionsTableUpdateCompanionBuilder,
      (_StoredLocalSubmission, $$_LocalSubmissionsTableReferences),
      _StoredLocalSubmission,
      PrefetchHooks Function({bool requestId})
    >;
typedef $$_ClientEventsTableCreateCompanionBuilder =
    _ClientEventsCompanion Function({
      required String eventId,
      required String connectionId,
      required String originDeviceId,
      required String conversationId,
      Value<String?> sessionId,
      required String requestId,
      required String sequenceText,
      required int occurredAtMicros,
      required String kind,
      Value<String?> payloadSafeMessage,
      Value<String?> payloadText,
      Value<String?> payloadRevisionText,
      Value<String?> payloadToolName,
      Value<String?> payloadToolStage,
      Value<String?> payloadSafeSummary,
      Value<String?> payloadApprovalId,
      Value<String?> payloadOperationSummarySha256,
      Value<int?> payloadExpiresAtMicros,
      Value<String?> payloadClarificationId,
      Value<String?> payloadSafePrompt,
      Value<String?> payloadFailureStage,
      Value<String?> payloadFailureCategory,
      Value<String?> payloadFailureCode,
      Value<bool?> payloadFailureRetryable,
      Value<int?> payloadNativeTypeNumber,
      required String envelopeSha256,
      Value<int> rowid,
    });
typedef $$_ClientEventsTableUpdateCompanionBuilder =
    _ClientEventsCompanion Function({
      Value<String> eventId,
      Value<String> connectionId,
      Value<String> originDeviceId,
      Value<String> conversationId,
      Value<String?> sessionId,
      Value<String> requestId,
      Value<String> sequenceText,
      Value<int> occurredAtMicros,
      Value<String> kind,
      Value<String?> payloadSafeMessage,
      Value<String?> payloadText,
      Value<String?> payloadRevisionText,
      Value<String?> payloadToolName,
      Value<String?> payloadToolStage,
      Value<String?> payloadSafeSummary,
      Value<String?> payloadApprovalId,
      Value<String?> payloadOperationSummarySha256,
      Value<int?> payloadExpiresAtMicros,
      Value<String?> payloadClarificationId,
      Value<String?> payloadSafePrompt,
      Value<String?> payloadFailureStage,
      Value<String?> payloadFailureCategory,
      Value<String?> payloadFailureCode,
      Value<bool?> payloadFailureRetryable,
      Value<int?> payloadNativeTypeNumber,
      Value<String> envelopeSha256,
      Value<int> rowid,
    });

final class $$_ClientEventsTableReferences
    extends
        BaseReferences<
          _$_EventLedgerDatabase,
          $_ClientEventsTable,
          _StoredClientEvent
        > {
  $$_ClientEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $_TrackedRequestsTable _requestIdTable(_$_EventLedgerDatabase db) => db
      .trackedRequests
      .createAlias('client_events__request_id__tracked_requests__request_id');

  $$_TrackedRequestsTableProcessedTableManager get requestId {
    final $_column = $_itemColumn<String>('request_id')!;

    final manager = $$_TrackedRequestsTableTableManager(
      $_db,
      $_db.trackedRequests,
    ).filter((f) => f.requestId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_requestIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$_ClientEventsTableFilterComposer
    extends Composer<_$_EventLedgerDatabase, $_ClientEventsTable> {
  $$_ClientEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sequenceText => $composableBuilder(
    column: $table.sequenceText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurredAtMicros => $composableBuilder(
    column: $table.occurredAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadSafeMessage => $composableBuilder(
    column: $table.payloadSafeMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadText => $composableBuilder(
    column: $table.payloadText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadRevisionText => $composableBuilder(
    column: $table.payloadRevisionText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadToolName => $composableBuilder(
    column: $table.payloadToolName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadToolStage => $composableBuilder(
    column: $table.payloadToolStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadSafeSummary => $composableBuilder(
    column: $table.payloadSafeSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadApprovalId => $composableBuilder(
    column: $table.payloadApprovalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadOperationSummarySha256 => $composableBuilder(
    column: $table.payloadOperationSummarySha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadExpiresAtMicros => $composableBuilder(
    column: $table.payloadExpiresAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadClarificationId => $composableBuilder(
    column: $table.payloadClarificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadSafePrompt => $composableBuilder(
    column: $table.payloadSafePrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadFailureStage => $composableBuilder(
    column: $table.payloadFailureStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadFailureCategory => $composableBuilder(
    column: $table.payloadFailureCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadFailureCode => $composableBuilder(
    column: $table.payloadFailureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get payloadFailureRetryable => $composableBuilder(
    column: $table.payloadFailureRetryable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get payloadNativeTypeNumber => $composableBuilder(
    column: $table.payloadNativeTypeNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get envelopeSha256 => $composableBuilder(
    column: $table.envelopeSha256,
    builder: (column) => ColumnFilters(column),
  );

  $$_TrackedRequestsTableFilterComposer get requestId {
    final $$_TrackedRequestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.trackedRequests,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_TrackedRequestsTableFilterComposer(
            $db: $db,
            $table: $db.trackedRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$_ClientEventsTableOrderingComposer
    extends Composer<_$_EventLedgerDatabase, $_ClientEventsTable> {
  $$_ClientEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sequenceText => $composableBuilder(
    column: $table.sequenceText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurredAtMicros => $composableBuilder(
    column: $table.occurredAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadSafeMessage => $composableBuilder(
    column: $table.payloadSafeMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadText => $composableBuilder(
    column: $table.payloadText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadRevisionText => $composableBuilder(
    column: $table.payloadRevisionText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadToolName => $composableBuilder(
    column: $table.payloadToolName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadToolStage => $composableBuilder(
    column: $table.payloadToolStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadSafeSummary => $composableBuilder(
    column: $table.payloadSafeSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadApprovalId => $composableBuilder(
    column: $table.payloadApprovalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadOperationSummarySha256 =>
      $composableBuilder(
        column: $table.payloadOperationSummarySha256,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<int> get payloadExpiresAtMicros => $composableBuilder(
    column: $table.payloadExpiresAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadClarificationId => $composableBuilder(
    column: $table.payloadClarificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadSafePrompt => $composableBuilder(
    column: $table.payloadSafePrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadFailureStage => $composableBuilder(
    column: $table.payloadFailureStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadFailureCategory => $composableBuilder(
    column: $table.payloadFailureCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadFailureCode => $composableBuilder(
    column: $table.payloadFailureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get payloadFailureRetryable => $composableBuilder(
    column: $table.payloadFailureRetryable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get payloadNativeTypeNumber => $composableBuilder(
    column: $table.payloadNativeTypeNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get envelopeSha256 => $composableBuilder(
    column: $table.envelopeSha256,
    builder: (column) => ColumnOrderings(column),
  );

  $$_TrackedRequestsTableOrderingComposer get requestId {
    final $$_TrackedRequestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.trackedRequests,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_TrackedRequestsTableOrderingComposer(
            $db: $db,
            $table: $db.trackedRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$_ClientEventsTableAnnotationComposer
    extends Composer<_$_EventLedgerDatabase, $_ClientEventsTable> {
  $$_ClientEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originDeviceId => $composableBuilder(
    column: $table.originDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get sequenceText => $composableBuilder(
    column: $table.sequenceText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurredAtMicros => $composableBuilder(
    column: $table.occurredAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payloadSafeMessage => $composableBuilder(
    column: $table.payloadSafeMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadText => $composableBuilder(
    column: $table.payloadText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadRevisionText => $composableBuilder(
    column: $table.payloadRevisionText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadToolName => $composableBuilder(
    column: $table.payloadToolName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadToolStage => $composableBuilder(
    column: $table.payloadToolStage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadSafeSummary => $composableBuilder(
    column: $table.payloadSafeSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadApprovalId => $composableBuilder(
    column: $table.payloadApprovalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadOperationSummarySha256 =>
      $composableBuilder(
        column: $table.payloadOperationSummarySha256,
        builder: (column) => column,
      );

  GeneratedColumn<int> get payloadExpiresAtMicros => $composableBuilder(
    column: $table.payloadExpiresAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadClarificationId => $composableBuilder(
    column: $table.payloadClarificationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadSafePrompt => $composableBuilder(
    column: $table.payloadSafePrompt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadFailureStage => $composableBuilder(
    column: $table.payloadFailureStage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadFailureCategory => $composableBuilder(
    column: $table.payloadFailureCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadFailureCode => $composableBuilder(
    column: $table.payloadFailureCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get payloadFailureRetryable => $composableBuilder(
    column: $table.payloadFailureRetryable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get payloadNativeTypeNumber => $composableBuilder(
    column: $table.payloadNativeTypeNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get envelopeSha256 => $composableBuilder(
    column: $table.envelopeSha256,
    builder: (column) => column,
  );

  $$_TrackedRequestsTableAnnotationComposer get requestId {
    final $$_TrackedRequestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.requestId,
      referencedTable: $db.trackedRequests,
      getReferencedColumn: (t) => t.requestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$_TrackedRequestsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackedRequests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$_ClientEventsTableTableManager
    extends
        RootTableManager<
          _$_EventLedgerDatabase,
          $_ClientEventsTable,
          _StoredClientEvent,
          $$_ClientEventsTableFilterComposer,
          $$_ClientEventsTableOrderingComposer,
          $$_ClientEventsTableAnnotationComposer,
          $$_ClientEventsTableCreateCompanionBuilder,
          $$_ClientEventsTableUpdateCompanionBuilder,
          (_StoredClientEvent, $$_ClientEventsTableReferences),
          _StoredClientEvent,
          PrefetchHooks Function({bool requestId})
        > {
  $$_ClientEventsTableTableManager(
    _$_EventLedgerDatabase db,
    $_ClientEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_ClientEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$_ClientEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$_ClientEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> connectionId = const Value.absent(),
                Value<String> originDeviceId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> requestId = const Value.absent(),
                Value<String> sequenceText = const Value.absent(),
                Value<int> occurredAtMicros = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> payloadSafeMessage = const Value.absent(),
                Value<String?> payloadText = const Value.absent(),
                Value<String?> payloadRevisionText = const Value.absent(),
                Value<String?> payloadToolName = const Value.absent(),
                Value<String?> payloadToolStage = const Value.absent(),
                Value<String?> payloadSafeSummary = const Value.absent(),
                Value<String?> payloadApprovalId = const Value.absent(),
                Value<String?> payloadOperationSummarySha256 =
                    const Value.absent(),
                Value<int?> payloadExpiresAtMicros = const Value.absent(),
                Value<String?> payloadClarificationId = const Value.absent(),
                Value<String?> payloadSafePrompt = const Value.absent(),
                Value<String?> payloadFailureStage = const Value.absent(),
                Value<String?> payloadFailureCategory = const Value.absent(),
                Value<String?> payloadFailureCode = const Value.absent(),
                Value<bool?> payloadFailureRetryable = const Value.absent(),
                Value<int?> payloadNativeTypeNumber = const Value.absent(),
                Value<String> envelopeSha256 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _ClientEventsCompanion(
                eventId: eventId,
                connectionId: connectionId,
                originDeviceId: originDeviceId,
                conversationId: conversationId,
                sessionId: sessionId,
                requestId: requestId,
                sequenceText: sequenceText,
                occurredAtMicros: occurredAtMicros,
                kind: kind,
                payloadSafeMessage: payloadSafeMessage,
                payloadText: payloadText,
                payloadRevisionText: payloadRevisionText,
                payloadToolName: payloadToolName,
                payloadToolStage: payloadToolStage,
                payloadSafeSummary: payloadSafeSummary,
                payloadApprovalId: payloadApprovalId,
                payloadOperationSummarySha256: payloadOperationSummarySha256,
                payloadExpiresAtMicros: payloadExpiresAtMicros,
                payloadClarificationId: payloadClarificationId,
                payloadSafePrompt: payloadSafePrompt,
                payloadFailureStage: payloadFailureStage,
                payloadFailureCategory: payloadFailureCategory,
                payloadFailureCode: payloadFailureCode,
                payloadFailureRetryable: payloadFailureRetryable,
                payloadNativeTypeNumber: payloadNativeTypeNumber,
                envelopeSha256: envelopeSha256,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String connectionId,
                required String originDeviceId,
                required String conversationId,
                Value<String?> sessionId = const Value.absent(),
                required String requestId,
                required String sequenceText,
                required int occurredAtMicros,
                required String kind,
                Value<String?> payloadSafeMessage = const Value.absent(),
                Value<String?> payloadText = const Value.absent(),
                Value<String?> payloadRevisionText = const Value.absent(),
                Value<String?> payloadToolName = const Value.absent(),
                Value<String?> payloadToolStage = const Value.absent(),
                Value<String?> payloadSafeSummary = const Value.absent(),
                Value<String?> payloadApprovalId = const Value.absent(),
                Value<String?> payloadOperationSummarySha256 =
                    const Value.absent(),
                Value<int?> payloadExpiresAtMicros = const Value.absent(),
                Value<String?> payloadClarificationId = const Value.absent(),
                Value<String?> payloadSafePrompt = const Value.absent(),
                Value<String?> payloadFailureStage = const Value.absent(),
                Value<String?> payloadFailureCategory = const Value.absent(),
                Value<String?> payloadFailureCode = const Value.absent(),
                Value<bool?> payloadFailureRetryable = const Value.absent(),
                Value<int?> payloadNativeTypeNumber = const Value.absent(),
                required String envelopeSha256,
                Value<int> rowid = const Value.absent(),
              }) => _ClientEventsCompanion.insert(
                eventId: eventId,
                connectionId: connectionId,
                originDeviceId: originDeviceId,
                conversationId: conversationId,
                sessionId: sessionId,
                requestId: requestId,
                sequenceText: sequenceText,
                occurredAtMicros: occurredAtMicros,
                kind: kind,
                payloadSafeMessage: payloadSafeMessage,
                payloadText: payloadText,
                payloadRevisionText: payloadRevisionText,
                payloadToolName: payloadToolName,
                payloadToolStage: payloadToolStage,
                payloadSafeSummary: payloadSafeSummary,
                payloadApprovalId: payloadApprovalId,
                payloadOperationSummarySha256: payloadOperationSummarySha256,
                payloadExpiresAtMicros: payloadExpiresAtMicros,
                payloadClarificationId: payloadClarificationId,
                payloadSafePrompt: payloadSafePrompt,
                payloadFailureStage: payloadFailureStage,
                payloadFailureCategory: payloadFailureCategory,
                payloadFailureCode: payloadFailureCode,
                payloadFailureRetryable: payloadFailureRetryable,
                payloadNativeTypeNumber: payloadNativeTypeNumber,
                envelopeSha256: envelopeSha256,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$_ClientEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({requestId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (requestId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.requestId,
                                referencedTable: $$_ClientEventsTableReferences
                                    ._requestIdTable(db),
                                referencedColumn: $$_ClientEventsTableReferences
                                    ._requestIdTable(db)
                                    .requestId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$_ClientEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$_EventLedgerDatabase,
      $_ClientEventsTable,
      _StoredClientEvent,
      $$_ClientEventsTableFilterComposer,
      $$_ClientEventsTableOrderingComposer,
      $$_ClientEventsTableAnnotationComposer,
      $$_ClientEventsTableCreateCompanionBuilder,
      $$_ClientEventsTableUpdateCompanionBuilder,
      (_StoredClientEvent, $$_ClientEventsTableReferences),
      _StoredClientEvent,
      PrefetchHooks Function({bool requestId})
    >;
typedef $$_ConversationCursorsTableCreateCompanionBuilder =
    _ConversationCursorsCompanion Function({
      required String conversationId,
      required String sequenceText,
      Value<int> rowid,
    });
typedef $$_ConversationCursorsTableUpdateCompanionBuilder =
    _ConversationCursorsCompanion Function({
      Value<String> conversationId,
      Value<String> sequenceText,
      Value<int> rowid,
    });

class $$_ConversationCursorsTableFilterComposer
    extends Composer<_$_EventLedgerDatabase, $_ConversationCursorsTable> {
  $$_ConversationCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sequenceText => $composableBuilder(
    column: $table.sequenceText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$_ConversationCursorsTableOrderingComposer
    extends Composer<_$_EventLedgerDatabase, $_ConversationCursorsTable> {
  $$_ConversationCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sequenceText => $composableBuilder(
    column: $table.sequenceText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$_ConversationCursorsTableAnnotationComposer
    extends Composer<_$_EventLedgerDatabase, $_ConversationCursorsTable> {
  $$_ConversationCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sequenceText => $composableBuilder(
    column: $table.sequenceText,
    builder: (column) => column,
  );
}

class $$_ConversationCursorsTableTableManager
    extends
        RootTableManager<
          _$_EventLedgerDatabase,
          $_ConversationCursorsTable,
          _StoredConversationCursor,
          $$_ConversationCursorsTableFilterComposer,
          $$_ConversationCursorsTableOrderingComposer,
          $$_ConversationCursorsTableAnnotationComposer,
          $$_ConversationCursorsTableCreateCompanionBuilder,
          $$_ConversationCursorsTableUpdateCompanionBuilder,
          (
            _StoredConversationCursor,
            BaseReferences<
              _$_EventLedgerDatabase,
              $_ConversationCursorsTable,
              _StoredConversationCursor
            >,
          ),
          _StoredConversationCursor,
          PrefetchHooks Function()
        > {
  $$_ConversationCursorsTableTableManager(
    _$_EventLedgerDatabase db,
    $_ConversationCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_ConversationCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$_ConversationCursorsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$_ConversationCursorsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> sequenceText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _ConversationCursorsCompanion(
                conversationId: conversationId,
                sequenceText: sequenceText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String sequenceText,
                Value<int> rowid = const Value.absent(),
              }) => _ConversationCursorsCompanion.insert(
                conversationId: conversationId,
                sequenceText: sequenceText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$_ConversationCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$_EventLedgerDatabase,
      $_ConversationCursorsTable,
      _StoredConversationCursor,
      $$_ConversationCursorsTableFilterComposer,
      $$_ConversationCursorsTableOrderingComposer,
      $$_ConversationCursorsTableAnnotationComposer,
      $$_ConversationCursorsTableCreateCompanionBuilder,
      $$_ConversationCursorsTableUpdateCompanionBuilder,
      (
        _StoredConversationCursor,
        BaseReferences<
          _$_EventLedgerDatabase,
          $_ConversationCursorsTable,
          _StoredConversationCursor
        >,
      ),
      _StoredConversationCursor,
      PrefetchHooks Function()
    >;

class $_EventLedgerDatabaseManager {
  final _$_EventLedgerDatabase _db;
  $_EventLedgerDatabaseManager(this._db);
  $$_TrackedRequestsTableTableManager get trackedRequests =>
      $$_TrackedRequestsTableTableManager(_db, _db.trackedRequests);
  $$_LocalSubmissionsTableTableManager get localSubmissions =>
      $$_LocalSubmissionsTableTableManager(_db, _db.localSubmissions);
  $$_ClientEventsTableTableManager get clientEvents =>
      $$_ClientEventsTableTableManager(_db, _db.clientEvents);
  $$_ConversationCursorsTableTableManager get conversationCursors =>
      $$_ConversationCursorsTableTableManager(_db, _db.conversationCursors);
}
