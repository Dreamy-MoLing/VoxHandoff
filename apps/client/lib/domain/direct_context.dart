import 'dart:convert';

import 'confirmed_draft.dart';
import 'direct_chat.dart';

/// A deterministic byte budget is intentionally used instead of a tokenizer.
/// It is portable across providers and keeps the request bounded even when a
/// provider's tokenizer is unavailable.
class DirectContextPolicy {
  const DirectContextPolicy({
    this.maxRequestBytes = 48 * 1024,
    this.outputReserveBytes = 8 * 1024,
  }) : assert(maxRequestBytes > outputReserveBytes);

  final int maxRequestBytes;
  final int outputReserveBytes;

  int get inputBudgetBytes => maxRequestBytes - outputReserveBytes;

  bool get isSafe =>
      maxRequestBytes > 0 &&
      outputReserveBytes >= 0 &&
      maxRequestBytes > outputReserveBytes;
}

class FixedMemory {
  const FixedMemory({
    required this.memoryId,
    required this.text,
    required this.scope,
    required this.revision,
    required this.updatedAt,
  });

  final String memoryId;
  final String text;
  final String scope;
  final int revision;
  final DateTime updatedAt;

  FixedMemory copyWith({
    String? text,
    String? scope,
    int? revision,
    DateTime? updatedAt,
  }) => FixedMemory(
    memoryId: memoryId,
    text: text ?? this.text,
    scope: scope ?? this.scope,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class RollingSummary {
  const RollingSummary({
    required this.summaryId,
    required this.text,
    required this.firstMessageId,
    required this.lastMessageId,
    required this.providerProfileId,
    required this.configurationRevision,
    required this.updatedAt,
  });

  final String summaryId;
  final String text;
  final String firstMessageId;
  final String lastMessageId;
  final String providerProfileId;
  final int configurationRevision;
  final DateTime updatedAt;
}

class DirectContextData {
  const DirectContextData({
    this.policy = const DirectContextPolicy(),
    this.memories = const [],
    this.summary,
  });

  final DirectContextPolicy policy;
  final List<FixedMemory> memories;
  final RollingSummary? summary;

  List<String> canonicalParts(List<DirectChatMessage> history) => [
    'policy:${policy.maxRequestBytes}:${policy.outputReserveBytes}',
    for (final memory in _sortedMemories(memories))
      'memory:${memory.memoryId}:${memory.revision}:${memory.scope}:${memory.text}',
    if (summary != null)
      'summary:${summary!.summaryId}:${summary!.firstMessageId}:${summary!.lastMessageId}:${summary!.providerProfileId}:${summary!.configurationRevision}:${summary!.text}',
    for (final message in history.where((message) => message.contextEligible))
      'message:${message.id}:${message.revision}:${message.terminal.name}:${message.text}',
  ];
}

List<FixedMemory> _sortedMemories(Iterable<FixedMemory> memories) =>
    (memories.toList()..sort((a, b) => a.memoryId.compareTo(b.memoryId)));

abstract interface class DirectContextStore {
  Future<DirectContextData> read(String conversationId);
  Future<void> saveMemory(String conversationId, FixedMemory memory);
  Future<void> deleteMemory(String conversationId, String memoryId);
  Future<void> saveSummary(String conversationId, RollingSummary summary);
  Future<void> deleteSummary(String conversationId);
}

/// Used by isolated tests and by the unconfigured Riverpod fallback. The
/// production composition root replaces it with the Drift-backed store.
class InMemoryDirectContextStore implements DirectContextStore {
  final Map<String, DirectContextData> _values = {};

  @override
  Future<DirectContextData> read(String conversationId) async =>
      _values[conversationId] ?? const DirectContextData();

  @override
  Future<void> saveMemory(String conversationId, FixedMemory memory) async {
    final current = await read(conversationId);
    final memories = [...current.memories]
      ..removeWhere((item) => item.memoryId == memory.memoryId)
      ..add(memory);
    _values[conversationId] = DirectContextData(
      policy: current.policy,
      memories: List.unmodifiable(memories),
      summary: current.summary,
    );
  }

  @override
  Future<void> deleteMemory(String conversationId, String memoryId) async {
    final current = await read(conversationId);
    _values[conversationId] = DirectContextData(
      policy: current.policy,
      memories: List.unmodifiable(
        current.memories.where((item) => item.memoryId != memoryId),
      ),
      summary: current.summary,
    );
  }

  @override
  Future<void> saveSummary(
    String conversationId,
    RollingSummary summary,
  ) async {
    final current = await read(conversationId);
    _values[conversationId] = DirectContextData(
      policy: current.policy,
      memories: current.memories,
      summary: summary,
    );
  }

  @override
  Future<void> deleteSummary(String conversationId) async {
    final current = await read(conversationId);
    _values[conversationId] = DirectContextData(
      policy: current.policy,
      memories: current.memories,
    );
  }
}

class DirectContextException implements Exception {
  const DirectContextException(this.code, this.safeMessage);

  final String code;
  final String safeMessage;
}

class DirectContextAssembly {
  const DirectContextAssembly({
    required this.messages,
    required this.data,
    required this.inputBytes,
  });

  final List<DirectChatMessage> messages;
  final DirectContextData data;
  final int inputBytes;
}

class DirectContextBuilder {
  const DirectContextBuilder();

  DirectContextAssembly assemble({
    required DirectLlmConfiguration configuration,
    required List<DirectChatMessage> history,
    required DirectChatMessage currentUser,
    required DirectContextData data,
  }) {
    if (!data.policy.isSafe) {
      throw const DirectContextException(
        'context_policy_invalid',
        'The conversation context policy is invalid.',
      );
    }
    final base = <DirectChatMessage>[];
    if (configuration.systemPrompt.trim().isNotEmpty) {
      base.add(
        _contextMessage(
          id: 'context-system-prompt',
          text: configuration.systemPrompt.trim(),
        ),
      );
    }
    for (final memory in _sortedMemories(data.memories)) {
      if (memory.text.trim().isEmpty) continue;
      base.add(
        _contextMessage(
          id: 'context-memory-${memory.memoryId}',
          text: '[Pinned memory / ${memory.scope}] ${memory.text.trim()}',
        ),
      );
    }
    final summary = data.summary;
    if (summary != null && summary.text.trim().isNotEmpty) {
      if (summary.providerProfileId != configuration.profileId ||
          summary.configurationRevision !=
              configuration.configurationRevision) {
        throw const DirectContextException(
          'context_summary_target_mismatch',
          'The conversation summary belongs to another Direct LLM target.',
        );
      }
      final firstIndex = history.indexWhere(
        (message) => message.id == summary.firstMessageId,
      );
      final lastIndex = history.indexWhere(
        (message) => message.id == summary.lastMessageId,
      );
      if (firstIndex < 0 || lastIndex < firstIndex) {
        throw const DirectContextException(
          'context_summary_source_missing',
          'The conversation summary no longer matches local message history.',
        );
      }
      base.add(
        _contextMessage(
          id: 'context-summary-${summary.summaryId}',
          text: '[Rolling summary] ${summary.text.trim()}',
        ),
      );
    }

    var inputBytes = _messagesBytes(base);
    if (inputBytes > data.policy.inputBudgetBytes) {
      throw const DirectContextException(
        'context_base_too_large',
        'The system prompt, memories, or summary exceed the context budget.',
      );
    }

    final eligible = history
        .where(
          (message) =>
              message.contextEligible &&
              message.role != DirectChatRole.system &&
              message.terminal == DirectMessageTerminal.completed,
        )
        .toList(growable: false);
    final turns = _turns(eligible);
    final selected = <DirectChatMessage>[];
    for (final turn in turns.reversed) {
      final turnBytes = _messagesBytes(turn);
      if (inputBytes + turnBytes > data.policy.inputBudgetBytes) break;
      selected.insertAll(0, turn);
      inputBytes += turnBytes;
    }
    final currentBytes = _messagesBytes([currentUser]);
    if (inputBytes + currentBytes > data.policy.inputBudgetBytes) {
      throw const DirectContextException(
        'context_current_message_too_large',
        'The current message exceeds the conversation context budget.',
      );
    }
    inputBytes += currentBytes;
    return DirectContextAssembly(
      messages: List.unmodifiable([...base, ...selected, currentUser]),
      data: data,
      inputBytes: inputBytes,
    );
  }

  List<List<DirectChatMessage>> _turns(List<DirectChatMessage> messages) {
    final turns = <List<DirectChatMessage>>[];
    for (final message in messages) {
      if (message.role == DirectChatRole.user || turns.isEmpty) {
        turns.add([message]);
      } else {
        turns.last.add(message);
      }
    }
    return turns;
  }

  int _messagesBytes(Iterable<DirectChatMessage> messages) => messages.fold(
    0,
    (total, message) =>
        total + utf8.encode('${message.role.name}\u0000${message.text}').length,
  );

  DirectChatMessage _contextMessage({
    required String id,
    required String text,
  }) => DirectChatMessage(
    id: id,
    role: DirectChatRole.system,
    text: text,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

String directContextHash(
  DirectContextData data,
  List<DirectChatMessage> history,
) => ConfirmedDraft.contextHash(data.canonicalParts(history));
