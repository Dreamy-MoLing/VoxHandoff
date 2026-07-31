import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/direct_chat.dart';
import '../infrastructure/chat/openai_compatible_chat_client.dart';
import '../infrastructure/security/direct_llm_secret_store.dart';
import '../infrastructure/security/flutter_secure_value_store.dart';
import 'client_session_controller.dart';
import 'speech_playback_controller.dart';

final directChatHistoryStoreProvider = Provider<DirectChatHistoryStore>(
  (_) => throw StateError('No direct chat history store is configured.'),
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
  });
  final DirectChatPhase phase;
  final DirectLlmConfiguration? configuration;
  final List<DirectChatMessage> messages;
  final DirectChatFailure? failure;
  final bool tested;
  bool get isConfigured => configuration?.isSafe ?? false;
  DirectChatState copyWith({
    DirectChatPhase? phase,
    DirectLlmConfiguration? configuration,
    List<DirectChatMessage>? messages,
    DirectChatFailure? failure,
    bool? tested,
    bool clearFailure = false,
  }) => DirectChatState(
    phase: phase ?? this.phase,
    configuration: configuration ?? this.configuration,
    messages: List.unmodifiable(messages ?? this.messages),
    failure: clearFailure ? null : failure ?? this.failure,
    tested: tested ?? this.tested,
  );
}

class DirectChatController extends Notifier<DirectChatState> {
  int _generation = 0;
  DirectChatTransport? _transport;

  @override
  DirectChatState build() {
    _transport = ref.watch(directChatTransportProvider);
    ref.onDispose(() => unawaited(_transport?.close() ?? Future<void>.value()));
    unawaited(_restore());
    return const DirectChatState();
  }

  Future<void> _restore() async {
    DirectLlmConfiguration? configuration;
    try {
      configuration = await ref
          .read(directChatConfigurationStoreProvider)
          .read();
    } on Object {
      return;
    }
    if (configuration == null || state.configuration != null) return;
    final messages = await ref
        .read(directChatHistoryStoreProvider)
        .list(configuration.id);
    state = DirectChatState(
      phase: DirectChatPhase.ready,
      configuration: configuration,
      messages: messages,
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
    if (apiKey.trim().isNotEmpty) {
      await ref
          .read(directChatSecretStoreProvider)
          .save(configuration.id, apiKey);
    }
    await ref.read(directChatConfigurationStoreProvider).save(configuration);
    final messages = await ref
        .read(directChatHistoryStoreProvider)
        .list(configuration.id);
    state = DirectChatState(
      phase: DirectChatPhase.ready,
      configuration: configuration,
      messages: messages,
    );
  }

  Future<void> testConnection() async {
    final configuration = state.configuration;
    if (configuration == null) return;
    final key = await ref
        .read(directChatSecretStoreProvider)
        .read(configuration.id);
    state = state.copyWith(phase: DirectChatPhase.testing, clearFailure: true);
    try {
      await _transport!.test(configuration, key ?? '');
      state = state.copyWith(phase: DirectChatPhase.ready, tested: true);
    } on DirectChatTransportException catch (error) {
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: DirectChatFailure(
          code: error.code,
          message: error.safeMessage,
        ),
      );
    }
  }

  Future<void> sendConfirmedText(String text) async {
    final configuration = state.configuration;
    if (configuration == null ||
        !configuration.isSafe ||
        state.phase == DirectChatPhase.sending) {
      return;
    }
    final apiKey = await ref
        .read(directChatSecretStoreProvider)
        .read(configuration.id);
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
    final previousMessages = state.messages;
    final now = DateTime.now().toUtc();
    final user = DirectChatMessage(
      id: _opaqueId('user'),
      role: DirectChatRole.user,
      text: text.trim(),
      createdAt: now,
    );
    final reply = DirectChatMessage(
      id: _opaqueId('reply'),
      role: DirectChatRole.assistant,
      text: '',
      createdAt: now,
      completed: false,
    );
    final store = ref.read(directChatHistoryStoreProvider);
    await store.upsert(configuration.id, user);
    await store.upsert(configuration.id, reply);
    state = state.copyWith(
      phase: DirectChatPhase.sending,
      messages: [...previousMessages, user, reply],
      clearFailure: true,
    );
    ref.read(clientSessionProvider.notifier).markAcceptedLocal();
    try {
      await for (final delta in _transport!.streamCompletion(
        configuration: configuration,
        apiKey: apiKey,
        messages: [...previousMessages, user],
      )) {
        if (generation != _generation) return;
        final current = state.messages
            .map(
              (message) => message.id == reply.id
                  ? message.copyWith(text: '${message.text}$delta')
                  : message,
            )
            .toList(growable: false);
        state = state.copyWith(messages: current);
        await store.upsert(configuration.id, current.last);
      }
      if (generation != _generation) return;
      final completed = state.messages
          .map(
            (message) => message.id == reply.id
                ? message.copyWith(completed: true)
                : message,
          )
          .toList(growable: false);
      state = state.copyWith(phase: DirectChatPhase.ready, messages: completed);
      final finalReply = completed.last;
      await store.upsert(configuration.id, finalReply);
      if (finalReply.text.trim().isNotEmpty) {
        await ref
            .read(speechPlaybackProvider.notifier)
            .speakCompletedReply(
              conversationId: 'local-${configuration.id}',
              requestId: reply.id,
              messageRevision: BigInt.one,
              fullReply: finalReply.text,
            );
      }
    } on DirectChatTransportException catch (error) {
      if (generation != _generation) return;
      await _completePartial(configuration.id, reply.id);
      state = state.copyWith(
        phase: DirectChatPhase.failed,
        failure: DirectChatFailure(
          code: error.code,
          message: error.safeMessage,
        ),
      );
    }
  }

  Future<void> cancel() async {
    if (state.phase != DirectChatPhase.sending) {
      return;
    }
    _generation += 1;
    await _transport!.cancel();
    final configuration = state.configuration;
    if (configuration != null) {
      final incomplete = state.messages
          .where((message) => !message.completed)
          .toList();
      for (final message in incomplete) {
        await ref
            .read(directChatHistoryStoreProvider)
            .upsert(configuration.id, message.copyWith(completed: true));
      }
      state = state.copyWith(
        phase: DirectChatPhase.cancelled,
        messages: state.messages
            .map(
              (message) => message.completed
                  ? message
                  : message.copyWith(completed: true),
            )
            .toList(),
      );
    }
  }

  Future<void> _completePartial(String providerId, String replyId) async {
    final messages = state.messages
        .map(
          (message) => message.id == replyId
              ? message.copyWith(completed: true)
              : message,
        )
        .toList(growable: false);
    state = state.copyWith(messages: messages);
    await ref
        .read(directChatHistoryStoreProvider)
        .upsert(providerId, messages.last);
  }
}

String _opaqueId(String prefix) =>
    '$prefix-${List<int>.generate(16, (_) => Random.secure().nextInt(256)).map((value) => value.toRadixString(16).padLeft(2, '0')).join()}';
