// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_local_direct_chat_store.dart';

// ignore_for_file: type=lint
class $_DirectChatMessagesTable extends _DirectChatMessages
    with TableInfo<$_DirectChatMessagesTable, _StoredDirectChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_DirectChatMessagesTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMicrosMeta = const VerificationMeta(
    'createdAtMicros',
  );
  @override
  late final GeneratedColumn<int> createdAtMicros = GeneratedColumn<int>(
    'created_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _terminalMeta = const VerificationMeta(
    'terminal',
  );
  @override
  late final GeneratedColumn<String> terminal = GeneratedColumn<String>(
    'terminal',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 16,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _provenanceMeta = const VerificationMeta(
    'provenance',
  );
  @override
  late final GeneratedColumn<String> provenance = GeneratedColumn<String>(
    'provenance',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageRevisionMeta = const VerificationMeta(
    'messageRevision',
  );
  @override
  late final GeneratedColumn<int> messageRevision = GeneratedColumn<int>(
    'message_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextEligibleMeta = const VerificationMeta(
    'contextEligible',
  );
  @override
  late final GeneratedColumn<bool> contextEligible = GeneratedColumn<bool>(
    'context_eligible',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("context_eligible" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    messageId,
    role,
    content,
    createdAtMicros,
    terminal,
    provenance,
    messageRevision,
    contextEligible,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'direct_chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredDirectChatMessage> instance, {
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
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at_micros')) {
      context.handle(
        _createdAtMicrosMeta,
        createdAtMicros.isAcceptableOrUnknown(
          data['created_at_micros']!,
          _createdAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMicrosMeta);
    }
    if (data.containsKey('terminal')) {
      context.handle(
        _terminalMeta,
        terminal.isAcceptableOrUnknown(data['terminal']!, _terminalMeta),
      );
    } else if (isInserting) {
      context.missing(_terminalMeta);
    }
    if (data.containsKey('provenance')) {
      context.handle(
        _provenanceMeta,
        provenance.isAcceptableOrUnknown(data['provenance']!, _provenanceMeta),
      );
    } else if (isInserting) {
      context.missing(_provenanceMeta);
    }
    if (data.containsKey('message_revision')) {
      context.handle(
        _messageRevisionMeta,
        messageRevision.isAcceptableOrUnknown(
          data['message_revision']!,
          _messageRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageRevisionMeta);
    }
    if (data.containsKey('context_eligible')) {
      context.handle(
        _contextEligibleMeta,
        contextEligible.isAcceptableOrUnknown(
          data['context_eligible']!,
          _contextEligibleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contextEligibleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, messageId};
  @override
  _StoredDirectChatMessage map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredDirectChatMessage(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      terminal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}terminal'],
      )!,
      provenance: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provenance'],
      )!,
      messageRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_revision'],
      )!,
      contextEligible: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}context_eligible'],
      )!,
    );
  }

  @override
  $_DirectChatMessagesTable createAlias(String alias) {
    return $_DirectChatMessagesTable(attachedDatabase, alias);
  }
}

