import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/voice.dart';

part 'drift_local_transcript_store.g.dart';

@DataClassName('_StoredLocalTranscript')
class _LocalTranscripts extends Table {
  @override
  String get tableName => 'local_stt_transcripts';

  TextColumn get transcriptId => text().withLength(min: 1, max: 256)();

  IntColumn get createdAtMicros => integer()();

  TextColumn get originalText => text()();

  TextColumn get provider => text().withLength(min: 1, max: 64)();

  IntColumn get audioDurationMicros => integer()();

  IntColumn get transcriptionDurationMicros => integer()();

  @override
  Set<Column<Object>> get primaryKey => {transcriptId};

  @override
  List<String> get customConstraints => const [
    'CHECK (created_at_micros >= 0)',
    'CHECK (audio_duration_micros >= 0)',
    'CHECK (transcription_duration_micros >= 0)',
  ];
}

@DriftDatabase(tables: [_LocalTranscripts])
class _TranscriptDatabase extends _$_TranscriptDatabase {
  _TranscriptDatabase(super.executor);

  @override
  int get schemaVersion => 1;
}

/// Private local retention for original STT finals. The production file lives
/// in Application Support and is pruned to the seven-day product default.
class DriftLocalTranscriptStore implements LocalTranscriptStore {
  DriftLocalTranscriptStore(QueryExecutor executor)
    : _database = _TranscriptDatabase(executor);

  factory DriftLocalTranscriptStore.inMemory() =>
      DriftLocalTranscriptStore(NativeDatabase.memory());

  factory DriftLocalTranscriptStore.openFile(File file) =>
      DriftLocalTranscriptStore(NativeDatabase(file));

  DriftLocalTranscriptStore._(this._database);

  static Future<DriftLocalTranscriptStore> forApplication() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}voxhandoff_voice.sqlite',
    );
    return DriftLocalTranscriptStore._(
      _TranscriptDatabase(NativeDatabase.createInBackground(file)),
    );
  }

  final _TranscriptDatabase _database;

  @override
  Future<void> save(StoredTranscript transcript) => _database
      .into(_database.localTranscripts)
      .insertOnConflictUpdate(
        _LocalTranscriptsCompanion.insert(
          transcriptId: transcript.transcriptId,
          createdAtMicros: transcript.createdAt.toUtc().microsecondsSinceEpoch,
          originalText: transcript.originalText,
          provider: transcript.provider,
          audioDurationMicros: transcript.audioDuration.inMicroseconds,
          transcriptionDurationMicros:
              transcript.transcriptionDuration.inMicroseconds,
        ),
      );

  @override
  Future<void> delete(String transcriptId) async {
    await (_database.delete(
      _database.localTranscripts,
    )..where((row) => row.transcriptId.equals(transcriptId))).go();
  }

  @override
  Future<void> pruneBefore(DateTime cutoff) async {
    await (_database.delete(_database.localTranscripts)..where(
          (row) => row.createdAtMicros.isSmallerThanValue(
            cutoff.toUtc().microsecondsSinceEpoch,
          ),
        ))
        .go();
  }

  /// Used by storage lifecycle tests without exposing generated Drift rows.
  Future<StoredTranscript?> readForTesting(String transcriptId) async {
    final query = _database.select(_database.localTranscripts)
      ..where((row) => row.transcriptId.equals(transcriptId));
    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return StoredTranscript(
      transcriptId: row.transcriptId,
      createdAt: DateTime.fromMicrosecondsSinceEpoch(
        row.createdAtMicros,
        isUtc: true,
      ),
      originalText: row.originalText,
      provider: row.provider,
      audioDuration: Duration(microseconds: row.audioDurationMicros),
      transcriptionDuration: Duration(
        microseconds: row.transcriptionDurationMicros,
      ),
    );
  }

  Future<void> close() => _database.close();
}
