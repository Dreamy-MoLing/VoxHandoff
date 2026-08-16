import 'dart:convert';

/// The v0.1.0 Hermes transport keeps one stable transcript id and one stable
/// memory scope key.  Bootstrap may replace [sessionId] with the server's
/// effective id, while [sessionKey] remains stable for the configured
/// assistant/profile/channel.
enum HermesSessionIdPolicy { bootstrapPreferred, generatedStable }

class HermesConversationConfiguration {
  const HermesConversationConfiguration({
    required this.providerProfileId,
    required this.origin,
    required this.model,
    required this.conversationId,
    required this.sessionId,
    required this.sessionKey,
    this.credentialRevision = 1,
    this.configurationRevision = 1,
    this.contextSnapshotRevision = 0,
    this.contextSnapshotHash = '',
    this.sessionIdPolicy = HermesSessionIdPolicy.bootstrapPreferred,
  });

  /// Opaque local provider identity. It is never the Hermes profile name.
  final String providerProfileId;

  /// HTTPS origin with an optional, exact `/p/<profile>` path prefix.
  final Uri origin;
  final String model;
  final String conversationId;
  final String sessionId;
  final String sessionKey;
  final int credentialRevision;
  final int configurationRevision;
  final int contextSnapshotRevision;
  final String contextSnapshotHash;
  final HermesSessionIdPolicy sessionIdPolicy;

  String get profileName {
    final segments = origin.pathSegments;
    return segments.length == 2 && segments.first == 'p' ? segments.last : '';
  }

  String get normalizedOrigin {
    final normalizedPath = origin.path == '/' ? '' : origin.path;
    return origin
        .replace(
          scheme: origin.scheme.toLowerCase(),
          host: origin.host.toLowerCase(),
          path: normalizedPath,
        )
        .toString();
  }

  bool get isSafe =>
      _isOpaque(providerProfileId, 128) &&
      model.trim().isNotEmpty &&
      model.length <= 256 &&
      _isOpaque(conversationId, 256) &&
      _isPathSegmentSafe(sessionId) &&
      _isOpaque(sessionKey, 256) &&
      credentialRevision > 0 &&
      configurationRevision > 0 &&
      contextSnapshotRevision >= 0 &&
      contextSnapshotHash.length <= 128 &&
      origin.scheme.toLowerCase() == 'https' &&
      origin.host.isNotEmpty &&
      origin.userInfo.isEmpty &&
      !origin.hasQuery &&
      !origin.hasFragment &&
      _hasSafeProfilePath(origin.pathSegments);

  HermesConversationConfiguration copyWith({
    Uri? origin,
    String? model,
    String? conversationId,
    String? sessionId,
    String? sessionKey,
    int? credentialRevision,
    int? configurationRevision,
    int? contextSnapshotRevision,
    String? contextSnapshotHash,
    HermesSessionIdPolicy? sessionIdPolicy,
  }) => HermesConversationConfiguration(
    providerProfileId: providerProfileId,
    origin: origin ?? this.origin,
    model: model ?? this.model,
    conversationId: conversationId ?? this.conversationId,
    sessionId: sessionId ?? this.sessionId,
    sessionKey: sessionKey ?? this.sessionKey,
    credentialRevision: credentialRevision ?? this.credentialRevision,
    configurationRevision: configurationRevision ?? this.configurationRevision,
    contextSnapshotRevision:
        contextSnapshotRevision ?? this.contextSnapshotRevision,
    contextSnapshotHash: contextSnapshotHash ?? this.contextSnapshotHash,
    sessionIdPolicy: sessionIdPolicy ?? this.sessionIdPolicy,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'provider_profile_id': providerProfileId,
    'origin': origin.toString(),
    'model': model,
    'conversation_id': conversationId,
    'session_id': sessionId,
    'session_key': sessionKey,
    'credential_revision': credentialRevision,
    'configuration_revision': configurationRevision,
    'context_snapshot_revision': contextSnapshotRevision,
    'context_snapshot_hash': contextSnapshotHash,
    'session_id_policy': sessionIdPolicy.name,
  };

