import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/direct_context.dart';
import '../../domain/direct_chat.dart';

part 'drift_local_direct_chat_store.g.dart';

@DataClassName('_StoredDirectChatMessage')
class _DirectChatMessages extends Table {
  TextColumn get conversationId => text().withLength(min: 1, max: 128)();
  TextColumn get messageId => text().withLength(min: 1, max: 128)();
  TextColumn get role => text().withLength(min: 1, max: 16)();
  TextColumn get content => text()();
  IntColumn get createdAtMicros => integer()();
  TextColumn get terminal => text().withLength(min: 1, max: 16)();
  TextColumn get provenance => text().withLength(min: 1, max: 32)();
  IntColumn get messageRevision => integer()();
  BoolColumn get contextEligible => boolean()();
  @override
  Set<Column<Object>> get primaryKey => {conversationId, messageId};
  @override
  List<String> get customConstraints => const [
    "CHECK (terminal IN ('streaming', 'completed', 'cancelled', 'failed', 'incomplete', 'truncated'))",
    "CHECK (provenance IN ('native', 'legacy_unverified'))",
    'CHECK (message_revision > 0)',
  ];
}

@DataClassName('_StoredDirectContextMemory')
class _DirectContextMemories extends Table {
  TextColumn get conversationId => text().withLength(min: 1, max: 128)();
  TextColumn get memoryId => text().withLength(min: 1, max: 128)();
  TextColumn get content => text().withLength(min: 1, max: 8192)();
  TextColumn get scope => text().withLength(min: 1, max: 128)();
  IntColumn get memoryRevision => integer()();
  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {conversationId, memoryId};

  @override
  List<String> get customConstraints => const [
    'CHECK (memory_revision > 0)',
    'CHECK (updated_at_micros >= 0)',
  ];
}

@DataClassName('_StoredDirectContextSummary')
class _DirectContextSummaries extends Table {
  TextColumn get conversationId => text().withLength(min: 1, max: 128)();
  TextColumn get summaryId => text().withLength(min: 1, max: 128)();
  TextColumn get content => text().withLength(min: 1, max: 32768)();
  TextColumn get firstMessageId => text().withLength(min: 1, max: 128)();
  TextColumn get lastMessageId => text().withLength(min: 1, max: 128)();
  TextColumn get providerProfileId => text().withLength(min: 1, max: 128)();
  IntColumn get configurationRevision => integer()();
  IntColumn get updatedAtMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {conversationId};

  @override
  List<String> get customConstraints => const [
    'CHECK (configuration_revision > 0)',
    'CHECK (updated_at_micros >= 0)',
  ];
}

@DriftDatabase(
  tables: [
    _DirectChatMessages,
    _DirectContextMemories,
    _DirectContextSummaries,
  ],
)
class _DirectChatDatabase extends _$_DirectChatDatabase {
  _DirectChatDatabase(super.executor);
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'ALTER TABLE direct_chat_messages '
          'RENAME TO direct_chat_messages_legacy',
        );
        await customStatement('''
          CREATE TABLE direct_chat_messages (
            conversation_id TEXT NOT NULL,
            message_id TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at_micros INTEGER NOT NULL,
            terminal TEXT NOT NULL,
            provenance TEXT NOT NULL,
            message_revision INTEGER NOT NULL,
            context_eligible INTEGER NOT NULL,
            CHECK (terminal IN ('streaming', 'completed', 'cancelled', 'failed', 'incomplete', 'truncated')),
            CHECK (provenance IN ('native', 'legacy_unverified')),
            CHECK (message_revision > 0),
            PRIMARY KEY (conversation_id, message_id)
          )
        ''');
        await customStatement('''
          INSERT INTO direct_chat_messages
            (conversation_id, message_id, role, content, created_at_micros,
             terminal, provenance, message_revision, context_eligible)
          SELECT 'legacy-' || provider_id, message_id, role, content,
                 created_at_micros, 'incomplete', 'legacy_unverified', 1, 0
          FROM direct_chat_messages_legacy
        ''');
        await customStatement('DROP TABLE direct_chat_messages_legacy');
      }
      if (from < 3) {
        await m.createTable(directContextMemories);
        await m.createTable(directContextSummaries);
      }
    },
  );
}

