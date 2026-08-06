// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_local_transcript_store.dart';

// ignore_for_file: type=lint
class $_LocalTranscriptsTable extends _LocalTranscripts
    with TableInfo<$_LocalTranscriptsTable, _StoredLocalTranscript> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $_LocalTranscriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transcriptIdMeta = const VerificationMeta(
    'transcriptId',
  );
  @override
  late final GeneratedColumn<String> transcriptId = GeneratedColumn<String>(
    'transcript_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 256,
    ),
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
  static const VerificationMeta _originalTextMeta = const VerificationMeta(
    'originalText',
  );
  @override
  late final GeneratedColumn<String> originalText = GeneratedColumn<String>(
    'original_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _audioDurationMicrosMeta =
      const VerificationMeta('audioDurationMicros');
  @override
  late final GeneratedColumn<int> audioDurationMicros = GeneratedColumn<int>(
    'audio_duration_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transcriptionDurationMicrosMeta =
      const VerificationMeta('transcriptionDurationMicros');
  @override
  late final GeneratedColumn<int> transcriptionDurationMicros =
      GeneratedColumn<int>(
        'transcription_duration_micros',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    transcriptId,
    createdAtMicros,
    originalText,
    provider,
    audioDurationMicros,
    transcriptionDurationMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_stt_transcripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<_StoredLocalTranscript> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transcript_id')) {
      context.handle(
        _transcriptIdMeta,
        transcriptId.isAcceptableOrUnknown(
          data['transcript_id']!,
          _transcriptIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptIdMeta);
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
    if (data.containsKey('original_text')) {
      context.handle(
        _originalTextMeta,
        originalText.isAcceptableOrUnknown(
          data['original_text']!,
          _originalTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalTextMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('audio_duration_micros')) {
      context.handle(
        _audioDurationMicrosMeta,
        audioDurationMicros.isAcceptableOrUnknown(
          data['audio_duration_micros']!,
          _audioDurationMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_audioDurationMicrosMeta);
    }
    if (data.containsKey('transcription_duration_micros')) {
      context.handle(
        _transcriptionDurationMicrosMeta,
        transcriptionDurationMicros.isAcceptableOrUnknown(
          data['transcription_duration_micros']!,
          _transcriptionDurationMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transcriptionDurationMicrosMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transcriptId};
  @override
  _StoredLocalTranscript map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return _StoredLocalTranscript(
      transcriptId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript_id'],
      )!,
      createdAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_micros'],
      )!,
      originalText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_text'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      audioDurationMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_duration_micros'],
      )!,
      transcriptionDurationMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transcription_duration_micros'],
      )!,
    );
  }

  @override
  $_LocalTranscriptsTable createAlias(String alias) {
    return $_LocalTranscriptsTable(attachedDatabase, alias);
  }
}

class _StoredLocalTranscript extends DataClass
    implements Insertable<_StoredLocalTranscript> {
  final String transcriptId;
  final int createdAtMicros;
  final String originalText;
  final String provider;
  final int audioDurationMicros;
  final int transcriptionDurationMicros;
  const _StoredLocalTranscript({
    required this.transcriptId,
    required this.createdAtMicros,
    required this.originalText,
    required this.provider,
    required this.audioDurationMicros,
    required this.transcriptionDurationMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transcript_id'] = Variable<String>(transcriptId);
    map['created_at_micros'] = Variable<int>(createdAtMicros);
    map['original_text'] = Variable<String>(originalText);
    map['provider'] = Variable<String>(provider);
    map['audio_duration_micros'] = Variable<int>(audioDurationMicros);
    map['transcription_duration_micros'] = Variable<int>(
      transcriptionDurationMicros,
    );
    return map;
  }

  _LocalTranscriptsCompanion toCompanion(bool nullToAbsent) {
    return _LocalTranscriptsCompanion(
      transcriptId: Value(transcriptId),
      createdAtMicros: Value(createdAtMicros),
      originalText: Value(originalText),
      provider: Value(provider),
      audioDurationMicros: Value(audioDurationMicros),
      transcriptionDurationMicros: Value(transcriptionDurationMicros),
    );
  }

  factory _StoredLocalTranscript.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return _StoredLocalTranscript(
      transcriptId: serializer.fromJson<String>(json['transcriptId']),
      createdAtMicros: serializer.fromJson<int>(json['createdAtMicros']),
      originalText: serializer.fromJson<String>(json['originalText']),
      provider: serializer.fromJson<String>(json['provider']),
      audioDurationMicros: serializer.fromJson<int>(
        json['audioDurationMicros'],
      ),
      transcriptionDurationMicros: serializer.fromJson<int>(
        json['transcriptionDurationMicros'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transcriptId': serializer.toJson<String>(transcriptId),
      'createdAtMicros': serializer.toJson<int>(createdAtMicros),
      'originalText': serializer.toJson<String>(originalText),
      'provider': serializer.toJson<String>(provider),
      'audioDurationMicros': serializer.toJson<int>(audioDurationMicros),
      'transcriptionDurationMicros': serializer.toJson<int>(
        transcriptionDurationMicros,
      ),
    };
  }

  _StoredLocalTranscript copyWith({
    String? transcriptId,
    int? createdAtMicros,
    String? originalText,
    String? provider,
    int? audioDurationMicros,
    int? transcriptionDurationMicros,
  }) => _StoredLocalTranscript(
    transcriptId: transcriptId ?? this.transcriptId,
    createdAtMicros: createdAtMicros ?? this.createdAtMicros,
    originalText: originalText ?? this.originalText,
    provider: provider ?? this.provider,
    audioDurationMicros: audioDurationMicros ?? this.audioDurationMicros,
    transcriptionDurationMicros:
        transcriptionDurationMicros ?? this.transcriptionDurationMicros,
  );
  _StoredLocalTranscript copyWithCompanion(_LocalTranscriptsCompanion data) {
    return _StoredLocalTranscript(
      transcriptId: data.transcriptId.present
          ? data.transcriptId.value
          : this.transcriptId,
      createdAtMicros: data.createdAtMicros.present
          ? data.createdAtMicros.value
          : this.createdAtMicros,
      originalText: data.originalText.present
          ? data.originalText.value
          : this.originalText,
      provider: data.provider.present ? data.provider.value : this.provider,
      audioDurationMicros: data.audioDurationMicros.present
          ? data.audioDurationMicros.value
          : this.audioDurationMicros,
      transcriptionDurationMicros: data.transcriptionDurationMicros.present
          ? data.transcriptionDurationMicros.value
          : this.transcriptionDurationMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('_StoredLocalTranscript(')
          ..write('transcriptId: $transcriptId, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('originalText: $originalText, ')
          ..write('provider: $provider, ')
          ..write('audioDurationMicros: $audioDurationMicros, ')
          ..write('transcriptionDurationMicros: $transcriptionDurationMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    transcriptId,
    createdAtMicros,
    originalText,
    provider,
    audioDurationMicros,
    transcriptionDurationMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _StoredLocalTranscript &&
          other.transcriptId == this.transcriptId &&
          other.createdAtMicros == this.createdAtMicros &&
          other.originalText == this.originalText &&
          other.provider == this.provider &&
          other.audioDurationMicros == this.audioDurationMicros &&
          other.transcriptionDurationMicros ==
              this.transcriptionDurationMicros);
}

class _LocalTranscriptsCompanion
    extends UpdateCompanion<_StoredLocalTranscript> {
  final Value<String> transcriptId;
  final Value<int> createdAtMicros;
  final Value<String> originalText;
  final Value<String> provider;
  final Value<int> audioDurationMicros;
  final Value<int> transcriptionDurationMicros;
  final Value<int> rowid;
  const _LocalTranscriptsCompanion({
    this.transcriptId = const Value.absent(),
    this.createdAtMicros = const Value.absent(),
    this.originalText = const Value.absent(),
    this.provider = const Value.absent(),
    this.audioDurationMicros = const Value.absent(),
    this.transcriptionDurationMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  _LocalTranscriptsCompanion.insert({
    required String transcriptId,
    required int createdAtMicros,
    required String originalText,
    required String provider,
    required int audioDurationMicros,
    required int transcriptionDurationMicros,
    this.rowid = const Value.absent(),
  }) : transcriptId = Value(transcriptId),
       createdAtMicros = Value(createdAtMicros),
       originalText = Value(originalText),
       provider = Value(provider),
       audioDurationMicros = Value(audioDurationMicros),
       transcriptionDurationMicros = Value(transcriptionDurationMicros);
  static Insertable<_StoredLocalTranscript> custom({
    Expression<String>? transcriptId,
    Expression<int>? createdAtMicros,
    Expression<String>? originalText,
    Expression<String>? provider,
    Expression<int>? audioDurationMicros,
    Expression<int>? transcriptionDurationMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transcriptId != null) 'transcript_id': transcriptId,
      if (createdAtMicros != null) 'created_at_micros': createdAtMicros,
      if (originalText != null) 'original_text': originalText,
      if (provider != null) 'provider': provider,
      if (audioDurationMicros != null)
        'audio_duration_micros': audioDurationMicros,
      if (transcriptionDurationMicros != null)
        'transcription_duration_micros': transcriptionDurationMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  _LocalTranscriptsCompanion copyWith({
    Value<String>? transcriptId,
    Value<int>? createdAtMicros,
    Value<String>? originalText,
    Value<String>? provider,
    Value<int>? audioDurationMicros,
    Value<int>? transcriptionDurationMicros,
    Value<int>? rowid,
  }) {
    return _LocalTranscriptsCompanion(
      transcriptId: transcriptId ?? this.transcriptId,
      createdAtMicros: createdAtMicros ?? this.createdAtMicros,
      originalText: originalText ?? this.originalText,
      provider: provider ?? this.provider,
      audioDurationMicros: audioDurationMicros ?? this.audioDurationMicros,
      transcriptionDurationMicros:
          transcriptionDurationMicros ?? this.transcriptionDurationMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transcriptId.present) {
      map['transcript_id'] = Variable<String>(transcriptId.value);
    }
    if (createdAtMicros.present) {
      map['created_at_micros'] = Variable<int>(createdAtMicros.value);
    }
    if (originalText.present) {
      map['original_text'] = Variable<String>(originalText.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (audioDurationMicros.present) {
      map['audio_duration_micros'] = Variable<int>(audioDurationMicros.value);
    }
    if (transcriptionDurationMicros.present) {
      map['transcription_duration_micros'] = Variable<int>(
        transcriptionDurationMicros.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('_LocalTranscriptsCompanion(')
          ..write('transcriptId: $transcriptId, ')
          ..write('createdAtMicros: $createdAtMicros, ')
          ..write('originalText: $originalText, ')
          ..write('provider: $provider, ')
          ..write('audioDurationMicros: $audioDurationMicros, ')
          ..write('transcriptionDurationMicros: $transcriptionDurationMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$_TranscriptDatabase extends GeneratedDatabase {
  _$_TranscriptDatabase(QueryExecutor e) : super(e);
  $_TranscriptDatabaseManager get managers => $_TranscriptDatabaseManager(this);
  late final $_LocalTranscriptsTable localTranscripts = $_LocalTranscriptsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localTranscripts];
}

typedef $$_LocalTranscriptsTableCreateCompanionBuilder =
    _LocalTranscriptsCompanion Function({
      required String transcriptId,
      required int createdAtMicros,
      required String originalText,
      required String provider,
      required int audioDurationMicros,
      required int transcriptionDurationMicros,
      Value<int> rowid,
    });
typedef $$_LocalTranscriptsTableUpdateCompanionBuilder =
    _LocalTranscriptsCompanion Function({
      Value<String> transcriptId,
      Value<int> createdAtMicros,
      Value<String> originalText,
      Value<String> provider,
      Value<int> audioDurationMicros,
      Value<int> transcriptionDurationMicros,
      Value<int> rowid,
    });

class $$_LocalTranscriptsTableFilterComposer
    extends Composer<_$_TranscriptDatabase, $_LocalTranscriptsTable> {
  $$_LocalTranscriptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get transcriptId => $composableBuilder(
    column: $table.transcriptId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioDurationMicros => $composableBuilder(
    column: $table.audioDurationMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transcriptionDurationMicros => $composableBuilder(
    column: $table.transcriptionDurationMicros,
    builder: (column) => ColumnFilters(column),
  );
}

class $$_LocalTranscriptsTableOrderingComposer
    extends Composer<_$_TranscriptDatabase, $_LocalTranscriptsTable> {
  $$_LocalTranscriptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get transcriptId => $composableBuilder(
    column: $table.transcriptId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioDurationMicros => $composableBuilder(
    column: $table.audioDurationMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transcriptionDurationMicros => $composableBuilder(
    column: $table.transcriptionDurationMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$_LocalTranscriptsTableAnnotationComposer
    extends Composer<_$_TranscriptDatabase, $_LocalTranscriptsTable> {
  $$_LocalTranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get transcriptId => $composableBuilder(
    column: $table.transcriptId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMicros => $composableBuilder(
    column: $table.createdAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalText => $composableBuilder(
    column: $table.originalText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<int> get audioDurationMicros => $composableBuilder(
    column: $table.audioDurationMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transcriptionDurationMicros => $composableBuilder(
    column: $table.transcriptionDurationMicros,
    builder: (column) => column,
  );
}

class $$_LocalTranscriptsTableTableManager
    extends
        RootTableManager<
          _$_TranscriptDatabase,
          $_LocalTranscriptsTable,
          _StoredLocalTranscript,
          $$_LocalTranscriptsTableFilterComposer,
          $$_LocalTranscriptsTableOrderingComposer,
          $$_LocalTranscriptsTableAnnotationComposer,
          $$_LocalTranscriptsTableCreateCompanionBuilder,
          $$_LocalTranscriptsTableUpdateCompanionBuilder,
          (
            _StoredLocalTranscript,
            BaseReferences<
              _$_TranscriptDatabase,
              $_LocalTranscriptsTable,
              _StoredLocalTranscript
            >,
          ),
          _StoredLocalTranscript,
          PrefetchHooks Function()
        > {
  $$_LocalTranscriptsTableTableManager(
    _$_TranscriptDatabase db,
    $_LocalTranscriptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$_LocalTranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$_LocalTranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$_LocalTranscriptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> transcriptId = const Value.absent(),
                Value<int> createdAtMicros = const Value.absent(),
                Value<String> originalText = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<int> audioDurationMicros = const Value.absent(),
                Value<int> transcriptionDurationMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => _LocalTranscriptsCompanion(
                transcriptId: transcriptId,
                createdAtMicros: createdAtMicros,
                originalText: originalText,
                provider: provider,
                audioDurationMicros: audioDurationMicros,
                transcriptionDurationMicros: transcriptionDurationMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transcriptId,
                required int createdAtMicros,
                required String originalText,
                required String provider,
                required int audioDurationMicros,
                required int transcriptionDurationMicros,
                Value<int> rowid = const Value.absent(),
              }) => _LocalTranscriptsCompanion.insert(
                transcriptId: transcriptId,
                createdAtMicros: createdAtMicros,
                originalText: originalText,
                provider: provider,
                audioDurationMicros: audioDurationMicros,
                transcriptionDurationMicros: transcriptionDurationMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$_LocalTranscriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$_TranscriptDatabase,
      $_LocalTranscriptsTable,
      _StoredLocalTranscript,
      $$_LocalTranscriptsTableFilterComposer,
      $$_LocalTranscriptsTableOrderingComposer,
      $$_LocalTranscriptsTableAnnotationComposer,
      $$_LocalTranscriptsTableCreateCompanionBuilder,
      $$_LocalTranscriptsTableUpdateCompanionBuilder,
      (
        _StoredLocalTranscript,
        BaseReferences<
          _$_TranscriptDatabase,
          $_LocalTranscriptsTable,
          _StoredLocalTranscript
        >,
      ),
      _StoredLocalTranscript,
      PrefetchHooks Function()
    >;

class $_TranscriptDatabaseManager {
  final _$_TranscriptDatabase _db;
  $_TranscriptDatabaseManager(this._db);
  $$_LocalTranscriptsTableTableManager get localTranscripts =>
      $$_LocalTranscriptsTableTableManager(_db, _db.localTranscripts);
}