class _StoredDirectChatMessage extends DataClass
    implements Insertable<_StoredDirectChatMessage> {
  final String conversationId;
  final String messageId;
  final String role;
  final String content;
  final int createdAtMicros;
  final String terminal;
  final String provenance;
  final int messageRevision;
  final bool contextEligible;
  const _StoredDirectChatMessage({
    required this.conversationId,
    required this.messageId,
    required this.role,
    required this.content,
    required this.createdAtMicros,
    required this.terminal,
    required this.provenance,
    required this.messageRevision,
    required this.contextEligible,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['message_id'] = Variable<String>(messageId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['terminal'] = Variable<String>(terminal);
    map['provenance'] = Variable<String>(provenance);
    map['message_revision'] = Variable<int>(messageRevision);
    map['context_eligible'] = Variable<bool>(contextEligible);
    return map;
  }

  _DirectChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return _DirectChatMessagesCompanion(
      conversationId: Value(conversationId),
      messageId: Value(messageId),
      role: Value(role),
      content: Value(content),
      createdAtMicros: Value(createdAtMicros),
      terminal: Value(terminal),
      provenance: Value(provenance),
      messageRevision: Value(messageRevision),
      contextEligible: Value(contextEligible),
    );
  }

  factory _StoredDirectChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredDirectChatMessage(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      terminal: serializer.fromJson<String>(json['terminal']),
      provenance: serializer.fromJson<String>(json['provenance']),
      messageRevision: serializer.fromJson<int>(json['messageRevision']),
      contextEligible: serializer.fromJson<bool>(json['contextEligible']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'messageId': serializer.toJson<String>(messageId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'terminal': serializer.toJson<String>(terminal),
      'provenance': serializer.toJson<String>(provenance),
      'messageRevision': serializer.toJson<int>(messageRevision),
      'contextEligible': serializer.toJson<bool>(contextEligible),
    };
  }

  _StoredDirectChatMessage copyWith({
    String? conversationId,
    String? messageId,
    String? role,
    String? content,
    int? createdAtMicros,
    String? terminal,
    String? provenance,
    int? messageRevision,
    bool? contextEligible,
  }) => _StoredDirectChatMessage(
    conversationId: conversationId ?? this.conversationId,
    messageId: messageId ?? this.messageId,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    terminal: terminal ?? this.terminal,
    provenance: provenance ?? this.provenance,
    messageRevision: messageRevision ?? this.messageRevision,
    contextEligible: contextEligible ?? this.contextEligible,
  );
  _StoredDirectChatMessage copyWithCompanion(
    _DirectChatMessagesCompanion data,
  ) {
    return _StoredDirectChatMessage(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      terminal: data.terminal.present ? data.terminal.value : this.terminal,
      provenance: data.provenance.present
          ? data.provenance.value
          : this.provenance,
      messageRevision: data.messageRevision.present
          ? data.messageRevision.value
          : this.messageRevision,
      contextEligible: data.contextEligible.present
          ? data.contextEligible.value
          : this.contextEligible,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredDirectChatMessage(')
          ..write('conversationId: $conversationId, ')
          ..write('messageId: $messageId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('terminal: $terminal, ')
          ..write('provenance: $provenance, ')
          ..write('messageRevision: $messageRevision, ')
          ..write('contextEligible: $contextEligible')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversationId,
    messageId,
    role,
    content,
    createdAtMicros,
    terminal,
    provenance,
    messageRevision,
    contextEligible,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredDirectChatMessage &&
          other.conversationId == this.conversationId &&
          other.messageId == this.messageId &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAtMicros == this.createdAtMicros &&
          other.terminal == this.terminal &&
          other.provenance == this.provenance &&
          other.messageRevision == this.messageRevision &&
          other.contextEligible == this.contextEligible);
}

class _DirectChatMessagesCompanion
    extends UpdateCompanion<_StoredDirectChatMessage> {
  final Value<String> conversationId;
  final Value<String> messageId;
  final Value<String> role;
  final Value<String> content;
  final Value<int> createdAtMicros;
  final Value<String> terminal;
  final Value<String> provenance;
  final Value<int> messageRevision;
  final Value<bool> contextEligible;
  final Value<int> rowid;
  const _DirectChatMessagesCompanion({
    this.conversationId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.terminal = const Value.absent(),
    this.provenance = const Value.absent(),
    this.messageRevision = const Value.absent(),
    this.contextEligible = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _DirectChatMessagesCompanion.insert({
    required String conversationId,
    required String messageId,
    required String role,
    required String content,
    required int createdAtMicros,
    required String terminal,
    required String provenance,
    required int messageRevision,
    required bool contextEligible,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       messageId = Value(messageId),
       role = Value(role),
       content = Value(content),
       createdAtMicros = Value(createdAtMicros),
       terminal = Value(terminal),
       provenance = Value(provenance),
       messageRevision = Value(messageRevision),
       contextEligible = Value(contextEligible);
  static Insertable<_StoredDirectChatMessage> custom({
    Expression<String>? conversationId,
    Expression<String>? messageId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<int>? createdAtMicros,
    Expression<String>? terminal,
    Expression<String>? provenance,
    Expression<int>? messageRevision,
    Expression<bool>? contextEligible,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (messageId != null) 'message_id': messageId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (terminal != null) 'terminal': terminal,
      if (provenance != null) 'provenance': provenance,
      if (messageRevision != null) 'message_revision': messageRevision,
      if (contextEligible != null) 'context_eligible': contextEligible,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _DirectChatMessagesCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? messageId,
    Value<String>? role,
    Value<String>? content,
    Value<int>? createdAtMicros,
    Value<String>? terminal,
    Value<String>? provenance,
    Value<int>? messageRevision,
    Value<bool>? contextEligible,
    Value<int>? rowid,
  }) {
    return _DirectChatMessagesCompanion(
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      terminal: terminal ?? this.terminal,
      provenance: provenance ?? this.provenance,
      messageRevision: messageRevision ?? this.messageRevision,
      contextEligible: contextEligible ?? this.contextEligible,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (terminal.present) {
      map['terminal'] = Variable<String>(terminal.value);
    }
    if (provenance.present) {
      map['provenance'] = Variable<String>(provenance.value);
    }
    if (messageRevision.present) {
      map['message_revision'] = Variable<int>(messageRevision.value);
    }
    if (contextEligible.present) {
      map['context_eligible'] = Variable<bool>(contextEligible.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_DirectChatMessagesCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('messageId: $messageId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('terminal: $terminal, ')
          ..write('provenance: $provenance, ')
          ..write('messageRevision: $messageRevision, ')
          ..write('contextEligible: $contextEligible, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $_DirectContextMemoriesTable extends _DirectContextMemories
    with TableInfo<$_DirectContextMemoriesTable, _StoredDirectContextMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_DirectContextMemoriesTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoryIdMeta = const VerificationMeta(
    'memoryId',
  );
  @override
  late final GeneratedColumn<String> memoryId = GeneratedColumn<String>(
    'memory_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 8192,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoryRevisionMeta = const VerificationMeta(
    'memoryRevision',
  );
  @override
  late final GeneratedColumn<int> memoryRevision = GeneratedColumn<int>(
    'memory_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    memoryId,
    content,
    scope,
    memoryRevision,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'direct_context_memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredDirectContextMemory> instance, {
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
    if (data.containsKey('memory_id')) {
      context.handle(
        _memoryIdMeta,
        memoryId.isAcceptableOrUnknown(data['memory_id']!, _memoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memoryIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('memory_revision')) {
      context.handle(
        _memoryRevisionMeta,
        memoryRevision.isAcceptableOrUnknown(
          data['memory_revision']!,
          _memoryRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memoryRevisionMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId, memoryId};
  @override
  _StoredDirectContextMemory map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredDirectContextMemory(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      memoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memory_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      memoryRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}memory_revision'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $_DirectContextMemoriesTable createAlias(String alias) {
    return $_DirectContextMemoriesTable(attachedDatabase, alias);
  }
}

class _StoredDirectContextMemory extends DataClass
    implements Insertable<_StoredDirectContextMemory> {
  final String conversationId;
  final String memoryId;
  final String content;
  final String scope;
  final int memoryRevision;
  final int updatedAtMicros;
  const _StoredDirectContextMemory({
    required this.conversationId,
    required this.memoryId,
    required this.content,
    required this.scope,
    required this.memoryRevision,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['memory_id'] = Variable<String>(memoryId);
    map['content'] = Variable<String>(content);
    map['scope'] = Variable<String>(scope);
    map['memory_revision'] = Variable<int>(memoryRevision);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  _DirectContextMemoriesCompanion toCompanion(bool nullToAbsent) {
    return _DirectContextMemoriesCompanion(
      conversationId: Value(conversationId),
      memoryId: Value(memoryId),
      content: Value(content),
      scope: Value(scope),
      memoryRevision: Value(memoryRevision),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory _StoredDirectContextMemory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredDirectContextMemory(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      memoryId: serializer.fromJson<String>(json['memoryId']),
      content: serializer.fromJson<String>(json['content']),
      scope: serializer.fromJson<String>(json['scope']),
      memoryRevision: serializer.fromJson<int>(json['memoryRevision']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'memoryId': serializer.toJson<String>(memoryId),
      'content': serializer.toJson<String>(content),
      'scope': serializer.toJson<String>(scope),
      'memoryRevision': serializer.toJson<int>(memoryRevision),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  _StoredDirectContextMemory copyWith({
    String? conversationId,
    String? memoryId,
    String? content,
    String? scope,
    int? memoryRevision,
    int? updatedAtMicros,
  }) => _StoredDirectContextMemory(
    conversationId: conversationId ?? this.conversationId,
    memoryId: memoryId ?? this.memoryId,
    content: content ?? this.content,
    scope: scope ?? this.scope,
    memoryRevision: memoryRevision ?? this.memoryRevision,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  _StoredDirectContextMemory copyWithCompanion(
    _DirectContextMemoriesCompanion data,
  ) {
    return _StoredDirectContextMemory(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      memoryId: data.memoryId.present ? data.memoryId.value : this.memoryId,
      content: data.content.present ? data.content.value : this.content,
      scope: data.scope.present ? data.scope.value : this.scope,
      memoryRevision: data.memoryRevision.present
          ? data.memoryRevision.value
          : this.memoryRevision,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredDirectContextMemory(')
          ..write('conversationId: $conversationId, ')
          ..write('memoryId: $memoryId, ')
          ..write('content: $content, ')
          ..write('scope: $scope, ')
          ..write('memoryRevision: $memoryRevision, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversationId,
    memoryId,
    content,
    scope,
    memoryRevision,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredDirectContextMemory &&
          other.conversationId == this.conversationId &&
          other.memoryId == this.memoryId &&
          other.content == this.content &&
          other.scope == this.scope &&
          other.memoryRevision == this.memoryRevision &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class _DirectContextMemoriesCompanion
    extends UpdateCompanion<_StoredDirectContextMemory> {
  final Value<String> conversationId;
  final Value<String> memoryId;
  final Value<String> content;
  final Value<String> scope;
  final Value<int> memoryRevision;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const _DirectContextMemoriesCompanion({
    this.conversationId = const Value.absent(),
    this.memoryId = const Value.absent(),
    this.content = const Value.absent(),
    this.scope = const Value.absent(),
    this.memoryRevision = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _DirectContextMemoriesCompanion.insert({
    required String conversationId,
    required String memoryId,
    required String content,
    required String scope,
    required int memoryRevision,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       memoryId = Value(memoryId),
       content = Value(content),
       scope = Value(scope),
       memoryRevision = Value(memoryRevision),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<_StoredDirectContextMemory> custom({
    Expression<String>? conversationId,
    Expression<String>? memoryId,
    Expression<String>? content,
    Expression<String>? scope,
    Expression<int>? memoryRevision,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (memoryId != null) 'memory_id': memoryId,
      if (content != null) 'content': content,
      if (scope != null) 'scope': scope,
      if (memoryRevision != null) 'memory_revision': memoryRevision,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _DirectContextMemoriesCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? memoryId,
    Value<String>? content,
    Value<String>? scope,
    Value<int>? memoryRevision,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return _DirectContextMemoriesCompanion(
      conversationId: conversationId ?? this.conversationId,
      memoryId: memoryId ?? this.memoryId,
      content: content ?? this.content,
      scope: scope ?? this.scope,
      memoryRevision: memoryRevision ?? this.memoryRevision,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (memoryId.present) {
      map['memory_id'] = Variable<String>(memoryId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (memoryRevision.present) {
      map['memory_revision'] = Variable<int>(memoryRevision.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_DirectContextMemoriesCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('memoryId: $memoryId, ')
          ..write('content: $content, ')
          ..write('scope: $scope, ')
          ..write('memoryRevision: $memoryRevision, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $_DirectContextSummariesTable extends _DirectContextSummaries
    with TableInfo<$_DirectContextSummariesTable, _StoredDirectContextSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_DirectContextSummariesTable(this.attachedDatabase, [this._alias]);
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
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryIdMeta = const VerificationMeta(
    'summaryId',
  );
  @override
  late final GeneratedColumn<String> summaryId = GeneratedColumn<String>(
    'summary_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32768,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstMessageIdMeta = const VerificationMeta(
    'firstMessageId',
  );
  @override
  late final GeneratedColumn<String> firstMessageId = GeneratedColumn<String>(
    'first_message_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMessageIdMeta = const VerificationMeta(
    'lastMessageId',
  );
  @override
  late final GeneratedColumn<String> lastMessageId = GeneratedColumn<String>(
    'last_message_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerProfileIdMeta = const VerificationMeta(
    'providerProfileId',
  );
  @override
  late final GeneratedColumn<String> providerProfileId =
      GeneratedColumn<String>(
        'provider_profile_id',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 1,
          maxTextLength: 128,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _configurationRevisionMeta =
      const VerificationMeta('configurationRevision');
  @override
  late final GeneratedColumn<int> configurationRevision = GeneratedColumn<int>(
    'configuration_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    conversationId,
    summaryId,
    content,
    firstMessageId,
    lastMessageId,
    providerProfileId,
    configurationRevision,
    updatedAtMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'direct_context_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredDirectContextSummary> instance, {
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
    if (data.containsKey('summary_id')) {
      context.handle(
        _summaryIdMeta,
        summaryId.isAcceptableOrUnknown(data['summary_id']!, _summaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_summaryIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('first_message_id')) {
      context.handle(
        _firstMessageIdMeta,
        firstMessageId.isAcceptableOrUnknown(
          data['first_message_id']!,
          _firstMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstMessageIdMeta);
    }
    if (data.containsKey('last_message_id')) {
      context.handle(
        _lastMessageIdMeta,
        lastMessageId.isAcceptableOrUnknown(
          data['last_message_id']!,
          _lastMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMessageIdMeta);
    }
    if (data.containsKey('provider_profile_id')) {
      context.handle(
        _providerProfileIdMeta,
        providerProfileId.isAcceptableOrUnknown(
          data['provider_profile_id']!,
          _providerProfileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerProfileIdMeta);
    }
    if (data.containsKey('configuration_revision')) {
      context.handle(
        _configurationRevisionMeta,
        configurationRevision.isAcceptableOrUnknown(
          data['configuration_revision']!,
          _configurationRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configurationRevisionMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId};
  @override
  _StoredDirectContextSummary map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredDirectContextSummary(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      summaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      firstMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_message_id'],
      )!,
      lastMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_id'],
      )!,
      providerProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_profile_id'],
      )!,
      configurationRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}configuration_revision'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
    );
  }

  @override
  $_DirectContextSummariesTable createAlias(String alias) {
    return $_DirectContextSummariesTable(attachedDatabase, alias);
  }
}

class _StoredDirectContextSummary extends DataClass
    implements Insertable<_StoredDirectContextSummary> {
  final String conversationId;
  final String summaryId;
  final String content;
  final String firstMessageId;
  final String lastMessageId;
  final String providerProfileId;
  final int configurationRevision;
  final int updatedAtMicros;
  const _StoredDirectContextSummary({
    required this.conversationId,
    required this.summaryId,
    required this.content,
    required this.firstMessageId,
    required this.lastMessageId,
    required this.providerProfileId,
    required this.configurationRevision,
    required this.updatedAtMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['summary_id'] = Variable<String>(summaryId);
    map['content'] = Variable<String>(content);
    map['first_message_id'] = Variable<String>(firstMessageId);
    map['last_message_id'] = Variable<String>(lastMessageId);
    map['provider_profile_id'] = Variable<String>(providerProfileId);
    map['configuration_revision'] = Variable<int>(configurationRevision);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    return map;
  }

  _DirectContextSummariesCompanion toCompanion(bool nullToAbsent) {
    return _DirectContextSummariesCompanion(
      conversationId: Value(conversationId),
      summaryId: Value(summaryId),
      content: Value(content),
      firstMessageId: Value(firstMessageId),
      lastMessageId: Value(lastMessageId),
      providerProfileId: Value(providerProfileId),
      configurationRevision: Value(configurationRevision),
      updatedAtMicros: Value(updatedAtMicros),
    );
  }

  factory _StoredDirectContextSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredDirectContextSummary(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      summaryId: serializer.fromJson<String>(json['summaryId']),
      content: serializer.fromJson<String>(json['content']),
      firstMessageId: serializer.fromJson<String>(json['firstMessageId']),
      lastMessageId: serializer.fromJson<String>(json['lastMessageId']),
      providerProfileId: serializer.fromJson<String>(json['providerProfileId']),
      configurationRevision: serializer.fromJson<int>(
        json['configurationRevision'],
      ),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'summaryId': serializer.toJson<String>(summaryId),
      'content': serializer.toJson<String>(content),
      'firstMessageId': serializer.toJson<String>(firstMessageId),
      'lastMessageId': serializer.toJson<String>(lastMessageId),
      'providerProfileId': serializer.toJson<String>(providerProfileId),
      'configurationRevision': serializer.toJson<int>(configurationRevision),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
    };
  }

  _StoredDirectContextSummary copyWith({
    String? conversationId,
    String? summaryId,
    String? content,
    String? firstMessageId,
    String? lastMessageId,
    String? providerProfileId,
    int? configurationRevision,
    int? updatedAtMicros,
  }) => _StoredDirectContextSummary(
    conversationId: conversationId ?? this.conversationId,
    summaryId: summaryId ?? this.summaryId,
    content: content ?? this.content,
    firstMessageId: firstMessageId ?? this.firstMessageId,
    lastMessageId: lastMessageId ?? this.lastMessageId,
    providerProfileId: providerProfileId ?? this.providerProfileId,
    configurationRevision: configurationRevision ?? this.configurationRevision,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
  );
  _StoredDirectContextSummary copyWithCompanion(
    _DirectContextSummariesCompanion data,
  ) {
    return _StoredDirectContextSummary(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      summaryId: data.summaryId.present ? data.summaryId.value : this.summaryId,
      content: data.content.present ? data.content.value : this.content,
      firstMessageId: data.firstMessageId.present
          ? data.firstMessageId.value
          : this.firstMessageId,
      lastMessageId: data.lastMessageId.present
          ? data.lastMessageId.value
          : this.lastMessageId,
      providerProfileId: data.providerProfileId.present
          ? data.providerProfileId.value
          : this.providerProfileId,
      configurationRevision: data.configurationRevision.present
          ? data.configurationRevision.value
          : this.configurationRevision,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredDirectContextSummary(')
          ..write('conversationId: $conversationId, ')
          ..write('summaryId: $summaryId, ')
          ..write('content: $content, ')
          ..write('firstMessageId: $firstMessageId, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('providerProfileId: $providerProfileId, ')
          ..write('configurationRevision: $configurationRevision, ')
          ..write('updatedAtMicros: $updatedAtMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    conversationId,
    summaryId,
    content,
    firstMessageId,
    lastMessageId,
    providerProfileId,
    configurationRevision,
    updatedAtMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredDirectContextSummary &&
          other.conversationId == this.conversationId &&
          other.summaryId == this.summaryId &&
          other.content == this.content &&
          other.firstMessageId == this.firstMessageId &&
          other.lastMessageId == this.lastMessageId &&
          other.providerProfileId == this.providerProfileId &&
          other.configurationRevision == this.configurationRevision &&
          other.updatedAtMicros == this.updatedAtMicros);
}

class _DirectContextSummariesCompanion
    extends UpdateCompanion<_StoredDirectContextSummary> {
  final Value<String> conversationId;
  final Value<String> summaryId;
  final Value<String> content;
  final Value<String> firstMessageId;
  final Value<String> lastMessageId;
  final Value<String> providerProfileId;
  final Value<int> configurationRevision;
  final Value<int> updatedAtMicros;
  final Value<int> rowid;
  const _DirectContextSummariesCompanion({
    this.conversationId = const Value.absent(),
    this.summaryId = const Value.absent(),
    this.content = const Value.absent(),
    this.firstMessageId = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.providerProfileId = const Value.absent(),
    this.configurationRevision = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _DirectContextSummariesCompanion.insert({
    required String conversationId,
    required String summaryId,
    required String content,
    required String firstMessageId,
    required String lastMessageId,
    required String providerProfileId,
    required int configurationRevision,
    required int updatedAtMicros,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       summaryId = Value(summaryId),
       content = Value(content),
       firstMessageId = Value(firstMessageId),
       lastMessageId = Value(lastMessageId),
       providerProfileId = Value(providerProfileId),
       configurationRevision = Value(configurationRevision),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<_StoredDirectContextSummary> custom({
    Expression<String>? conversationId,
    Expression<String>? summaryId,
    Expression<String>? content,
    Expression<String>? firstMessageId,
    Expression<String>? lastMessageId,
    Expression<String>? providerProfileId,
    Expression<int>? configurationRevision,
    Expression<int>? updatedAtMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (summaryId != null) 'summary_id': summaryId,
      if (content != null) 'content': content,
      if (firstMessageId != null) 'first_message_id': firstMessageId,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (providerProfileId != null) 'provider_profile_id': providerProfileId,
      if (configurationRevision != null)
        'configuration_revision': configurationRevision,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _DirectContextSummariesCompanion copyWith({
    Value<String>? conversationId,
    Value<String>? summaryId,
    Value<String>? content,
    Value<String>? firstMessageId,
    Value<String>? lastMessageId,
    Value<String>? providerProfileId,
    Value<int>? configurationRevision,
    Value<int>? updatedAtMicros,
    Value<int>? rowid,
  }) {
    return _DirectContextSummariesCompanion(
      conversationId: conversationId ?? this.conversationId,
      summaryId: summaryId ?? this.summaryId,
      content: content ?? this.content,
      firstMessageId: firstMessageId ?? this.firstMessageId,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      providerProfileId: providerProfileId ?? this.providerProfileId,
      configurationRevision:
          configurationRevision ?? this.configurationRevision,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (summaryId.present) {
      map['summary_id'] = Variable<String>(summaryId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (firstMessageId.present) {
      map['first_message_id'] = Variable<String>(firstMessageId.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<String>(lastMessageId.value);
    }
    if (providerProfileId.present) {
      map['provider_profile_id'] = Variable<String>(providerProfileId.value);
    }
    if (configurationRevision.present) {
      map['configuration_revision'] = Variable<int>(
        configurationRevision.value,
      );
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_DirectContextSummariesCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('summaryId: $summaryId, ')
          ..write('content: $content, ')
          ..write('firstMessageId: $firstMessageId, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('providerProfileId: $providerProfileId, ')
          ..write('configurationRevision: $configurationRevision, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_DirectChatDatabase extends GeneratedDatabase {
  _$_DirectChatDatabase(QueryExecutor e) : super(e);
  $_DirectChatDatabaseManager get managers => $_DirectChatDatabaseManager(this);
  late final $_DirectChatMessagesTable directChatMessages =
      $_DirectChatMessagesTable(this);
  late final $_DirectContextMemoriesTable directContextMemories =
      $_DirectContextMemoriesTable(this);
  late final $_DirectContextSummariesTable directContextSummaries =
      $_DirectContextSummariesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    directChatMessages,
    directContextMemories,
    directContextSummaries,
  ];
}

typedef $$_DirectChatMessagesTableCreateCompanionBuilder =
    _DirectChatMessagesCompanion Function({
      required String conversationId,
      required String messageId,
      required String role,
      required String content,
      required int createdAtMicros,
      required String terminal,
      required String provenance,
      required int messageRevision,
      required bool contextEligible,
      Value<int> rowid,
    });
typedef $$_DirectChatMessagesTableUpdateCompanionBuilder =
    _DirectChatMessagesCompanion Function({
      Value<String> conversationId,
      Value<String> messageId,
      Value<String> role,
      Value<String> content,
      Value<int> createdAtMicros,
      Value<String> terminal,
      Value<String> provenance,
      Value<int> messageRevision,
      Value<bool> contextEligible,
      Value<int> rowid,
    });

class $$_DirectChatMessagesTableFilterComposer
    extends Composer<_$_DirectChatDatabase, $_DirectChatMessagesTable> {
  $$_DirectChatMessagesTableFilterComposer({
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

  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get terminal => $composableBuilder(
    column: $table.terminal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageRevision => $composableBuilder(
    column: $table.messageRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get contextEligible => $composableBuilder(
    column: $table.contextEligible,
    builder: (column) => ColumnFilters(column),
  );
}

class $$_DirectChatMessagesTableOrderingComposer
    extends Composer<_$_DirectChatDatabase, $_DirectChatMessagesTable> {
  $$_DirectChatMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get terminal => $composableBuilder(
    column: $table.terminal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageRevision => $composableBuilder(
    column: $table.messageRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get contextEligible => $composableBuilder(
    column: $table.contextEligible,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$_DirectChatMessagesTableAnnotationComposer
    extends Composer<_$_DirectChatDatabase, $_DirectChatMessagesTable> {
  $$_DirectChatMessagesTableAnnotationComposer({
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

  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get terminal =>
      $composableBuilder(column: $table.terminal, builder: (column) => column);

  GeneratedColumn<String> get provenance => $composableBuilder(
    column: $table.provenance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messageRevision => $composableBuilder(
    column: $table.messageRevision,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get contextEligible => $composableBuilder(
    column: $table.contextEligible,
    builder: (column) => column,
  );
}

class $$_DirectChatMessagesTableTableManager
    extends
        RootTableManager<
          _$_DirectChatDatabase,
          $_DirectChatMessagesTable,
          _StoredDirectChatMessage,
          $$_DirectChatMessagesTableFilterComposer,
          $$_DirectChatMessagesTableOrderingComposer,
          $$_DirectChatMessagesTableAnnotationComposer,
          $$_DirectChatMessagesTableCreateCompanionBuilder,
          $$_DirectChatMessagesTableUpdateCompanionBuilder,
          (
            _StoredDirectChatMessage,
            BaseReferences<
              _$_DirectChatDatabase,
              $_DirectChatMessagesTable,
              _StoredDirectChatMessage
            >,
          ),
          _StoredDirectChatMessage,
          PrefetchHooks Function()
        > {
  $$_DirectChatMessagesTableTableManager(
    _$_DirectChatDatabase db,
    $_DirectChatMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_DirectChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$_DirectChatMessagesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$_DirectChatMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<String> terminal = const Value.absent(),
                Value<String> provenance = const Value.absent(),
                Value<int> messageRevision = const Value.absent(),
                Value<bool> contextEligible = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _DirectChatMessagesCompanion(
                conversationId: conversationId,
                messageId: messageId,
                role: role,
                content: content,
                createdAtMicros: createdAtMicros,
                terminal: terminal,
                provenance: provenance,
                messageRevision: messageRevision,
                contextEligible: contextEligible,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String messageId,
                required String role,
                required String content,
                required int createdAtMicros,
                required String terminal,
                required String provenance,
                required int messageRevision,
                required bool contextEligible,
                Value<int> rowid = const Value.absent(),
              }) => _DirectChatMessagesCompanion.insert(
                conversationId: conversationId,
                messageId: messageId,
                role: role,
                content: content,
                createdAtMicros: createdAtMicros,
                terminal: terminal,
                provenance: provenance,
                messageRevision: messageRevision,
                contextEligible: contextEligible,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$_DirectChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$_DirectChatDatabase,
      $_DirectChatMessagesTable,
      _StoredDirectChatMessage,
      $$_DirectChatMessagesTableFilterComposer,
      $$_DirectChatMessagesTableOrderingComposer,
      $$_DirectChatMessagesTableAnnotationComposer,
      $$_DirectChatMessagesTableCreateCompanionBuilder,
      $$_DirectChatMessagesTableUpdateCompanionBuilder,
      (
        _StoredDirectChatMessage,
        BaseReferences<
          _$_DirectChatDatabase,
          $_DirectChatMessagesTable,
          _StoredDirectChatMessage
        >,
      ),
      _StoredDirectChatMessage,
      PrefetchHooks Function()
    >;
typedef $$_DirectContextMemoriesTableCreateCompanionBuilder =
    _DirectContextMemoriesCompanion Function({
      required String conversationId,
      required String memoryId,
      required String content,
      required String scope,
      required int memoryRevision,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$_DirectContextMemoriesTableUpdateCompanionBuilder =
    _DirectContextMemoriesCompanion Function({
      Value<String> conversationId,
      Value<String> memoryId,
      Value<String> content,
      Value<String> scope,
      Value<int> memoryRevision,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

class $$_DirectContextMemoriesTableFilterComposer
    extends Composer<_$_DirectChatDatabase, $_DirectContextMemoriesTable> {
  $$_DirectContextMemoriesTableFilterComposer({
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

  ColumnFilters<String> get memoryId => $composableBuilder(
    column: $table.memoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memoryRevision => $composableBuilder(
    column: $table.memoryRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );
}

class $$_DirectContextMemoriesTableOrderingComposer
    extends Composer<_$_DirectChatDatabase, $_DirectContextMemoriesTable> {
  $$_DirectContextMemoriesTableOrderingComposer({
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

  ColumnOrderings<String> get memoryId => $composableBuilder(
    column: $table.memoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memoryRevision => $composableBuilder(
    column: $table.memoryRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$_DirectContextMemoriesTableAnnotationComposer
    extends Composer<_$_DirectChatDatabase, $_DirectContextMemoriesTable> {
  $$_DirectContextMemoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get memoryId =>
      $composableBuilder(column: $table.memoryId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get memoryRevision => $composableBuilder(
    column: $table.memoryRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );
}

class $$_DirectContextMemoriesTableTableManager
    extends
        RootTableManager<
          _$_DirectChatDatabase,
          $_DirectContextMemoriesTable,
          _StoredDirectContextMemory,
          $$_DirectContextMemoriesTableFilterComposer,
          $$_DirectContextMemoriesTableOrderingComposer,
          $$_DirectContextMemoriesTableAnnotationComposer,
          $$_DirectContextMemoriesTableCreateCompanionBuilder,
          $$_DirectContextMemoriesTableUpdateCompanionBuilder,
          (
            _StoredDirectContextMemory,
            BaseReferences<
              _$_DirectChatDatabase,
              $_DirectContextMemoriesTable,
              _StoredDirectContextMemory
            >,
          ),
          _StoredDirectContextMemory,
          PrefetchHooks Function()
        > {
  $$_DirectContextMemoriesTableTableManager(
    _$_DirectChatDatabase db,
    $_DirectContextMemoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_DirectContextMemoriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$_DirectContextMemoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$_DirectContextMemoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> memoryId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<int> memoryRevision = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _DirectContextMemoriesCompanion(
                conversationId: conversationId,
                memoryId: memoryId,
                content: content,
                scope: scope,
                memoryRevision: memoryRevision,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String memoryId,
                required String content,
                required String scope,
                required int memoryRevision,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => _DirectContextMemoriesCompanion.insert(
                conversationId: conversationId,
                memoryId: memoryId,
                content: content,
                scope: scope,
                memoryRevision: memoryRevision,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$_DirectContextMemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$_DirectChatDatabase,
      $_DirectContextMemoriesTable,
      _StoredDirectContextMemory,
      $$_DirectContextMemoriesTableFilterComposer,
      $$_DirectContextMemoriesTableOrderingComposer,
      $$_DirectContextMemoriesTableAnnotationComposer,
      $$_DirectContextMemoriesTableCreateCompanionBuilder,
      $$_DirectContextMemoriesTableUpdateCompanionBuilder,
      (
        _StoredDirectContextMemory,
        BaseReferences<
          _$_DirectChatDatabase,
          $_DirectContextMemoriesTable,
          _StoredDirectContextMemory
        >,
      ),
      _StoredDirectContextMemory,
      PrefetchHooks Function()
    >;
typedef $$_DirectContextSummariesTableCreateCompanionBuilder =
    _DirectContextSummariesCompanion Function({
      required String conversationId,
      required String summaryId,
      required String content,
      required String firstMessageId,
      required String lastMessageId,
      required String providerProfileId,
      required int configurationRevision,
      required int updatedAtMicros,
      Value<int> rowid,
    });
typedef $$_DirectContextSummariesTableUpdateCompanionBuilder =
    _DirectContextSummariesCompanion Function({
      Value<String> conversationId,
      Value<String> summaryId,
      Value<String> content,
      Value<String> firstMessageId,
      Value<String> lastMessageId,
      Value<String> providerProfileId,
      Value<int> configurationRevision,
      Value<int> updatedAtMicros,
      Value<int> rowid,
    });

class $$_DirectContextSummariesTableFilterComposer
    extends Composer<_$_DirectChatDatabase, $_DirectContextSummariesTable> {
  $$_DirectContextSummariesTableFilterComposer({
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

  ColumnFilters<String> get summaryId => $composableBuilder(
    column: $table.summaryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstMessageId => $composableBuilder(
    column: $table.firstMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerProfileId => $composableBuilder(
    column: $table.providerProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get configurationRevision => $composableBuilder(
    column: $table.configurationRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );
}

class $$_DirectContextSummariesTableOrderingComposer
    extends Composer<_$_DirectChatDatabase, $_DirectContextSummariesTable> {
  $$_DirectContextSummariesTableOrderingComposer({
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

  ColumnOrderings<String> get summaryId => $composableBuilder(
    column: $table.summaryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstMessageId => $composableBuilder(
    column: $table.firstMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerProfileId => $composableBuilder(
    column: $table.providerProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get configurationRevision => $composableBuilder(
    column: $table.configurationRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$_DirectContextSummariesTableAnnotationComposer
    extends Composer<_$_DirectChatDatabase, $_DirectContextSummariesTable> {
  $$_DirectContextSummariesTableAnnotationComposer({
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

  GeneratedColumn<String> get summaryId =>
      $composableBuilder(column: $table.summaryId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get firstMessageId => $composableBuilder(
    column: $table.firstMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerProfileId => $composableBuilder(
    column: $table.providerProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get configurationRevision => $composableBuilder(
    column: $table.configurationRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );
}

class $$_DirectContextSummariesTableTableManager
    extends
        RootTableManager<
          _$_DirectChatDatabase,
          $_DirectContextSummariesTable,
          _StoredDirectContextSummary,
          $$_DirectContextSummariesTableFilterComposer,
          $$_DirectContextSummariesTableOrderingComposer,
          $$_DirectContextSummariesTableAnnotationComposer,
          $$_DirectContextSummariesTableCreateCompanionBuilder,
          $$_DirectContextSummariesTableUpdateCompanionBuilder,
          (
            _StoredDirectContextSummary,
            BaseReferences<
              _$_DirectChatDatabase,
              $_DirectContextSummariesTable,
              _StoredDirectContextSummary
            >,
          ),
          _StoredDirectContextSummary,
          PrefetchHooks Function()
        > {
  $$_DirectContextSummariesTableTableManager(
    _$_DirectChatDatabase db,
    $_DirectContextSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_DirectContextSummariesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$_DirectContextSummariesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$_DirectContextSummariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<String> summaryId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> firstMessageId = const Value.absent(),
                Value<String> lastMessageId = const Value.absent(),
                Value<String> providerProfileId = const Value.absent(),
                Value<int> configurationRevision = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _DirectContextSummariesCompanion(
                conversationId: conversationId,
                summaryId: summaryId,
                content: content,
                firstMessageId: firstMessageId,
                lastMessageId: lastMessageId,
                providerProfileId: providerProfileId,
                configurationRevision: configurationRevision,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required String summaryId,
                required String content,
                required String firstMessageId,
                required String lastMessageId,
                required String providerProfileId,
                required int configurationRevision,
                required int updatedAtMicros,
                Value<int> rowid = const Value.absent(),
              }) => _DirectContextSummariesCompanion.insert(
                conversationId: conversationId,
                summaryId: summaryId,
                content: content,
                firstMessageId: firstMessageId,
                lastMessageId: lastMessageId,
                providerProfileId: providerProfileId,
                configurationRevision: configurationRevision,
                updatedAtMicros: updatedAtMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$_DirectContextSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$_DirectChatDatabase,
      $_DirectContextSummariesTable,
      _StoredDirectContextSummary,
      $$_DirectContextSummariesTableFilterComposer,
      $$_DirectContextSummariesTableOrderingComposer,
      $$_DirectContextSummariesTableAnnotationComposer,
      $$_DirectContextSummariesTableCreateCompanionBuilder,
      $$_DirectContextSummariesTableUpdateCompanionBuilder,
      (
        _StoredDirectContextSummary,
        BaseReferences<
          _$_DirectChatDatabase,
          $_DirectContextSummariesTable,
          _StoredDirectContextSummary
        >,
      ),
      _StoredDirectContextSummary,
      PrefetchHooks Function()
    >;

class $_DirectChatDatabaseManager {
  final _$_DirectChatDatabase _db;
  $_DirectChatDatabaseManager(this._db);
  $$_DirectChatMessagesTableTableManager get directChatMessages =>
      $$_DirectChatMessagesTableTableManager(_db, _db.directChatMessages);
  $$_DirectContextMemoriesTableTableManager get directContextMemories =>
      $$_DirectContextMemoriesTableTableManager(_db, _db.directContextMemories);
  $$_DirectContextSummariesTableTableManager get directContextSummaries =>
      $$_DirectContextSummariesTableTableManager(
        _db,
        _db.directContextSummaries,
      );
}
