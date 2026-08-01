import 'confirmed_draft.dart';

enum DirectChatRole { system, user, assistant }

enum DirectMessageTerminal {
  streaming,
  completed,
  cancelled,
  failed,
  incomplete,
  truncated,
}

enum DirectMessageProvenance { native, legacyUnverified }

extension DirectMessageProvenanceStorage on DirectMessageProvenance {
  String get storageName => switch (this) {
    DirectMessageProvenance.native => 'native',
    DirectMessageProvenance.legacyUnverified => 'legacy_unverified',
  };
}

class DirectChatMessage {
  DirectChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.terminal = DirectMessageTerminal.completed,
    this.provenance = DirectMessageProvenance.native,
    this.revision = 1,
    this.contextEligibleOverride,
  }) {
    if (id.trim().isEmpty || revision < 1) {
      throw const FormatException('The direct chat message is invalid.');
    }
  }

  final String id;
  final DirectChatRole role;
  final String text;
  final DateTime createdAt;
  final DirectMessageTerminal terminal;
  final DirectMessageProvenance provenance;
  final int revision;
  final bool? contextEligibleOverride;

  bool get contextEligible =>
      contextEligibleOverride ??
      (role != DirectChatRole.assistant ||
          (terminal == DirectMessageTerminal.completed &&
              provenance == DirectMessageProvenance.native));

  DirectChatMessage copyWith({
    String? text,
    DirectMessageTerminal? terminal,
    DirectMessageProvenance? provenance,
    int? revision,
    bool? contextEligibleOverride,
  }) => DirectChatMessage(
    id: id,
    role: role,
    text: text ?? this.text,
    createdAt: createdAt,
    terminal: terminal ?? this.terminal,
    provenance: provenance ?? this.provenance,
    revision: revision ?? this.revision + 1,
    contextEligibleOverride:
        contextEligibleOverride ?? this.contextEligibleOverride,
  );
}

enum AssistantMemoryPolicy { localOnly, disabled }

enum AssistantSpeechPolicy { off, manual, afterCompleted }

enum AssistantCapability {
  chat,
  agent,
  tools,
  approvals,
  leases,
  interrupt,
  clarifications,
}

class AssistantProfile {
  const AssistantProfile({
    required this.assistantId,
    required this.assistantRevision,
    required this.systemPrompt,
    this.displayName = 'VoxHandoff',
    this.persona = '',
    this.memoryPolicy = AssistantMemoryPolicy.localOnly,
    this.voiceProfileId = 'default-voice',
    this.signalCoreProfile = 'signal-core',
    this.defaultChatSource = ChatSource.directLlm,
    this.hermesWorkBackend = 'hermes-gateway',
    this.speechPolicy = AssistantSpeechPolicy.afterCompleted,
  });

  final String assistantId;
  final int assistantRevision;
  final String systemPrompt;
  final String displayName;
  final String persona;
  final AssistantMemoryPolicy memoryPolicy;
  final String voiceProfileId;
  final String signalCoreProfile;
  final ChatSource defaultChatSource;
  final String hermesWorkBackend;
  final AssistantSpeechPolicy speechPolicy;

  AssistantProfile copyWith({
    int? assistantRevision,
    String? systemPrompt,
    String? displayName,
    String? persona,
    AssistantMemoryPolicy? memoryPolicy,
    String? voiceProfileId,
    String? signalCoreProfile,
    ChatSource? defaultChatSource,
    String? hermesWorkBackend,
    AssistantSpeechPolicy? speechPolicy,
  }) => AssistantProfile(
    assistantId: assistantId,
    assistantRevision: assistantRevision ?? this.assistantRevision,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    displayName: displayName ?? this.displayName,
    persona: persona ?? this.persona,
    memoryPolicy: memoryPolicy ?? this.memoryPolicy,
    voiceProfileId: voiceProfileId ?? this.voiceProfileId,
    signalCoreProfile: signalCoreProfile ?? this.signalCoreProfile,
    defaultChatSource: defaultChatSource ?? this.defaultChatSource,
    hermesWorkBackend: hermesWorkBackend ?? this.hermesWorkBackend,
    speechPolicy: speechPolicy ?? this.speechPolicy,
  );
}

class AssistantCapabilityProjection {
  const AssistantCapabilityProjection({
    required this.source,
    required this.capabilities,
  });

  final ChatSource source;
  final Set<AssistantCapability> capabilities;

  bool has(AssistantCapability capability) => capabilities.contains(capability);

  static const direct = AssistantCapabilityProjection(
    source: ChatSource.directLlm,
    capabilities: {AssistantCapability.chat},
  );

