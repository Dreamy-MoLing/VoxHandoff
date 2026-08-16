import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/confirmed_draft.dart';
import '../domain/direct_chat.dart';
import '../domain/hermes_conversation.dart';
import '../infrastructure/chat/hermes_chat_client.dart';
import '../infrastructure/chat/hermes_session_client.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';
import '../infrastructure/security/hermes_conversation_secret_store.dart';
import 'client_session_controller.dart';

final hermesConversationHistoryStoreProvider =
    Provider<HermesConversationHistoryStore>(
      (_) => throw StateError(
        'No Hermes conversation history store is configured.',
      ),
    );

final hermesConversationSecretStoreProvider =
    Provider<HermesConversationSecretStore>(
      (_) => HermesConversationSecretStore(FlutterSecureValueStore()),
    );

final hermesConversationConfigurationStoreProvider =
    Provider<HermesConversationConfigurationStore>(
      (_) => HermesConversationConfigurationStore(FlutterSecureValueStore()),
    );

final hermesConversationTransportProvider = Provider<HermesChatTransport>(
  (_) => HermesChatHttpTransport(),
);

final hermesSessionClientProvider = Provider<HermesSessionClient>(
  (_) => HermesSessionClient(),
);

final hermesConversationProvider =
    NotifierProvider<HermesConversationController, HermesConversationState>(
      HermesConversationController.new,
    );

enum HermesConversationPhase {
  unconfigured,
  restoring,
  bootstrapping,
  ready,
  testing,
  sending,
  cancelled,
  failed,
}

class HermesConversationFailure {
  const HermesConversationFailure({
    required this.code,
    required this.message,
    this.stage = HermesChatFailureStage.connection,
    this.statusCode,
  });

  final String code;
  final String message;
  final HermesChatFailureStage stage;
  final int? statusCode;
}

class HermesConversationState {
  const HermesConversationState({
    this.phase = HermesConversationPhase.unconfigured,
    this.configuration,
    this.messages = const [],
    this.failure,
    this.tested = false,
    this.credentialAvailable = false,
    this.sessionBootstrapFallback = false,
    this.toolProgress,
  });

  final HermesConversationPhase phase;
  final HermesConversationConfiguration? configuration;
  final List<DirectChatMessage> messages;
  final HermesConversationFailure? failure;
  final bool tested;
  final bool credentialAvailable;
  final bool sessionBootstrapFallback;
  final String? toolProgress;

  bool get isConfigured =>
      (configuration?.isSafe ?? false) && credentialAvailable;

  HermesConversationState copyWith({
    HermesConversationPhase? phase,
    HermesConversationConfiguration? configuration,
    List<DirectChatMessage>? messages,
    HermesConversationFailure? failure,
    bool? tested,
    bool? credentialAvailable,
    bool? sessionBootstrapFallback,
    String? toolProgress,
    bool clearFailure = false,
    bool clearToolProgress = false,
  }) => HermesConversationState(
    phase: phase ?? this.phase,
    configuration: configuration ?? this.configuration,
    messages: List.unmodifiable(messages ?? this.messages),
    failure: clearFailure ? null : failure ?? this.failure,
    tested: tested ?? this.tested,
    credentialAvailable: credentialAvailable ?? this.credentialAvailable,
    sessionBootstrapFallback:
        sessionBootstrapFallback ?? this.sessionBootstrapFallback,
    toolProgress: clearToolProgress ? null : toolProgress ?? this.toolProgress,
  );
}

class HermesConversationController extends Notifier<HermesConversationState> {
  int _generation = 0;
  int _testGeneration = 0;
  String? _activeRequestId;
  HermesConversationConfiguration? _activeConfiguration;
  HermesChatTransport? _transport;
  HermesSessionClient? _sessions;
  var _configuredExplicitly = false;

  @override
  HermesConversationState build() {
    _transport = ref.watch(hermesConversationTransportProvider);
    _sessions = ref.watch(hermesSessionClientProvider);
    ref.onDispose(() {
      _generation += 1;
      _activeRequestId = null;
      _activeConfiguration = null;
      unawaited(_transport?.close() ?? Future<void>.value());
      unawaited(_sessions?.close() ?? Future<void>.value());
    });
    unawaited(_restore());
    return const HermesConversationState();
  }

