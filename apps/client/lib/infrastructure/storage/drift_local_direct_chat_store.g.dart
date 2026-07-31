// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_local_direct_chat_store.dart';

// ignore_for_file: type=lint
class $_DirectChatMessagesTable extends _DirectChatMessages
    with TableInfo<$_DirectChatMessagesTable, _StoredDirectChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_DirectChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
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
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    providerId,
    messageId,
    role,
    content,
    createdAtMicros,
    completed,
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
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
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
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    } else if (isInserting) {
      context.missing(_completedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {providerId, messageId};
  @override
  _StoredDirectChatMessage map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredDirectChatMessage(
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
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
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
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
  final String providerId;
  final String messageId;
  final String role;
  final String content;
  final int createdAtMicros;
  final bool completed;
  const _StoredDirectChatMessage({
    required this.providerId,
    required this.messageId,
    required this.role,
    required this.content,
    required this.createdAtMicros,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['provider_id'] = Variable<String>(providerId);
    map['message_id'] = Variable<String>(messageId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  _DirectChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return _DirectChatMessagesCompanion(
      providerId: Value(providerId),
      messageId: Value(messageId),
      role: Value(role),
      content: Value(content),
      createdAtMicros: Value(createdAtMicros),
      completed: Value(completed),
    );
  }

  factory _StoredDirectChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredDirectChatMessage(
      providerId: serializer.fromJson<String>(json['providerId']),
      messageId: serializer.fromJson<String>(json['messageId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'providerId': serializer.toJson<String>(providerId),
      'messageId': serializer.toJson<String>(messageId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  _StoredDirectChatMessage copyWith({
    String? providerId,
    String? messageId,
    String? role,
    String? content,
    int? createdAtMicros,
    bool? completed,
  }) => _StoredDirectChatMessage(
    providerId: providerId ?? this.providerId,
    messageId: messageId ?? this.messageId,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    completed: completed ?? this.completed,
  );
  _StoredDirectChatMessage copyWithCompanion(
    _DirectChatMessagesCompanion data,
  ) {
    return _StoredDirectChatMessage(
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredDirectChatMessage(')
          ..write('providerId: $providerId, ')
          ..write('messageId: $messageId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    providerId,
    messageId,
    role,
    content,
    createdAtMicros,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredDirectChatMessage &&
          other.providerId == this.providerId &&
          other.messageId == this.messageId &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAtMicros == this.createdAtMicros &&
          other.completed == this.completed);
}

class _DirectChatMessagesCompanion
    extends UpdateCompanion<_StoredDirectChatMessage> {
  final Value<String> providerId;
  final Value<String> messageId;
  final Value<String> role;
  final Value<String> content;
  final Value<int> createdAtMicros;
  final Value<bool> completed;
  final Value<int> rowid;
  const _DirectChatMessagesCompanion({
    this.providerId = const Value.absent(),
    this.messageId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _DirectChatMessagesCompanion.insert({
    required String providerId,
    required String messageId,
    required String role,
    required String content,
    required int createdAtMicros,
    required bool completed,
    this.rowid = const Value.absent(),
  }) : providerId = Value(providerId),
       messageId = Value(messageId),
       role = Value(role),
       content = Value(content),
       createdAtMicros = Value(createdAtMicros),
       completed = Value(completed);
  static Insertable<_StoredDirectChatMessage> custom({
    Expression<String>? providerId,
    Expression<String>? messageId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<int>? createdAtMicros,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (providerId != null) 'provider_id': providerId,
      if (messageId != null) 'message_id': messageId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _DirectChatMessagesCompanion copyWith({
    Value<String>? providerId,
    Value<String>? messageId,
    Value<String>? role,
    Value<String>? content,
    Value<int>? createdAtMicros,
    Value<bool>? completed,
    Value<int>? rowid,
  }) {
    return _DirectChatMessagesCompanion(
      providerId: providerId ?? this.providerId,
      messageId: messageId ?? this.messageId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
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
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_DirectChatMessagesCompanion(')
          ..write('providerId: $providerId, ')
          ..write('messageId: $messageId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('completed: $completed, ')
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
      required String providerId,
      required String messageId,
      required String role,
      required String content,
      required int createdAtMicros,
      required bool completed,
      Value<int> rowid,
    });
typedef $$_DirectChatMessagesTableUpdateCompanionBuilder =
    _DirectChatMessagesCompanion Function({
      Value<String> providerId,
      Value<String> messageId,
      Value<String> role,
      Value<String> content,
      Value<int> createdAtMicros,
      Value<bool> completed,
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
  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
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

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
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
  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
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

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
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
  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
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

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);
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
                Value<String> providerId = const Value.absent(),
                Value<String> messageId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _DirectChatMessagesCompanion(
                providerId: providerId,
                messageId: messageId,
                role: role,
                content: content,
                createdAtMicros: createdAtMicros,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String providerId,
                required String messageId,
                required String role,
                required String content,
                required int createdAtMicros,
                required bool completed,
                Value<int> rowid = const Value.absent(),
              }) => _DirectChatMessagesCompanion.insert(
                providerId: providerId,
                messageId: messageId,
                role: role,
                content: content,
                createdAtMicros: createdAtMicros,
                completed: completed,
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
