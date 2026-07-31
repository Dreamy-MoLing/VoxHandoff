import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/direct_chat.dart';

part 'drift_local_direct_chat_store.g.dart';

@DataClassName('_StoredDirectChatMessage')
class _DirectChatMessages extends Table {
  TextColumn get providerId => text().withLength(min: 1, max: 128)();
  TextColumn get messageId => text().withLength(min: 1, max: 128)();
  TextColumn get role => text().withLength(min: 1, max: 16)();
  TextColumn get content => text()();
  IntColumn get createdAtMicros => integer()();
  BoolColumn get completed => boolean()();
  @override
  Set<Column<Object>> get primaryKey => {providerId, messageId};
}

@DriftDatabase(tables: [_DirectChatMessages])
class _DirectChatDatabase extends _$_DirectChatDatabase {
  _DirectChatDatabase(super.executor);
  @override
  int get schemaVersion => 1;
}

class DriftLocalDirectChatStore implements DirectChatHistoryStore {
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
  Future<List<DirectChatMessage>> list(String providerId) async {
    final rows =
        await (_database.select(_database.directChatMessages)
              ..where((row) => row.providerId.equals(providerId))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAtMicros)]))
            .get();
    return List.unmodifiable(
      rows.map(
        (row) => DirectChatMessage(
          id: row.messageId,
          role: DirectChatRole.values.byName(row.role),
          text: row.content,
          createdAt: DateTime.fromMicrosecondsSinceEpoch(
            row.createdAtMicros,
            isUtc: true,
          ),
          completed: row.completed,
        ),
      ),
    );
  }

  @override
  Future<void> upsert(String providerId, DirectChatMessage message) => _database
      .into(_database.directChatMessages)
      .insertOnConflictUpdate(
        _DirectChatMessagesCompanion.insert(
          providerId: providerId,
          messageId: message.id,
          role: message.role.name,
          content: message.text,
          createdAtMicros: message.createdAt.toUtc().microsecondsSinceEpoch,
          completed: message.completed,
        ),
      );

  Future<void> close() => _database.close();
}
