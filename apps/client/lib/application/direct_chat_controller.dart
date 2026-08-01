import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/direct_context.dart';
import '../domain/direct_chat.dart';
import '../domain/confirmed_draft.dart';
import '../infrastructure/chat/openai_compatible_chat_client.dart';
import '../infrastructure/security/direct_llm_secret_store.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';
import 'client_session_controller.dart';
import 'speech_playback_controller.dart';

final directChatHistoryStoreProvider = Provider<DirectChatHistoryStore>(
  (_) => throw StateError('No direct chat history store is configured.'),
);
final directContextStoreProvider = Provider<DirectContextStore>(
  (_) => InMemoryDirectContextStore(),
);
final directContextBuilderProvider = Provider<DirectContextBuilder>(
  (_) => const DirectContextBuilder(),
);
final directChatSecretStoreProvider = Provider<DirectLlmSecretStore>(
  (_) => DirectLlmSecretStore(FlutterSecureValueStore()),
);
final directChatConfigurationStoreProvider =
    Provider<DirectLlmConfigurationStore>(
      (_) => DirectLlmConfigurationStore(FlutterSecureValueStore()),
    );
final directChatTransportProvider = Provider<DirectChatTransport>(
  (_) => OpenAiCompatibleChatTransport(),
);
final directChatProvider =
    NotifierProvider<DirectChatController, DirectChatState>(
      DirectChatController.new,
    );

class DirectChatState {
  const DirectChatState({
    this.phase = DirectChatPhase.unconfigured,
    this.configuration,
    this.messages = const [],
    this.failure,
    this.tested = false,
    this.assistantProfile,
    this.credentialAvailable = false,
  });
  final DirectChatPhase phase;
  final DirectLlmConfiguration? configuration;
  final List<DirectChatMessage> messages;
  final DirectChatFailure? failure;
  final bool tested;
  final AssistantProfile? assistantProfile;
  final bool credentialAvailable;
  bool get isConfigured =>
      (configuration?.isSafe ?? false) && credentialAvailable;
  DirectChatState copyWith({
    DirectChatPhase? phase,
    DirectLlmConfiguration? configuration,
    List<DirectChatMessage>? messages,
    DirectChatFailure? failure,
    bool? tested,
    AssistantProfile? assistantProfile,
    bool? credentialAvailable,
    bool clearFailure = false,
  }) => DirectChatState(
    phase: phase ?? this.phase,
    configuration: configuration ?? this.configuration,
    messages: List.unmodifiable(messages ?? this.messages),
    failure: clearFailure ? null : failure ?? this.failure,
    tested: tested ?? this.tested,
    assistantProfile: assistantProfile ?? this.assistantProfile,
    credentialAvailable: credentialAvailable ?? this.credentialAvailable,
  );
}

class DirectChatController extends Notifier<DirectChatState> {
  int _generation = 0;
  int _testGeneration = 0;
  String? _activeRequestId;
  DirectLlmConfiguration? _activeConfiguration;
  DirectChatTransport? _transport;

  @override
  DirectChatState build() {
    _transport = ref.watch(directChatTransportProvider);
    ref.onDispose(() {
      _generation += 1;
      _activeRequestId = null;
      _activeConfiguration = null;
      unawaited(_transport?.close() ?? Future<void>.value());
    });
    unawaited(_restore());
    return const DirectChatState();
  }

  Future<void> _restore() async {
    final configurationStore = ref.read(directChatConfigurationStoreProvider);
    AssistantProfile? defaultAssistant;
    try {
      defaultAssistant = await configurationStore
          .readOrCreateDefaultAssistant();
    } on Object {
      // Widget/unit tests and locked-down hosts may not expose secure storage.
      // Keep Direct unconfigured; never substitute a legacy secret.
      return;
    }
    DirectLlmConfiguration? configuration;
    try {
      configuration = await configurationStore.read();
    } on Object {
      return;
    }
    if (configuration == null) {
      state = state.copyWith(assistantProfile: defaultAssistant);
      return;
    }
    if (state.configuration != null) return;
    final messages = await ref
        .read(directChatHistoryStoreProvider)
        .list(configuration.conversationId);
    final key = await ref
        .read(directChatSecretStoreProvider)
        .read(
          configuration.profileId,
          credentialRevision: configuration.credentialRevision,
        );
    final restored = await _withCurrentContext(configuration, messages);
    await ref.read(directChatConfigurationStoreProvider).save(restored);
    state = DirectChatState(
      phase: key == null || key.isEmpty
          ? DirectChatPhase.failed
          : DirectChatPhase.ready,
      configuration: restored,
      messages: messages,
      assistantProfile: defaultAssistant,
      credentialAvailable: key != null && key.isNotEmpty,
      failure: key == null || key.isEmpty
          ? const DirectChatFailure(
              code: 'llm_key_missing',
              message:
                  'Save this LLM API key in secure storage before sending.',
            )
          : null,
    );
  }