  static const hermes = AssistantCapabilityProjection(
    source: ChatSource.hermes,
    capabilities: {
      AssistantCapability.chat,
      AssistantCapability.agent,
      AssistantCapability.tools,
      AssistantCapability.approvals,
      AssistantCapability.leases,
      AssistantCapability.interrupt,
      AssistantCapability.clarifications,
    },
  );

  factory AssistantCapabilityProjection.hermesFromNegotiation({
    required bool supportsApprovals,
    required bool supportsInterrupt,
    required bool supportsClarifications,
  }) => AssistantCapabilityProjection(
    source: ChatSource.hermes,
    capabilities: {
      AssistantCapability.chat,
      AssistantCapability.agent,
      if (supportsApprovals) AssistantCapability.approvals,
      if (supportsInterrupt) AssistantCapability.interrupt,
      if (supportsClarifications) AssistantCapability.clarifications,
    },
  );
}

/// A deliberately narrow OpenAI-compatible text source. It has no tools,
/// Agent host, approval, lease, or Gateway semantics.
class DirectLlmConfiguration {
  const DirectLlmConfiguration({
    this.id,
    this.providerProfileId,
    required this.origin,
    required this.model,
    this.systemPrompt = '',
    this.authRealm = '',
    this.principal = '',
    this.credentialRevision = 1,
    this.configurationRevision = 1,
    this.conversationId = '',
    this.assistantId = '',
    this.assistantRevision = 1,
    this.contextSnapshotRevision = 0,
    this.contextSnapshotHash = '',
  });

  /// `id` remains a source-compatible input alias only. Active code uses
  /// [providerProfileId] and never uses it as a history/conversation key.
  final String? id;
  final String? providerProfileId;
  final Uri origin;
  final String model;
  final String systemPrompt;
  final String authRealm;
  final String principal;
  final int credentialRevision;
  final int configurationRevision;
  final String conversationId;
  final String assistantId;
  final int assistantRevision;
  final int contextSnapshotRevision;
  final String contextSnapshotHash;

  String get profileId => providerProfileId ?? id ?? '';

  AssistantProfile get assistant => AssistantProfile(
    assistantId: assistantId,
    assistantRevision: assistantRevision,
    systemPrompt: systemPrompt,
  );

  bool get isSafe =>
      profileId.isNotEmpty &&
      model.trim().isNotEmpty &&
      origin.scheme == 'https' &&
      origin.host.isNotEmpty &&
      origin.userInfo.isEmpty &&
      _hasSafeApiBasePath(origin.pathSegments) &&
      !origin.hasQuery &&
      !origin.hasFragment;

  DirectLlmConfiguration copyWith({
    Uri? origin,
    String? model,
    String? systemPrompt,
    String? authRealm,
    String? principal,
    String? providerProfileId,
    int? credentialRevision,
    int? configurationRevision,
    String? conversationId,
    String? assistantId,
    int? assistantRevision,
    int? contextSnapshotRevision,
    String? contextSnapshotHash,
  }) => DirectLlmConfiguration(
    id: id,
    providerProfileId: providerProfileId ?? this.providerProfileId,
    origin: origin ?? this.origin,
    model: model ?? this.model,
    systemPrompt: systemPrompt ?? this.systemPrompt,
    authRealm: authRealm ?? this.authRealm,
    principal: principal ?? this.principal,
    credentialRevision: credentialRevision ?? this.credentialRevision,
    configurationRevision: configurationRevision ?? this.configurationRevision,
    conversationId: conversationId ?? this.conversationId,
    assistantId: assistantId ?? this.assistantId,
    assistantRevision: assistantRevision ?? this.assistantRevision,
    contextSnapshotRevision:
        contextSnapshotRevision ?? this.contextSnapshotRevision,
    contextSnapshotHash: contextSnapshotHash ?? this.contextSnapshotHash,
  );
}

String normalizedProviderOrigin(Uri origin) {
  final normalizedPath = origin.path == '/' ? '' : origin.path;
  return origin
      .replace(
        scheme: origin.scheme.toLowerCase(),
        host: origin.host.toLowerCase(),
        path: normalizedPath,
      )
      .toString();
}

/// A provider may expose its OpenAI-compatible API beneath a stable prefix
/// (for example OpenRouter's `/api/v1`).  Keep that prefix explicit and small:
/// it is not a free-form request URL and cannot carry query/user-info data.
bool _hasSafeApiBasePath(List<String> segments) =>
    segments.length <= 4 &&
    segments.every(
      (segment) =>
          segment.isNotEmpty && RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(segment),
    );

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
  Future<List<DirectChatMessage>> list(String conversationId);
  Future<void> upsert(String conversationId, DirectChatMessage message);
}
