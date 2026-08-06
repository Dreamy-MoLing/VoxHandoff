import 'dart:io';

import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:agent_talk_client/domain/direct_context.dart';
import 'package:agent_talk_client/infrastructure/storage/drift_local_direct_chat_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'migrates legacy provider rows into isolated unverified history',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
      CREATE TABLE direct_chat_messages (
        provider_id TEXT NOT NULL,
        message_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at_micros INTEGER NOT NULL,
        completed INTEGER NOT NULL,
        PRIMARY KEY (provider_id, message_id)
      )
    ''');
          database.execute('''
          INSERT INTO direct_chat_messages
        (provider_id, message_id, role, content, created_at_micros, completed)
      VALUES ('default-direct-llm', 'legacy-reply', 'user',
              'old reply', 1785456000000000, 1)
    ''');
          database.execute('PRAGMA user_version = 1');
        },
      );

      final store = DriftLocalDirectChatStore(executor);
      addTearDown(store.close);

      final legacy = await store.list('legacy-default-direct-llm');
      expect(legacy, hasLength(1));
      expect(legacy.single.terminal, DirectMessageTerminal.incomplete);
      expect(
        legacy.single.provenance,
        DirectMessageProvenance.legacyUnverified,
      );
      expect(legacy.single.contextEligible, isFalse);

      await store.upsert(
        'conversation-new',
        DirectChatMessage(
          id: 'message-new',
          role: DirectChatRole.user,
          text: 'new message',
          createdAt: DateTime.now().toUtc(),
        ),
      );
      expect(await store.list('conversation-new'), hasLength(1));
      expect(await store.list('default-direct-llm'), isEmpty);
    },
  );

  test(
    'new rows persist terminal and provenance without completed boolean',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voxhandoff-direct-',
      );
      final file = File('${directory.path}/direct.sqlite');
      try {
        final first = DriftLocalDirectChatStore(
          NativeDatabase.createInBackground(file),
        );
        await first.upsert(
          'conversation-1',
          DirectChatMessage(
            id: 'reply-1',
            role: DirectChatRole.assistant,
            text: 'partial',
            createdAt: DateTime.utc(2026, 8, 1),
            terminal: DirectMessageTerminal.incomplete,
          ),
        );
        await first.close();

        final reopened = DriftLocalDirectChatStore(
          NativeDatabase.createInBackground(file),
        );
        final message = (await reopened.list('conversation-1')).single;
        expect(message.terminal, DirectMessageTerminal.incomplete);
        expect(message.provenance, DirectMessageProvenance.native);
        await reopened.close();
      } finally {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    },
  );

  test('persists conversation memories and summaries independently', () async {
    final store = DriftLocalDirectChatStore.inMemory();
    addTearDown(store.close);
    final now = DateTime.utc(2026, 8, 1);
    await store.saveMemory(
      'conversation-a',
      FixedMemory(
        memoryId: 'memory-a',
        text: 'local preference',
        scope: 'conversation',
        revision: 1,
        updatedAt: now,
      ),
    );
    await store.saveSummary(
      'conversation-a',
      RollingSummary(
        summaryId: 'summary-a',
        text: 'bounded summary',
        firstMessageId: 'message-1',
        lastMessageId: 'message-2',
        providerProfileId: 'profile-a',
        configurationRevision: 1,
        updatedAt: now,
      ),
    );

    final context = await store.read('conversation-a');
    expect(context.memories.single.text, 'local preference');
    expect(context.summary?.text, 'bounded summary');
    expect((await store.read('conversation-b')).memories, isEmpty);
    expect((await store.read('conversation-b')).summary, isNull);
  });
}