  Future<void> configure(
    DirectLlmConfiguration configuration,
    String apiKey,
  ) async {
    if (!configuration.isSafe) {
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_configuration_invalid',
          message: 'Use a complete HTTPS LLM API configuration.',
        ),
      );
      return;
    }
    _testGeneration += 1;
    await cancelForContextChange();
    final current = state.configuration;
    final origin = normalizedProviderOrigin(configuration.origin);
    final currentOrigin = current == null
        ? null
        : normalizedProviderOrigin(current.origin);
    final identityChanged =
        current == null ||
        currentOrigin != origin ||
        current.authRealm != configuration.authRealm ||
        current.principal != configuration.principal;
    final assistantStore = ref.read(directChatConfigurationStoreProvider);
    final oldAssistant =
        state.assistantProfile ??
        current?.assistant ??
        await assistantStore.readOrCreateDefaultAssistant();
    final assistantChanged =
        current != null && current.systemPrompt != configuration.systemPrompt;
    final assistant = assistantChanged
        ? oldAssistant.copyWith(
            assistantRevision: oldAssistant.assistantRevision + 1,
            systemPrompt: configuration.systemPrompt,
          )
        : oldAssistant.systemPrompt == configuration.systemPrompt
        ? oldAssistant
        : oldAssistant.copyWith(systemPrompt: configuration.systemPrompt);
    await assistantStore.saveAssistant(assistant);
    final profileId = identityChanged
        ? _opaqueId('provider')
        : current.profileId;
    final credentialRevision = identityChanged
        ? 1
        : apiKey.trim().isNotEmpty
        ? current.credentialRevision + 1
        : current.credentialRevision;
    final configurationChanged =
        identityChanged || current.model != configuration.model;
    final configurationRevision = identityChanged
        ? 1
        : configurationChanged
        ? current.configurationRevision + 1
        : current.configurationRevision;
    final conversationId = identityChanged || configurationChanged
        ? _opaqueId('conversation')
        : current.conversationId;
    final active = DirectLlmConfiguration(
      providerProfileId: profileId,
      origin: configuration.origin,
      model: configuration.model,
      systemPrompt: assistant.systemPrompt,
      authRealm: configuration.authRealm,
      principal: configuration.principal,
      credentialRevision: credentialRevision,
      configurationRevision: configurationRevision,
      conversationId: conversationId,
      assistantId: assistant.assistantId,
      assistantRevision: assistant.assistantRevision,
      contextSnapshotRevision: 0,
      contextSnapshotHash: ConfirmedDraft.contextHash(const []),
    );
    if (apiKey.trim().isNotEmpty) {
      await ref
          .read(directChatSecretStoreProvider)
          .save(
            active.profileId,
            apiKey,
            credentialRevision: active.credentialRevision,
          );
      if (configuration.id != null) {
        await ref
            .read(directChatSecretStoreProvider)
            .deleteLegacy(configuration.id!);
      }
      if (current != null &&
          (identityChanged ||
              current.credentialRevision != active.credentialRevision)) {
        await ref
            .read(directChatSecretStoreProvider)
            .delete(
              current.profileId,
              credentialRevision: current.credentialRevision,
            );
      }
    }
    await assistantStore.save(active);
    final storedKey = await ref
        .read(directChatSecretStoreProvider)
        .read(active.profileId, credentialRevision: active.credentialRevision);
    final messages = await ref
        .read(directChatHistoryStoreProvider)
        .list(active.conversationId);
    final activeWithContext = await _withCurrentContext(active, messages);
    await assistantStore.save(activeWithContext);
    final confirmed = ref.read(clientSessionProvider).confirmedDraft;
    if (confirmed != null &&
        (confirmed.target is! DirectTargetSnapshot ||
            !confirmed.target.matches(_directTarget(activeWithContext)) ||
            confirmed.assistantId != activeWithContext.assistantId ||
            confirmed.assistantRevision !=
                activeWithContext.assistantRevision ||
            confirmed.contextSnapshotRevision !=
                activeWithContext.contextSnapshotRevision ||
            confirmed.contextSnapshotHash !=
                activeWithContext.contextSnapshotHash)) {
      ref.read(clientSessionProvider.notifier).invalidateConfirmation();
    }
    state = DirectChatState(
      phase: storedKey == null || storedKey.isEmpty
          ? DirectChatPhase.failed
          : DirectChatPhase.ready,
      configuration: activeWithContext,
      messages: messages,
      assistantProfile: assistant,
      credentialAvailable: storedKey != null && storedKey.isNotEmpty,
      failure: storedKey == null || storedKey.isEmpty
          ? DirectChatFailure(
              code: identityChanged
                  ? 'llm_key_required_for_new_profile'
                  : 'llm_key_missing',
              message: identityChanged
                  ? 'Enter a new API key for this exact provider identity.'
                  : 'Save this LLM API key in secure storage before sending.',
            )
          : null,
    );
  }

  Future<void> testConnection() async {
    if (state.phase == DirectChatPhase.sending ||
        state.phase == DirectChatPhase.testing) {
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_request_busy',
          message: 'Finish or cancel the active LLM request before testing.',
        ),
      );
      return;
    }
    final configuration = state.configuration;
    if (configuration == null) return;
    final key = await ref
        .read(directChatSecretStoreProvider)
        .read(
          configuration.profileId,
          credentialRevision: configuration.credentialRevision,
        );
    if (key == null || key.isEmpty) {
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        credentialAvailable: false,
        failure: const DirectChatFailure(
          code: 'llm_key_missing',
          message: 'Save this LLM API key in secure storage before testing.',
        ),
      );
      return;
    }
    final testGeneration = ++_testGeneration;
    state = state.copyWith(phase: DirectChatPhase.testing, clearFailure: true);
    try {
      await _transport!.test(configuration, key);
      if (testGeneration != _testGeneration ||
          state.configuration != configuration) {
        return;
      }
      state = state.copyWith(phase: DirectChatPhase.ready, tested: true);
    } on DirectChatTransportException catch (error) {
      if (testGeneration != _testGeneration ||
          state.configuration != configuration) {
        return;
      }
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: DirectChatFailure(
          code: error.code,
          message: error.safeMessage,
        ),
      );
    } on Object {
      if (testGeneration != _testGeneration ||
          state.configuration != configuration) {
        return;
      }
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_connection_failed',
          message: 'The LLM API could not be reached securely.',
        ),
      );
    }
  }

  Future<void> sendConfirmedText(ConfirmedDraft draft) async {
    final configuration = state.configuration;
    if (configuration == null ||
        !configuration.isSafe ||
        state.phase == DirectChatPhase.sending) {
      return;
    }
    if (draft.chatSource != ChatSource.directLlm ||
        !_draftMatchesConfiguration(draft, configuration)) {
      ref.read(clientSessionProvider.notifier).invalidateConfirmation();
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_confirmation_stale',
          message:
              'The confirmed Direct target changed. Confirm the draft again.',
        ),
      );
      return;
    }
    if (!state.credentialAvailable) {
      final failure = state.failure?.code == 'llm_key_required_for_new_profile'
          ? state.failure!
          : const DirectChatFailure(
              code: 'llm_key_missing',
              message:
                  'Save this LLM API key in secure storage before sending.',
            );
      state = state.copyWith(phase: DirectChatPhase.failed, failure: failure);
      return;
    }
    final apiKey = await ref
        .read(directChatSecretStoreProvider)
        .read(
          configuration.profileId,
          credentialRevision: configuration.credentialRevision,
        );
    if (apiKey == null || apiKey.isEmpty) {
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_key_missing',
          message: 'Save this LLM API key in secure storage before sending.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    final requestId = _opaqueId('request');
    _activeRequestId = requestId;
    _activeConfiguration = configuration;
    final previousMessages = state.messages;
    final now = DateTime.now().toUtc();
    final user = DirectChatMessage(
      id: _opaqueId('user'),
      role: DirectChatRole.user,
      text: draft.confirmedText,
      createdAt: now,
      terminal: DirectMessageTerminal.completed,
    );
    final reply = DirectChatMessage(
      id: _opaqueId('reply'),
      role: DirectChatRole.assistant,
      text: '',
      createdAt: now,
      terminal: DirectMessageTerminal.streaming,
    );
    final contextConfiguration = await _withCurrentContext(
      configuration,
      previousMessages,
    );
    if (!_sameContextSnapshot(configuration, contextConfiguration)) {
      state = state.copyWith(configuration: contextConfiguration);
      await ref
          .read(directChatConfigurationStoreProvider)
          .save(contextConfiguration);
      ref.read(clientSessionProvider.notifier).invalidateConfirmation();
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_context_changed',
          message: 'Conversation context changed. Confirm the draft again.',
        ),
      );
      _releaseRequest(requestId);
      return;
    }
    final contextData = await ref
        .read(directContextStoreProvider)
        .read(configuration.conversationId);
    late final DirectContextAssembly assembly;
    try {
      assembly = ref
          .read(directContextBuilderProvider)
          .assemble(
            configuration: configuration,
            history: previousMessages,
            currentUser: user,
            data: contextData,
          );
    } on DirectContextException catch (error) {
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: DirectChatFailure(
          code: error.code,
          message: error.safeMessage,
        ),
      );
      _releaseRequest(requestId);
      return;
    }
    final store = ref.read(directChatHistoryStoreProvider);
    await store.upsert(configuration.conversationId, user);
    await store.upsert(configuration.conversationId, reply);
    state = state.copyWith(
      phase: DirectChatPhase.sending,
      messages: [...previousMessages, user, reply],
      clearFailure: true,
    );
    ref.read(clientSessionProvider.notifier).markAcceptedLocal();
    var lastPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final delta in _transport!.streamCompletion(
        configuration: configuration,
        apiKey: apiKey,
        messages: assembly.messages,
      )) {
        if (!_ownsRequest(generation, requestId, configuration)) return;
        final current = state.messages
            .map(
              (message) => message.id == reply.id
                  ? message.copyWith(text: '${message.text}$delta')
                  : message,
            )
            .toList(growable: false);
        state = state.copyWith(messages: current);
        final now = DateTime.now();
        if (now.difference(lastPersistedAt) >=
            const Duration(milliseconds: 250)) {
          await store.upsert(configuration.conversationId, current.last);
          lastPersistedAt = now;
        }
      }
      if (!_ownsRequest(generation, requestId, configuration)) return;
      final completed = state.messages
          .map(
            (message) => message.id == reply.id
                ? message.copyWith(terminal: DirectMessageTerminal.completed)
                : message,
          )
          .toList(growable: false);
      state = state.copyWith(phase: DirectChatPhase.ready, messages: completed);
      final finalReply = completed.last;
      await store.upsert(configuration.conversationId, finalReply);
      _releaseRequest(requestId);
      final updatedConfiguration = configuration.copyWith(
        contextSnapshotRevision: configuration.contextSnapshotRevision + 1,
        contextSnapshotHash: directContextHash(contextData, completed),
      );
      await ref
          .read(directChatConfigurationStoreProvider)
          .save(updatedConfiguration);
      state = state.copyWith(configuration: updatedConfiguration);
      if (_isCurrentConfiguration(configuration) &&
          state.assistantProfile?.speechPolicy ==
              AssistantSpeechPolicy.afterCompleted &&
          finalReply.text.trim().isNotEmpty) {
        await ref
            .read(speechPlaybackProvider.notifier)
            .speakCompletedReply(
              conversationId: configuration.conversationId,
              requestId: reply.id,
              messageRevision: BigInt.one,
              fullReply: finalReply.text,
            );
      }
    } on DirectChatTransportException catch (error) {
      if (!_ownsRequest(generation, requestId, configuration)) return;
      await _completePartial(
        configuration.conversationId,
        reply.id,
        code: error.code,
      );
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: DirectChatFailure(
          code: error.code,
          message: error.safeMessage,
        ),
      );
      _releaseRequest(requestId);
    } on Object {
      if (!_ownsRequest(generation, requestId, configuration)) return;
      await _completePartial(
        configuration.conversationId,
        reply.id,
        code: 'llm_stream_failed',
      );
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: const DirectChatFailure(
          code: 'llm_stream_failed',
          message: 'The LLM response stopped before completion.',
        ),
      );
      _releaseRequest(requestId);
    }
  }

  Future<void> cancel() async {
    if (state.phase != DirectChatPhase.sending) {
      return;
    }
    _generation += 1;
    _activeRequestId = null;
    _activeConfiguration = null;
    await _transport!.cancel();
    await ref.read(speechPlaybackProvider.notifier).stopSpeech();
    final configuration = state.configuration;
    if (configuration != null) {
      final incomplete = state.messages
          .where(
            (message) => message.terminal == DirectMessageTerminal.streaming,
          )
          .toList();
      for (final message in incomplete) {
        await ref
            .read(directChatHistoryStoreProvider)
            .upsert(
              configuration.conversationId,
              message.copyWith(terminal: DirectMessageTerminal.cancelled),
            );
      }
      state = state.copyWith(
        phase: DirectChatPhase.cancelled,
        messages: state.messages
            .map(
              (message) => message.terminal != DirectMessageTerminal.streaming
                  ? message
                  : message.copyWith(terminal: DirectMessageTerminal.cancelled),
            )
            .toList(),
      );
    }
  }

  /// Cancels local work before a source, profile, configuration or conversation
  /// becomes active. The generation increment is the stale-result barrier;
  /// awaiting transport cancellation completes the terminal write barrier.
  Future<void> cancelForContextChange() async {
    if (state.phase == DirectChatPhase.sending) {
      await cancel();
    } else {
      await ref.read(speechPlaybackProvider.notifier).stopSpeech();
    }
  }

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
