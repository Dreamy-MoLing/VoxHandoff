import 'package:agent_talk_client/domain/direct_context.dart';
import 'package:agent_talk_client/domain/direct_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final configuration = DirectLlmConfiguration(
    providerProfileId: 'profile-a',
    origin: Uri.parse('https://llm.example.test'),
    model: 'model-a',
    systemPrompt: 'Be concise.',
    configurationRevision: 2,
    conversationId: 'conversation-a',
  );

  test('assembles context in order and excludes non-completed replies', () {
    final now = DateTime.utc(2026, 8, 1);
    final history = [
      DirectChatMessage(
        id: 'old-user',
        role: DirectChatRole.user,
        text: 'old question',
        createdAt: now,
      ),
      DirectChatMessage(
        id: 'old-reply',
        role: DirectChatRole.assistant,
        text: 'old answer',
        createdAt: now,
      ),
      DirectChatMessage(
        id: 'partial',
        role: DirectChatRole.assistant,
        text: 'must not enter',
        createdAt: now,
        terminal: DirectMessageTerminal.incomplete,
      ),
      DirectChatMessage(
        id: 'legacy',
        role: DirectChatRole.assistant,
        text: 'legacy must not enter',
        createdAt: now,
        provenance: DirectMessageProvenance.legacyUnverified,
      ),
    ];
    final data = DirectContextData(
      memories: [
        FixedMemory(
          memoryId: 'memory-1',
          text: 'The user prefers short answers.',
          scope: 'conversation',
          revision: 1,
          updatedAt: now,
        ),
      ],
      summary: RollingSummary(
        summaryId: 'summary-1',
        text: 'The conversation is about context safety.',
        firstMessageId: 'old-user',
        lastMessageId: 'old-reply',
        providerProfileId: 'profile-a',
        configurationRevision: 2,
        updatedAt: now,
      ),
    );
    final current = DirectChatMessage(
      id: 'current',
      role: DirectChatRole.user,
      text: 'new question',
      createdAt: now,
    );

    final assembly = const DirectContextBuilder().assemble(
      configuration: configuration,
      history: history,
      currentUser: current,
      data: data,
    );

    expect(assembly.messages.map((message) => message.text), [
      'Be concise.',
      '[Pinned memory / conversation] The user prefers short answers.',
      '[Rolling summary] The conversation is about context safety.',
      'old question',
      'old answer',
      'new question',
    ]);
    expect(
      assembly.messages.map((message) => message.text),
      isNot(contains('must not enter')),
    );
  });

  test('keeps an output reserve and drops oldest complete turns', () {
    final now = DateTime.utc(2026, 8, 1);
    final history = [
      for (var index = 0; index < 4; index++) ...[
        DirectChatMessage(
          id: 'user-$index',
          role: DirectChatRole.user,
          text: 'question-$index-${'x' * 20}',
          createdAt: now,
        ),
        DirectChatMessage(
          id: 'reply-$index',
          role: DirectChatRole.assistant,
          text: 'answer-$index-${'y' * 20}',
          createdAt: now,
        ),
      ],
    ];
    final assembly = const DirectContextBuilder().assemble(
      configuration: configuration,
      history: history,
      currentUser: DirectChatMessage(
        id: 'current',
        role: DirectChatRole.user,
        text: 'current',
        createdAt: now,
      ),
      data: const DirectContextData(
        policy: DirectContextPolicy(
          maxRequestBytes: 180,
          outputReserveBytes: 60,
        ),
      ),
    );

    expect(assembly.inputBytes, lessThanOrEqualTo(120));
    expect(assembly.messages.any((message) => message.id == 'user-0'), isFalse);
    expect(assembly.messages.last.id, 'current');
  });

  test('rejects summaries from another provider revision', () {
    expect(
      () => const DirectContextBuilder().assemble(
        configuration: configuration,
        history: const [],
        currentUser: DirectChatMessage(
          id: 'current',
          role: DirectChatRole.user,
          text: 'hello',
          createdAt: DateTime.utc(2026, 8, 1),
        ),
        data: DirectContextData(
          summary: RollingSummary(
            summaryId: 'wrong-summary',
            text: 'wrong target',
            firstMessageId: 'a',
            lastMessageId: 'b',
            providerProfileId: 'profile-b',
            configurationRevision: 2,
            updatedAt: DateTime.utc(2026, 8, 1),
          ),
        ),
      ),
      throwsA(
        isA<DirectContextException>().having(
          (error) => error.code,
          'code',
          'context_summary_target_mismatch',
        ),
      ),
    );
  });

  test('in-memory context store supports memory and summary CRUD', () async {
    final store = InMemoryDirectContextStore();
    final now = DateTime.utc(2026, 8, 1);
    await store.saveMemory(
      'conversation-a',
      FixedMemory(
        memoryId: 'memory-1',
        text: 'remember this',
        scope: 'conversation',
        revision: 1,
        updatedAt: now,
      ),
    );
    expect((await store.read('conversation-a')).memories, hasLength(1));
    await store.deleteMemory('conversation-a', 'memory-1');
    expect((await store.read('conversation-a')).memories, isEmpty);
    await store.saveSummary(
      'conversation-a',
      RollingSummary(
        summaryId: 'summary-1',
        text: 'summary',
        firstMessageId: 'a',
        lastMessageId: 'b',
        providerProfileId: 'profile-a',
        configurationRevision: 2,
        updatedAt: now,
      ),
    );
    expect((await store.read('conversation-a')).summary?.text, 'summary');
    await store.deleteSummary('conversation-a');
    expect((await store.read('conversation-a')).summary, isNull);
  });
}