  Future<void> _restore() async {
    final configurationStore = ref.read(
      hermesConversationConfigurationStoreProvider,
    );
    HermesConversationConfiguration? configuration;
    try {
      configuration = await configurationStore.read();
    } on Object {
      return;
    }
    if (_configuredExplicitly || configuration == null) return;
    final history = ref.read(hermesConversationHistoryStoreProvider);
    final messages = await history.list(configuration.conversationId);
    final key = await ref
        .read(hermesConversationSecretStoreProvider)
        .read(
          configuration.providerProfileId,
          credentialRevision: configuration.credentialRevision,
        );
    if (_configuredExplicitly) return;
    if (key == null || key.isEmpty) {
      state = HermesConversationState(
        phase: HermesConversationPhase.failed,
        configuration: configuration,
        messages: messages,
        credentialAvailable: false,
        failure: const HermesConversationFailure(
          code: 'hermes_key_missing',
          message: 'Save the Hermes API key in secure storage before sending.',
        ),
      );
      return;
    }
    state = HermesConversationState(
      phase: HermesConversationPhase.restoring,
      configuration: configuration,
      messages: messages,
      credentialAvailable: true,
    );
    try {
      final restored = await _sessions!.restore(configuration, key);
      final withSession = await _withContext(
        configuration.sessionId == restored.effectiveSessionId
            ? configuration
            : configuration.copyWith(
                sessionId: restored.effectiveSessionId,
                configurationRevision: configuration.configurationRevision + 1,
              ),
        restored.messages,
      );
      await history.replace(configuration.conversationId, restored.messages);
      await configurationStore.save(withSession);
      if (_configuredExplicitly) return;
      state = HermesConversationState(
        phase: HermesConversationPhase.ready,
        configuration: withSession,
        messages: restored.messages,
        credentialAvailable: true,
      );
    } on HermesChatTransportException catch (error) {
      if (_configuredExplicitly) return;
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        failure: _failure(error),
      );
    } on Object {
      if (_configuredExplicitly) return;
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        failure: const HermesConversationFailure(
          code: 'hermes_session_restore_failed',
          message: 'Hermes conversation history could not be restored.',
        ),
      );
    }
  }

  Future<void> configure(
    HermesConversationConfiguration requested,
    String apiKey,
  ) async {
    _configuredExplicitly = true;
    if (!requested.isSafe) {
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        failure: const HermesConversationFailure(
          code: 'hermes_configuration_invalid',
          message: 'Use a complete HTTPS Hermes conversation configuration.',
          stage: HermesChatFailureStage.configuration,
        ),
      );
      return;
    }
    _testGeneration += 1;
    await cancelForContextChange();
    final current = state.configuration;
    final identityChanged =
        current == null ||
        current.normalizedOrigin != requested.normalizedOrigin ||
        current.model != requested.model;
    final keyChanged = apiKey.trim().isNotEmpty;
    final active = HermesConversationConfiguration(
      providerProfileId: identityChanged
          ? _opaqueId('hermes-provider')
          : current.providerProfileId,
      origin: requested.origin,
      model: requested.model,
      conversationId: identityChanged
          ? _opaqueId('hermes-conversation')
          : current.conversationId,
      sessionId: identityChanged
          ? _opaqueId('hermes-session')
          : current.sessionId,
      sessionKey: identityChanged
          ? _opaqueId('hermes-scope')
          : current.sessionKey,
      credentialRevision: identityChanged
          ? 1
          : keyChanged
          ? current.credentialRevision + 1
          : current.credentialRevision,
      configurationRevision: identityChanged
          ? 1
          : current.configurationRevision,
      contextSnapshotRevision: 0,
      contextSnapshotHash: ConfirmedDraft.contextHash(const []),
      sessionIdPolicy: requested.sessionIdPolicy,
    );
    final secrets = ref.read(hermesConversationSecretStoreProvider);
    if (keyChanged) {
      await secrets.save(
        active.providerProfileId,
        apiKey,
        credentialRevision: active.credentialRevision,
      );
      if (current != null &&
          current.providerProfileId != active.providerProfileId) {
        await secrets.delete(
          current.providerProfileId,
          credentialRevision: current.credentialRevision,
        );
      }
    }
    final storedKey = await secrets.read(
      active.providerProfileId,
      credentialRevision: active.credentialRevision,
    );
    final history = ref.read(hermesConversationHistoryStoreProvider);
    final localMessages = await history.list(active.conversationId);
    var withContext = await _withContext(active, localMessages);
    await ref
        .read(hermesConversationConfigurationStoreProvider)
        .save(withContext);
    if (storedKey == null || storedKey.isEmpty) {
      state = HermesConversationState(
        phase: HermesConversationPhase.failed,
        configuration: withContext,
        messages: localMessages,
        credentialAvailable: false,
        failure: const HermesConversationFailure(
          code: 'hermes_key_required_for_new_profile',
          message: 'Enter a Hermes API key for this exact endpoint/profile.',
        ),
      );
      return;
    }
    var bootstrapFallback = false;
    if (identityChanged &&
        requested.sessionIdPolicy == HermesSessionIdPolicy.bootstrapPreferred) {
      state = HermesConversationState(
        phase: HermesConversationPhase.bootstrapping,
        configuration: withContext,
        messages: localMessages,
        credentialAvailable: true,
      );
      try {
        final bootstrap = await _sessions!.bootstrap(withContext, storedKey);
        if (bootstrap.sessionId != withContext.sessionId) {
          withContext = withContext.copyWith(
            sessionId: bootstrap.sessionId,
            configurationRevision: withContext.configurationRevision + 1,
          );
          await ref
              .read(hermesConversationConfigurationStoreProvider)
              .save(withContext);
        }
      } on HermesChatTransportException {
        // The generated opaque session ID is the explicit, stable fallback for
        // first-turn Chat Completions persistence. Do not silently retry POST.
        bootstrapFallback = true;
      }
    }
    state = HermesConversationState(
      phase: HermesConversationPhase.ready,
      configuration: withContext,
      messages: localMessages,
      credentialAvailable: true,
      sessionBootstrapFallback: bootstrapFallback,
    );
  }

  Future<void> testConnection() async {
    final configuration = state.configuration;
    if (configuration == null) return;
    if (state.phase == HermesConversationPhase.sending ||
        state.phase == HermesConversationPhase.testing) {
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        failure: const HermesConversationFailure(
          code: 'hermes_request_busy',
          message: 'Finish or cancel the active Hermes request before testing.',
        ),
      );
      return;
    }
    final key = await ref
        .read(hermesConversationSecretStoreProvider)
        .read(
          configuration.providerProfileId,
          credentialRevision: configuration.credentialRevision,
        );
    if (key == null || key.isEmpty) {
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        credentialAvailable: false,
        failure: const HermesConversationFailure(
          code: 'hermes_key_missing',
          message: 'Save the Hermes API key in secure storage before testing.',
        ),
      );
      return;
    }
    final generation = ++_testGeneration;
    state = state.copyWith(
      phase: HermesConversationPhase.testing,
      clearFailure: true,
    );
    try {
      await _transport!.test(configuration, key);
      if (generation != _testGeneration ||
          state.configuration != configuration) {
        return;
      }
      state = state.copyWith(
        phase: HermesConversationPhase.ready,
        tested: true,
      );
    } on HermesChatTransportException catch (error) {
      if (generation != _testGeneration ||
          state.configuration != configuration) {
        return;
      }
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        failure: _failure(error),
      );
    }
  }

  Future<void> sendConfirmedText(ConfirmedDraft draft) async {
    final configuration = state.configuration;
    if (configuration == null ||
        !configuration.isSafe ||
        state.phase == HermesConversationPhase.sending ||
        draft.chatSource != ChatSource.hermesConversation ||
        !_draftMatchesConfiguration(draft, configuration)) {
      return;
    }
    final key = await ref
        .read(hermesConversationSecretStoreProvider)
        .read(
          configuration.providerProfileId,
          credentialRevision: configuration.credentialRevision,
        );
    if (key == null || key.isEmpty) {
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        credentialAvailable: false,
        failure: const HermesConversationFailure(
          code: 'hermes_key_missing',
          message: 'Save the Hermes API key in secure storage before sending.',
        ),
      );
      return;
    }
    final generation = ++_generation;
    final requestId = _opaqueId('hermes-request');
    _activeRequestId = requestId;
    _activeConfiguration = configuration;
    final previous = state.messages;
    final now = DateTime.now().toUtc();
    final user = DirectChatMessage(
      id: _opaqueId('hermes-user'),
      role: DirectChatRole.user,
      text: draft.confirmedText,
      createdAt: now,
    );
    final reply = DirectChatMessage(
      id: _opaqueId('hermes-reply'),
      role: DirectChatRole.assistant,
      text: '',
      createdAt: now,
      terminal: DirectMessageTerminal.streaming,
    );
    final history = ref.read(hermesConversationHistoryStoreProvider);
    await history.upsert(configuration.conversationId, user);
    await history.upsert(configuration.conversationId, reply);
    state = state.copyWith(
      phase: HermesConversationPhase.sending,
      messages: [...previous, user, reply],
      clearFailure: true,
      clearToolProgress: true,
    );
    ref.read(clientSessionProvider.notifier).markAcceptedLocal();
    var lastPersistedAt = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      await for (final event in _transport!.streamCompletion(
        configuration: configuration,
        apiKey: key,
        userText: draft.confirmedText,
      )) {
        if (!_ownsRequest(generation, requestId, configuration)) return;
        if (event case HermesToolProgressEvent(:final message)) {
          state = state.copyWith(toolProgress: message);
          continue;
        }
        if (event case HermesChatTextDeltaEvent(:final text)) {
          final current = _replaceReply(reply.id, text: text, append: true);
          state = state.copyWith(messages: current);
          final now = DateTime.now();
          if (now.difference(lastPersistedAt) >=
              const Duration(milliseconds: 250)) {
            await history.upsert(configuration.conversationId, current.last);
            lastPersistedAt = now;
          }
          continue;
        }
        if (event case HermesChatTerminalEvent(:final terminal)) {
          final current = _replaceReply(reply.id, terminal: terminal.terminal);
          state = state.copyWith(messages: current, clearToolProgress: true);
          await history.upsert(configuration.conversationId, current.last);
          var updatedConfiguration = configuration;
          if (terminal.effectiveSessionId != null &&
              terminal.effectiveSessionId != configuration.sessionId) {
            updatedConfiguration = configuration.copyWith(
              sessionId: terminal.effectiveSessionId,
              configurationRevision: configuration.configurationRevision + 1,
            );
          }
          if (terminal.terminal == DirectMessageTerminal.completed) {
            updatedConfiguration = await _withContext(
              updatedConfiguration,
              current,
            );
            state = state.copyWith(
              phase: HermesConversationPhase.ready,
              configuration: updatedConfiguration,
            );
            await ref
                .read(hermesConversationConfigurationStoreProvider)
                .save(updatedConfiguration);
          } else {
            state = state.copyWith(
              phase: terminal.terminal == DirectMessageTerminal.cancelled
                  ? HermesConversationPhase.cancelled
                  : HermesConversationPhase.failed,
              configuration: updatedConfiguration,
              failure: HermesConversationFailure(
                code: terminal.errorCode ?? _terminalCode(terminal.terminal),
                message: _terminalMessage(terminal.terminal),
                stage: HermesChatFailureStage.terminal,
              ),
            );
            if (updatedConfiguration != configuration) {
              await ref
                  .read(hermesConversationConfigurationStoreProvider)
                  .save(updatedConfiguration);
            }
          }
          _releaseRequest(requestId);
        }
      }
    } on HermesChatTransportException catch (error) {
      if (!_ownsRequest(generation, requestId, configuration)) return;
      final terminal = _terminalFor(error.code, reply.text);
      final current = _replaceReply(reply.id, terminal: terminal);
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        messages: current,
        failure: _failure(error),
        clearToolProgress: true,
      );
      await history.upsert(configuration.conversationId, current.last);
      _releaseRequest(requestId);
    } on Object {
      if (!_ownsRequest(generation, requestId, configuration)) return;
      final current = _replaceReply(
        reply.id,
        terminal: _terminalFor('hermes_stream_failed', reply.text),
      );
      state = state.copyWith(
        phase: HermesConversationPhase.failed,
        messages: current,
        failure: const HermesConversationFailure(
          code: 'hermes_stream_failed',
          message: 'The Hermes response stopped before completion.',
        ),
        clearToolProgress: true,
      );
      await history.upsert(configuration.conversationId, current.last);
      _releaseRequest(requestId);
    }
  }

  Future<void> cancel() async {
    if (state.phase != HermesConversationPhase.sending) return;
    _generation += 1;
    final requestId = _activeRequestId;
    final configuration = _activeConfiguration;
    _activeRequestId = null;
    _activeConfiguration = null;
    await _transport?.cancel();
    if (requestId == null || configuration == null) return;
    final current = state.messages
        .map(
          (message) =>
              message.role == DirectChatRole.assistant &&
                  message.terminal == DirectMessageTerminal.streaming
              ? message.copyWith(terminal: DirectMessageTerminal.cancelled)
              : message,
        )
        .toList(growable: false);
    state = state.copyWith(
      phase: HermesConversationPhase.cancelled,
      messages: current,
      clearToolProgress: true,
    );
    await ref
        .read(hermesConversationHistoryStoreProvider)
        .upsert(configuration.conversationId, current.last);
  }

  Future<void> cancelForContextChange() async {
    if (state.phase == HermesConversationPhase.sending) {
      await cancel();
    }
  }

  bool _draftMatchesConfiguration(
    ConfirmedDraft draft,
    HermesConversationConfiguration configuration,
  ) {
    final target = draft.target;
    return target is HermesConversationTargetSnapshot &&
        target.conversationId == configuration.conversationId &&
        target.providerProfileId == configuration.providerProfileId &&
        target.credentialRevision == configuration.credentialRevision &&
        target.configurationRevision == configuration.configurationRevision &&
        target.normalizedOrigin == configuration.normalizedOrigin &&
        target.model == configuration.model &&
        target.sessionId == configuration.sessionId &&
        target.sessionKey == configuration.sessionKey &&
        draft.contextSnapshotRevision ==
            configuration.contextSnapshotRevision &&
        draft.contextSnapshotHash == configuration.contextSnapshotHash;
  }

  List<DirectChatMessage> _replaceReply(
    String replyId, {
    String? text,
    bool append = false,
    DirectMessageTerminal? terminal,
  }) => state.messages
      .map(
        (message) => message.id == replyId
            ? message.copyWith(
                text: append ? '${message.text}${text ?? ''}' : text,
                terminal: terminal,
              )
            : message,
      )
      .toList(growable: false);

  Future<HermesConversationConfiguration> _withContext(
    HermesConversationConfiguration configuration,
    List<DirectChatMessage> messages,
  ) async {
    final hash = ConfirmedDraft.contextHash(
      messages
          .where((message) => message.contextEligible)
          .map(
            (message) => '${message.id}:${message.revision}:${message.text}',
          ),
    );
    return configuration.copyWith(
      contextSnapshotRevision: configuration.contextSnapshotHash == hash
          ? configuration.contextSnapshotRevision
          : configuration.contextSnapshotRevision + 1,
      contextSnapshotHash: hash,
    );
  }

  bool _ownsRequest(
    int generation,
    String requestId,
    HermesConversationConfiguration configuration,
  ) =>
      generation == _generation &&
      _activeRequestId == requestId &&
      identical(_activeConfiguration, configuration);

  void _releaseRequest(String requestId) {
    if (_activeRequestId == requestId) {
      _activeRequestId = null;
      _activeConfiguration = null;
    }
  }

  HermesConversationFailure _failure(HermesChatTransportException error) =>
      HermesConversationFailure(
        code: error.code,
        message: error.safeMessage,
        stage: error.stage,
        statusCode: error.statusCode,
      );

  DirectMessageTerminal _terminalFor(String code, String text) {
    if (code == 'hermes_stream_too_large' ||
        code == 'hermes_response_too_large') {
      return DirectMessageTerminal.truncated;
    }
    return text.trim().isEmpty
        ? DirectMessageTerminal.failed
        : DirectMessageTerminal.incomplete;
  }

  String _terminalCode(DirectMessageTerminal terminal) => switch (terminal) {
    DirectMessageTerminal.cancelled => 'hermes_cancelled',
    DirectMessageTerminal.failed => 'hermes_terminal_failed',
    DirectMessageTerminal.incomplete => 'hermes_partial_response',
    DirectMessageTerminal.truncated => 'hermes_response_truncated',
    _ => 'hermes_terminal_invalid',
  };

  String _terminalMessage(DirectMessageTerminal terminal) => switch (terminal) {
    DirectMessageTerminal.cancelled => 'The Hermes response was cancelled.',
    DirectMessageTerminal.failed => 'Hermes reported a failed response.',
    DirectMessageTerminal.incomplete =>
      'Hermes returned a partial response; it was not used as context.',
    DirectMessageTerminal.truncated =>
      'The Hermes response exceeded the safe size limit.',
    _ => 'The Hermes response did not reach a valid terminal state.',
  };

  String _opaqueId(String prefix) =>
      '$prefix-${List<int>.generate(16, (_) => Random.secure().nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
}
