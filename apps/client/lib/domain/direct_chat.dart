enum DirectChatRole { system, user, assistant }

class DirectChatMessage {
  const DirectChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.completed = true,
  });

  final String id;
  final DirectChatRole role;
  final String text;
  final DateTime createdAt;
  final bool completed;

  DirectChatMessage copyWith({String? text, bool? completed}) =>
      DirectChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        createdAt: createdAt,
        completed: completed ?? this.completed,
      );
}

/// A deliberately narrow OpenAI-compatible text source. It has no tools,
/// Agent host, approval, lease, or Gateway semantics.
class DirectLlmConfiguration {
  const DirectLlmConfiguration({
    required this.id,
    required this.origin,
    required this.model,
    this.systemPrompt = '',
  });

  final String id;
  final Uri origin;
  final String model;
  final String systemPrompt;

  bool get isSafe =>
      id.isNotEmpty &&
      model.trim().isNotEmpty &&
      origin.scheme == 'https' &&
      origin.host.isNotEmpty &&
      origin.userInfo.isEmpty &&
      (origin.path.isEmpty || origin.path == '/') &&
      !origin.hasQuery &&
      !origin.hasFragment;

  DirectLlmConfiguration copyWith({
    Uri? origin,
    String? model,
    String? systemPrompt,
  }) => DirectLlmConfiguration(
    id: id,
    origin: origin ?? this.origin,
    model: model ?? this.model,
    systemPrompt: systemPrompt ?? this.systemPrompt,
  );
}

enum DirectChatPhase {
  unconfigured,
  ready,
  testing,
  sending,
  cancelled,
  failed,
}

class DirectChatFailure {
  const DirectChatFailure({required this.code, required this.message});

  final String code;
  final String message;
}

abstract interface class DirectChatHistoryStore {
  Future<List<DirectChatMessage>> list(String providerId);
  Future<void> upsert(String providerId, DirectChatMessage message);
}
