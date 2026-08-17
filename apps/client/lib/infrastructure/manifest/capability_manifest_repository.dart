import '../../domain/capability_manifest.dart';

/// 拉取 Capability Manifest 失败时的可读异常。
///
/// [safeMessage] 必须是安全的展示文本，绝不包含 URL、token、凭据。
class ManifestFetchException implements Exception {
  const ManifestFetchException(this.code, this.safeMessage);

  final String code;
  final String safeMessage;

  @override
  String toString() => 'ManifestFetchException($code): $safeMessage';
}

/// Capability Manifest 获取源（配对后由 Companion Bridge 已认证连接提供）。
///
/// T1 落地 Companion Bridge 后接入真实实现；失败必须抛出
/// [ManifestFetchException]，不允许抛出未捕获异常。
abstract interface class CapabilityManifestRepository {
  Future<CapabilityManifest> fetch();
}

/// Bridge 未就绪时的占位实现：明确降级失败，绝不伪造 manifest，
/// 也绝不影响文字主链路。
class UnavailableCapabilityManifestRepository
    implements CapabilityManifestRepository {
  const UnavailableCapabilityManifestRepository();

  @override
  Future<CapabilityManifest> fetch() => Future.error(
    const ManifestFetchException(
      'bridge_not_configured',
      '未完成配对，无法获取能力清单。完成配对后重试即可；这不影响文字输入。',
    ),
  );
}