  static HermesConversationConfiguration? fromJson(Object? raw) {
    if (raw is! Map<String, Object?> || raw['version'] != 1) return null;
    final providerProfileId = raw['provider_profile_id'];
    final originValue = raw['origin'];
    final model = raw['model'];
    final conversationId = raw['conversation_id'];
    final sessionId = raw['session_id'];
    final sessionKey = raw['session_key'];
    final credentialRevision = raw['credential_revision'];
    final configurationRevision = raw['configuration_revision'];
    final contextSnapshotRevision = raw['context_snapshot_revision'];
    final contextSnapshotHash = raw['context_snapshot_hash'];
    final policyValue = raw['session_id_policy'];
    if (providerProfileId is! String ||
        originValue is! String ||
        model is! String ||
        conversationId is! String ||
        sessionId is! String ||
        sessionKey is! String ||
        credentialRevision is! int ||
        configurationRevision is! int ||
        contextSnapshotRevision is! int ||
        contextSnapshotHash is! String ||
        policyValue is! String) {
      return null;
    }
    final origin = Uri.tryParse(originValue);
    HermesSessionIdPolicy? policy;
    for (final candidate in HermesSessionIdPolicy.values) {
      if (candidate.name == policyValue) policy = candidate;
    }
    if (origin == null || policy == null) return null;
    final configuration = HermesConversationConfiguration(
      providerProfileId: providerProfileId,
      origin: origin,
      model: model,
      conversationId: conversationId,
      sessionId: sessionId,
      sessionKey: sessionKey,
      credentialRevision: credentialRevision,
      configurationRevision: configurationRevision,
      contextSnapshotRevision: contextSnapshotRevision,
      contextSnapshotHash: contextSnapshotHash,
      sessionIdPolicy: policy,
    );
    return configuration.isSafe ? configuration : null;
  }

  @override
  bool operator ==(Object other) =>
      other is HermesConversationConfiguration &&
      providerProfileId == other.providerProfileId &&
      normalizedOrigin == other.normalizedOrigin &&
      model == other.model &&
      conversationId == other.conversationId &&
      sessionId == other.sessionId &&
      sessionKey == other.sessionKey &&
      credentialRevision == other.credentialRevision &&
      configurationRevision == other.configurationRevision &&
      contextSnapshotRevision == other.contextSnapshotRevision &&
      contextSnapshotHash == other.contextSnapshotHash &&
      sessionIdPolicy == other.sessionIdPolicy;

  @override
  int get hashCode => Object.hash(
    providerProfileId,
    normalizedOrigin,
    model,
    conversationId,
    sessionId,
    sessionKey,
    credentialRevision,
    configurationRevision,
    contextSnapshotRevision,
    contextSnapshotHash,
    sessionIdPolicy,
  );
}

Uri hermesConversationEndpoint(
  HermesConversationConfiguration configuration,
  List<String> resource,
) {
  if (!configuration.isSafe ||
      resource.isEmpty ||
      resource.any((segment) => !_isPathSegmentSafe(segment))) {
    throw ArgumentError.value(
      configuration,
      'configuration',
      'Unsafe Hermes conversation endpoint',
    );
  }
  return configuration.origin.replace(
    pathSegments: [...configuration.origin.pathSegments, ...resource],
  );
}

bool _hasSafeProfilePath(List<String> segments) =>
    segments.isEmpty ||
    (segments.length == 2 &&
        segments.first == 'p' &&
        _isProfileSegmentSafe(segments.last));

bool _isProfileSegmentSafe(String value) =>
    value.length <= 64 &&
    RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value) &&
    value != '.' &&
    value != '..';

bool _isPathSegmentSafe(String value) =>
    value.isNotEmpty &&
    value.length <= 64 &&
    RegExp(r'^[A-Za-z0-9._~-]+$').hasMatch(value) &&
    value != '.' &&
    value != '..';

bool _isOpaque(String value, int maximumLength) =>
    value.isNotEmpty &&
    value.length <= maximumLength &&
    !value.contains(RegExp(r'[\s\u0000-\u001f\u007f]'));

String encodeHermesConversationConfiguration(
  HermesConversationConfiguration configuration,
) => jsonEncode(configuration.toJson());
