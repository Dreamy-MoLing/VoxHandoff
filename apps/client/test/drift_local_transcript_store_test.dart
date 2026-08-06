import 'dart:io';

import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/storage/drift_local_transcript_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saves, reopens, prunes, and deletes private transcript records',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voxhandoff-transcripts-',
      );
      final file = File('${directory.path}/voice.sqlite');
      const oldId = 'voice-old';
      const recentId = 'voice-recent';
      try {
        final first = DriftLocalTranscriptStore.openFile(file);
        await first.save(_fixture(oldId, DateTime.utc(2026, 7, 1)));
        await first.save(_fixture(recentId, DateTime.utc(2026, 7, 22)));
        await first.close();

        final reopened = DriftLocalTranscriptStore.openFile(file);
        expect(
          (await reopened.readForTesting(recentId))?.originalText,
          '检查核心测试，然后报告结果。',
        );
        await reopened.pruneBefore(DateTime.utc(2026, 7, 15));
        expect(await reopened.readForTesting(oldId), isNull);
        expect(await reopened.readForTesting(recentId), isNotNull);
        await reopened.delete(recentId);
        expect(await reopened.readForTesting(recentId), isNull);
        await reopened.close();
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}

StoredTranscript _fixture(String id, DateTime createdAt) => StoredTranscript(
  transcriptId: id,
  createdAt: createdAt,
  originalText: '检查核心测试，然后报告结果。',
  provider: 'local-stt',
  audioDuration: const Duration(seconds: 4),
  transcriptionDuration: const Duration(milliseconds: 900),
);
