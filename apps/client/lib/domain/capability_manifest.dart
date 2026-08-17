import 'dart:convert';

/// 解析失败（载荷根本不是 JSON 对象）时的可读异常。
///
/// 只有"完全不是 manifest"（非法 JSON 或顶层非对象）才会抛错；
/// 合法对象里的未知字段一律宽容跳过，绝不因为未知字段失败。
class ManifestParseException implements Exception {
  const ManifestParseException(this.code, this.safeMessage);

  final String code;
  final String safeMessage;

  @override
  String toString() => 'ManifestParseException($code): $safeMessage';
}

/// 配对后由 Companion Bridge 通过已认证连接下发的 Capability Manifest。
///
/// 结构以 spec/design/onboarding-qr-pairing.md 第 5 节为准：
/// `chat` / `stt` / `tts` / `hermes` 四段。未知字段被保留但不参与判定，
/// 缺失字段按不可用降级，任何情况下都不会因多余或未知字段失败。
class CapabilityManifest {
  const CapabilityManifest({
    required this.chat,
    required this.stt,
    required this.tts,
    required this.hermes,
    this.others = const {},
  });

  final ManifestChatSection chat;
  final ManifestSttSection stt;
  final ManifestTtsSection tts;
  final ManifestHermesSection hermes;

  /// 顶层未知字段（原样保留，不参与判定）。
  final Map<String, Object?> others;

  /// Hermes Chat 必须可用；不可用时 UI 应提示"不可用"。
  bool get chatAvailable => chat.available;
  bool get sttAvailable => stt.available;
  bool get ttsAvailable => tts.available;
  bool get hermesAvailable => hermes.available;

  factory CapabilityManifest.fromJsonString(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const ManifestParseException(
        'manifest_invalid_json',
        'Capability manifest 不是有效的 JSON。',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const ManifestParseException(
        'manifest_not_object',
        'Capability manifest 必须是 JSON 对象。',
      );
    }
    return CapabilityManifest.fromMap(decoded);
  }

  factory CapabilityManifest.fromMap(Map<String, Object?> map) {
    final chat = _asMap(map['chat']);
    final stt = _asMap(map['stt']);
    final tts = _asMap(map['tts']);
    final hermes = _asMap(map['hermes']);
    return CapabilityManifest(
      chat: chat == null
          ? const ManifestChatSection()
          : ManifestChatSection.fromMap(chat),
      stt: stt == null
          ? const ManifestSttSection()
          : ManifestSttSection.fromMap(stt),
      tts: tts == null
          ? const ManifestTtsSection()
          : ManifestTtsSection.fromMap(tts),
      hermes: hermes == null
          ? const ManifestHermesSection()
          : ManifestHermesSection.fromMap(hermes),
      others: _copyStringKeys(map, const {'chat', 'stt', 'tts', 'hermes'}),
    );
  }

  static Map<String, Object?>? _asMap(Object? value) =>
      value is Map<String, Object?> ? value : null;
}

Map<String, Object?> _copyStringKeys(
  Map<String, Object?> source,
  Set<String> excluded,
) {
  final result = <String, Object?>{};
  for (final entry in source.entries) {
    if (excluded.contains(entry.key)) continue;
    result[entry.key] = entry.value;
  }
  return Map.unmodifiable(result);
}

/// chat 段：`{ "available": true }`。
class ManifestChatSection {
  const ManifestChatSection({this.available = false, this.extra = const {}});

  /// 缺失或非布尔时视为不可用，绝不因此抛错。
  final bool available;

  /// 本段未知字段（保留，不参与判定）。
  final Map<String, Object?> extra;

  factory ManifestChatSection.fromMap(Map<String, Object?> map) =>
      ManifestChatSection(
        available: _readBool(map['available'], false),
        extra: _readExtra(map, const {'available'}),
      );
}

/// stt 段：`{ "available": true, "capabilities": { ... } }`。
class ManifestSttSection {
  const ManifestSttSection({
    this.available = false,
    this.capabilities = const {},
    this.extra = const {},
  });

  final bool available;

  /// 结构化能力声明；结构由 T1 服务端定义，客户端原样保留待对齐。
  final Map<String, Object?> capabilities;

  final Map<String, Object?> extra;

  factory ManifestSttSection.fromMap(Map<String, Object?> map) =>
      ManifestSttSection(
        available: _readBool(map['available'], false),
        capabilities: _readCapabilities(map['capabilities']),
        extra: _readExtra(map, const {'available', 'capabilities'}),
      );
}

/// tts 段：`{ "available": true, "voices": [], "recommended_voice": "Bronya" }`。
class ManifestTtsSection {
  const ManifestTtsSection({
    this.available = false,
    this.voices = const [],
    this.recommendedVoice,
    this.capabilities = const {},
    this.extra = const {},
  });

  final bool available;
  final List<String> voices;
  final String? recommendedVoice;
  final Map<String, Object?> capabilities;
  final Map<String, Object?> extra;

  factory ManifestTtsSection.fromMap(Map<String, Object?> map) =>
      ManifestTtsSection(
        available: _readBool(map['available'], false),
        voices: _readStringList(map['voices']),
        recommendedVoice: _readOptionalString(map['recommended_voice']),
        capabilities: _readCapabilities(map['capabilities']),
        extra: _readExtra(map, const {
          'available',
          'voices',
          'recommended_voice',
          'capabilities',
        }),
      );
}

/// hermes 段：`{ "profile": "...", "model": "...", "capabilities": { } }`。
///
/// 该段不强制携带 `available`；存在 profile/model/能力时视为已配置。
class ManifestHermesSection {
  const ManifestHermesSection({
    this.available = false,
    this.profile,
    this.model,
    this.capabilities = const {},
    this.extra = const {},
  });

  final bool available;
  final String? profile;
  final String? model;
  final Map<String, Object?> capabilities;
  final Map<String, Object?> extra;

  factory ManifestHermesSection.fromMap(Map<String, Object?> map) {
    final explicitAvailable = _readBoolOrNull(map['available']);
    final profile = _readOptionalString(map['profile']);
    final model = _readOptionalString(map['model']);
    final capabilities = _readCapabilities(map['capabilities']);
    final available =
        explicitAvailable ??
        (profile != null || model != null || capabilities.isNotEmpty);
    return ManifestHermesSection(
      available: available,
      profile: profile,
      model: model,
      capabilities: capabilities,
      extra: _readExtra(map, const {
        'available',
        'profile',
        'model',
        'capabilities',
      }),
    );
  }
}

bool _readBool(Object? value, bool fallback) {
  if (value is bool) return value;
  return fallback;
}

bool? _readBoolOrNull(Object? value) => value is bool ? value : null;

String? _readOptionalString(Object? value) => value is String ? value : null;

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  final result = <String>[];
  for (final item in value) {
    if (item is String) result.add(item);
  }
  return List.unmodifiable(result);
}

Map<String, Object?> _readCapabilities(Object? value) =>
    value is Map<String, Object?> ? Map.unmodifiable(value) : const {};

Map<String, Object?> _readExtra(Map<String, Object?> map, Set<String> known) {
  final result = <String, Object?>{};
  for (final entry in map.entries) {
    if (known.contains(entry.key)) continue;
    result[entry.key] = entry.value;
  }
  return Map.unmodifiable(result);
}
