/// 手动连接 fallback 的裸 TOFU 信任记录。
///
/// 语义（对齐 spec/design/onboarding-qr-pairing.md 2.6 / 4）：
/// - 仅在"手动输入地址后首次接受未知指纹"时创建；
/// - 记录绑定单个 (origin, fingerprint)，不是"永久忽略"某个主机；
/// - 指纹不匹配即视为未信任（fail closed）。
class TofuTrustRecord {
  const TofuTrustRecord({
    required this.origin,
    required this.fingerprint,
    required this.acceptedAt,
  });

  /// 归一化的服务器标识（https://host:port）。
  final String origin;

  /// `sha256:<hex>` 形式的服务器指纹。
  final String fingerprint;

  final DateTime acceptedAt;

  bool matches(String otherOrigin, String otherFingerprint) =>
      origin == otherOrigin && fingerprint == otherFingerprint;
}

/// 把 HTTPS 源归一化为信任记录的服务器键（去路径/查询/片段/用户信息，
/// 端口缺省记 443）。非 HTTPS 一律拒绝——TOFU 只允许 TLS 通道。
String normalizeTofuOrigin(Uri origin) {
  final scheme = origin.scheme.toLowerCase();
  if (scheme != 'https') {
    throw const FormatException('TOFU 信任仅允许 HTTPS 地址。');
  }
  if (origin.userInfo.isNotEmpty ||
      origin.hasQuery ||
      origin.hasFragment ||
      origin.host.isEmpty) {
    throw const FormatException('TOFU 信任要求裸的 HTTPS 主机地址。');
  }
  final port = origin.hasPort ? origin.port : 443;
  return '$scheme://${origin.host.toLowerCase()}:$port';
}

/// 展示用：只展示指纹前 16 个十六进制位（连同 `sha256:` 前缀共 23 字符）
/// 并掩码其余位，避免把完整指纹直接铺满界面（仍是标识，但不是凭据）。
String shortenFingerprint(String fingerprint) {
  if (fingerprint.length <= 24) return fingerprint;
  return '${fingerprint.substring(0, 23)}…';
}