class DriftLocalDirectChatStore
    implements DirectChatHistoryStore, DirectContextStore {
  DriftLocalDirectChatStore(QueryExecutor executor)
    : _database = _DirectChatDatabase(executor);
  factory DriftLocalDirectChatStore.inMemory() =>
      DriftLocalDirectChatStore(NativeDatabase.memory());
  DriftLocalDirectChatStore._(this._database);

  static Future<DriftLocalDirectChatStore> forApplication() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return DriftLocalDirectChatStore._(
      _DirectChatDatabase(
        NativeDatabase.createInBackground(
          File(
            '${directory.path}${Platform.pathSeparator}voxhandoff_direct_chat.sqlite',
          ),
        ),
      ),
    );
  }

  final _DirectChatDatabase _database;

  @override
  Future<List<DirectChatMessage>> list(String conversationId) async {
    final rows =
        await (_database.select(_database.directChatMessages)
              ..where((row) => row.conversationId.equals(conversationId))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAtMicros)]))
            .get();
    return List.unmodifiable(
      rows.map((row) {
        final provenance = row.provenance == 'legacy_unverified'
            ? DirectMessageProvenance.legacyUnverified
            : DirectMessageProvenance.native;
        return DirectChatMessage(
          id: row.messageId,
          role: DirectChatRole.values.byName(row.role),
          text: row.content,
          createdAt: DateTime.fromMicrosecondsSinceEpoch(
            row.createdAtMicros,
            isUtc: true,
          ),
          terminal: DirectMessageTerminal.values.byName(row.terminal),
          provenance: provenance,
          revision: row.messageRevision,
          contextEligibleOverride:
              provenance == DirectMessageProvenance.legacyUnverified
              ? row.contextEligible
              : null,
        );
      }),
    );
  }

  @override
  Future<void> upsert(String conversationId, DirectChatMessage message) =>
      _database
          .into(_database.directChatMessages)
          .insertOnConflictUpdate(
            _DirectChatMessagesCompanion.insert(
              conversationId: conversationId,
              messageId: message.id,
              role: message.role.name,
              content: message.text,
              createdAtMicros: message.createdAt.toUtc().microsecondsSinceEpoch,
              terminal: message.terminal.name,
              provenance: message.provenance.storageName,
              messageRevision: message.revision,
              contextEligible: message.contextEligible,
            ),
          );

  @override
  Future<DirectContextData> read(String conversationId) async {
    final memories = await (_database.select(
      _database.directContextMemories,
    )..where((row) => row.conversationId.equals(conversationId))).get();
    final summary =
        await (_database.select(_database.directContextSummaries)
              ..where((row) => row.conversationId.equals(conversationId)))
            .getSingleOrNull();
    return DirectContextData(
      memories: List.unmodifiable(
        memories.map(
          (row) => FixedMemory(
            memoryId: row.memoryId,
            text: row.content,
            scope: row.scope,
            revision: row.memoryRevision,
            updatedAt: DateTime.fromMicrosecondsSinceEpoch(
              row.updatedAtMicros,
              isUtc: true,
            ),
          ),
        ),
      ),
      summary: summary == null
          ? null
          : RollingSummary(
              summaryId: summary.summaryId,
              text: summary.content,
              firstMessageId: summary.firstMessageId,
              lastMessageId: summary.lastMessageId,
              providerProfileId: summary.providerProfileId,
              configurationRevision: summary.configurationRevision,
              updatedAt: DateTime.fromMicrosecondsSinceEpoch(
                summary.updatedAtMicros,
                isUtc: true,
              ),
            ),
    );
  }

  @override
  Future<void> saveMemory(String conversationId, FixedMemory memory) =>
      _database
          .into(_database.directContextMemories)
          .insertOnConflictUpdate(
            _DirectContextMemoriesCompanion.insert(
              conversationId: conversationId,
              memoryId: memory.memoryId,
              content: memory.text,
              scope: memory.scope,
              memoryRevision: memory.revision,
              updatedAtMicros: memory.updatedAt.toUtc().microsecondsSinceEpoch,
            ),
          );

  @override
  Future<void> deleteMemory(String conversationId, String memoryId) async {
    await (_database.delete(_database.directContextMemories)..where(
          (row) =>
              row.conversationId.equals(conversationId) &
              row.memoryId.equals(memoryId),
        ))
        .go();
  }

  @override
  Future<void> saveSummary(String conversationId, RollingSummary summary) =>
      _database
          .into(_database.directContextSummaries)
          .insertOnConflictUpdate(
            _DirectContextSummariesCompanion.insert(
              conversationId: conversationId,
              summaryId: summary.summaryId,
              content: summary.text,
              firstMessageId: summary.firstMessageId,
              lastMessageId: summary.lastMessageId,
              providerProfileId: summary.providerProfileId,
              configurationRevision: summary.configurationRevision,
              updatedAtMicros: summary.updatedAt.toUtc().microsecondsSinceEpoch,
            ),
          );

  @override
  Future<void> deleteSummary(String conversationId) async {
    await (_database.delete(
      _database.directContextSummaries,
    )..where((row) => row.conversationId.equals(conversationId))).go();
  }

  Future<void> close() => _database.close();
}
