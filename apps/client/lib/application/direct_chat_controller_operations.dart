part of 'direct_chat_controller.dart';

// The operations stay in this library part so they can use the controller's
// protected Riverpod state/ref members without changing the runtime boundary.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

extension DirectChatControllerOperations on DirectChatController {
  Future<List<FixedMemory>> listMemories() async {
    final configuration = state.configuration;
    if (configuration == null) return const [];
    return (await ref
            .read(directContextStoreProvider)
            .read(configuration.conversationId))
        .memories;
  }

  Future<RollingSummary?> readSummary() async {
    final configuration = state.configuration;
    if (configuration == null) return null;
    return (await ref
            .read(directContextStoreProvider)
            .read(configuration.conversationId))
        .summary;
  }

  Future<void> saveMemory(
    String text, {
    String scope = 'conversation',
    String? memoryId,
  }) async {
    final configuration = state.configuration;
    final normalizedText = text.trim();
    final normalizedScope = scope.trim();
    if (configuration == null ||
        normalizedText.isEmpty ||
        normalizedText.length > 8192 ||
        normalizedScope.isEmpty ||
        normalizedScope.length > 128) {
      throw const FormatException('The fixed memory is invalid.');
    }
    await cancelForContextChange();
    final current = await ref
        .read(directContextStoreProvider)
        .read(configuration.conversationId);
    FixedMemory? existing;
    for (final item in current.memories) {
      if ((memoryId != null && item.memoryId == memoryId) ||
          (memoryId == null &&
              item.text == normalizedText &&
              item.scope == normalizedScope)) {
        existing = item;
        break;
      }
    }
    final memory = FixedMemory(
      memoryId: existing?.memoryId ?? memoryId ?? _opaqueId('memory'),
      text: normalizedText,
      scope: normalizedScope,
      revision: (existing?.revision ?? 0) + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref
        .read(directContextStoreProvider)
        .saveMemory(configuration.conversationId, memory);
    await _refreshContextAfterMutation(configuration);
  }

  Future<void> updateAssistantIdentity({
    required String displayName,
    required String persona,
    AssistantSpeechPolicy? speechPolicy,
  }) async {
    final current = state.assistantProfile;
    if (current == null) return;
    final name = displayName.trim();
    final description = persona.trim();
    if (name.isEmpty || name.length > 128 || description.length > 2048) {
      throw const FormatException('The assistant identity is invalid.');
    }
    await cancelForContextChange();
    final updated = current.copyWith(
      assistantRevision: current.assistantRevision + 1,
      displayName: name,
      persona: description,
      speechPolicy: speechPolicy,
    );
    final store = ref.read(directChatConfigurationStoreProvider);
    await store.saveAssistant(updated);
    final configuration = state.configuration;
    if (configuration == null) {
      state = state.copyWith(assistantProfile: updated);
      return;
    }
    final next = configuration.copyWith(
      assistantRevision: updated.assistantRevision,
      contextSnapshotRevision: configuration.contextSnapshotRevision + 1,
    );
    await store.save(next);
    ref.read(clientSessionProvider.notifier).invalidateConfirmation();
    state = state.copyWith(configuration: next, assistantProfile: updated);
  }

  Future<void> speakMessage(DirectChatMessage message) async {
    final configuration = state.configuration;
    final assistant = state.assistantProfile;
    if (configuration == null ||
        assistant?.speechPolicy != AssistantSpeechPolicy.manual ||
        message.role != DirectChatRole.assistant ||
        message.terminal != DirectMessageTerminal.completed ||
        message.text.trim().isEmpty ||
        !_isCurrentConfiguration(configuration)) {
      return;
    }
    await ref
        .read(speechPlaybackProvider.notifier)
        .speakCompletedReply(
          conversationId: configuration.conversationId,
          requestId: message.id,
          messageRevision: BigInt.from(message.revision),
          fullReply: message.text,
        );
  }

  Future<void> deleteMemory(String memoryId) async {
    final configuration = state.configuration;
    if (configuration == null || memoryId.trim().isEmpty) return;
    await cancelForContextChange();
    await ref
        .read(directContextStoreProvider)
        .deleteMemory(configuration.conversationId, memoryId);
    await _refreshContextAfterMutation(configuration);
  }

  /// Rebuilds a local, deterministic summary from completed turns. It does not
  /// make a second LLM request, so summary failure cannot affect chat sending.
  Future<void> rebuildSummary() async {
    final configuration = state.configuration;
    if (configuration == null) return;
    await cancelForContextChange();
    final messages = state.messages
        .where(
          (message) =>
              message.contextEligible &&
              message.terminal == DirectMessageTerminal.completed &&
              message.role != DirectChatRole.system,
        )
        .toList(growable: false);
    if (messages.isEmpty) {
      await clearSummary();
      return;
    }
    final summaryText = messages
        .map(
          (message) =>
              '${message.role == DirectChatRole.user ? 'User' : 'Assistant'}: ${message.text}',
        )
        .join('\n');
    final bounded = summaryText.length > 16384
        ? summaryText.substring(summaryText.length - 16384)
        : summaryText;
    final current = await readSummary();
    await ref
        .read(directContextStoreProvider)
        .saveSummary(
          configuration.conversationId,
          RollingSummary(
            summaryId: current?.summaryId ?? _opaqueId('summary'),
            text: bounded,
            firstMessageId: messages.first.id,
            lastMessageId: messages.last.id,
            providerProfileId: configuration.profileId,
            configurationRevision: configuration.configurationRevision,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    await _refreshContextAfterMutation(configuration);
  }

  Future<void> clearSummary() async {
    final configuration = state.configuration;
    if (configuration == null) return;
    await cancelForContextChange();
    await ref
        .read(directContextStoreProvider)
        .deleteSummary(configuration.conversationId);
    await _refreshContextAfterMutation(configuration);
  }

  Future<void> _refreshContextAfterMutation(
    DirectLlmConfiguration configuration,
  ) async {
    final refreshed = await _withCurrentContext(configuration, state.messages);
    final next = refreshed.copyWith(
      contextSnapshotRevision:
          refreshed.contextSnapshotRevision ==
              configuration.contextSnapshotRevision
          ? refreshed.contextSnapshotRevision + 1
          : refreshed.contextSnapshotRevision,
    );
    await ref.read(directChatConfigurationStoreProvider).save(next);
    ref.read(clientSessionProvider.notifier).invalidateConfirmation();
    state = state.copyWith(configuration: next);
  }

  Future<void> _completePartial(
    String conversationId,
    String replyId, {
    required String code,
  }) async {
    final messages = state.messages
        .map(
          (message) => message.id == replyId
              ? message.copyWith(terminal: _terminalFor(code, message.text))
              : message,
        )
        .toList(growable: false);
    state = state.copyWith(messages: messages);
    await ref
        .read(directChatHistoryStoreProvider)
        .upsert(conversationId, messages.last);
  }

  DirectMessageTerminal _terminalFor(String code, String text) {
    if (code == 'llm_stream_too_large') {
      return DirectMessageTerminal.truncated;
    }
    return text.trim().isEmpty
        ? DirectMessageTerminal.failed
        : DirectMessageTerminal.incomplete;
  }

  bool _ownsRequest(
    int generation,
    String requestId,
    DirectLlmConfiguration configuration,
  ) =>
      generation == _generation &&
      _activeRequestId == requestId &&
      identical(_activeConfiguration, configuration);

  bool _isCurrentConfiguration(DirectLlmConfiguration configuration) {
    final current = state.configuration;
    return _activeConfiguration == null &&
        current != null &&
        current.conversationId == configuration.conversationId &&
        current.profileId == configuration.profileId &&
        current.credentialRevision == configuration.credentialRevision &&
        current.configurationRevision == configuration.configurationRevision &&
        current.assistantId == configuration.assistantId &&
        current.assistantRevision == configuration.assistantRevision;
  }

  void _releaseRequest(String requestId) {
    if (_activeRequestId == requestId) {
      _activeRequestId = null;
      _activeConfiguration = null;
    }
  }

  bool _draftMatchesConfiguration(
    ConfirmedDraft draft,
    DirectLlmConfiguration configuration,
  ) {
    final target = draft.target;
    return target is DirectTargetSnapshot &&
        target.conversationId == configuration.conversationId &&
        target.providerProfileId == configuration.profileId &&
        target.credentialRevision == configuration.credentialRevision &&
        target.configurationRevision == configuration.configurationRevision &&
        target.normalizedOrigin ==
            normalizedProviderOrigin(configuration.origin) &&
        target.model == configuration.model &&
        draft.assistantId == configuration.assistantId &&
        draft.assistantRevision == configuration.assistantRevision &&
        draft.contextSnapshotRevision ==
            configuration.contextSnapshotRevision &&
        draft.contextSnapshotHash == configuration.contextSnapshotHash;
  }

  DirectTargetSnapshot _directTarget(DirectLlmConfiguration configuration) =>
      DirectTargetSnapshot(
        conversationId: configuration.conversationId,
        providerProfileId: configuration.profileId,
        credentialRevision: configuration.credentialRevision,
        configurationRevision: configuration.configurationRevision,
        normalizedOrigin: normalizedProviderOrigin(configuration.origin),
        model: configuration.model,
      );

  Future<DirectLlmConfiguration> _withCurrentContext(
    DirectLlmConfiguration configuration,
    List<DirectChatMessage> messages,
  ) async {
    final data = await ref
        .read(directContextStoreProvider)
        .read(configuration.conversationId);
    final hash = directContextHash(data, messages);
    return configuration.copyWith(
      contextSnapshotRevision: configuration.contextSnapshotHash == hash
          ? configuration.contextSnapshotRevision
          : configuration.contextSnapshotRevision + 1,
      contextSnapshotHash: hash,
    );
  }

  bool _sameContextSnapshot(
    DirectLlmConfiguration first,
    DirectLlmConfiguration second,
  ) =>
      first.contextSnapshotRevision == second.contextSnapshotRevision &&
      first.contextSnapshotHash == second.contextSnapshotHash;

  String _opaqueId(String prefix) =>
      '$prefix-${List<int>.generate(16, (_) => Random.secure().nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
}
