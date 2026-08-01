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

abstract class _$_DirectChatDatabase extends GeneratedDatabase {
  _$_DirectChatDatabase(QueryExecutor e) : super(e);
  $_DirectChatDatabaseManager get managers => $_DirectChatDatabaseManager(this);
  late final $_DirectChatMessagesTable directChatMessages =
      $_DirectChatMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [directChatMessages];
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

class $_DirectChatDatabaseManager {
  final _$_DirectChatDatabase _db;
  $_DirectChatDatabaseManager(this._db);
  $$_DirectChatMessagesTableTableManager get directChatMessages =>
      $$_DirectChatMessagesTableTableManager(_db, _db.directChatMessages);
}
