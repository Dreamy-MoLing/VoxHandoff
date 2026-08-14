part of 'direct_chat_controller.dart';

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
