import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

class FingerprintProbeException implements Exception {
  const FingerprintProbeException(this.code, this.safeMessage);

  final String code;
  final String safeMessage;

  @override
  String toString() => 'FingerprintProbeException($code): $safeMessage';
}

/// 服务器指纹探测：建立只读 TLS 连接并抓取对端证书，计算 SHA-256 指纹。
///
/// 手动连接 fallback 的第一步：先拿到指纹，再让用户显式决定是否
/// 首次接受（裸 TOFU）。绝不会自动记录信任，也绝不会携带用户数据。
abstract interface class FingerprintProbe {
  Future<String> probe(Uri serverOrigin);
}

/// 对真实 HTTPS 服务器探测指纹（叶子证书 DER 的 SHA-256）。
///
/// 探测连接只发送一个无正文的 HEAD 请求并立即关闭：不发送用户文本、
/// 凭据或任何配置数据。为读取未知证书的指纹，TLS 校验失败时会在
/// `badCertificateCallback` 中捕获证书对象并放行本次只读握手——
/// 这不等同于信任：信任记录只在用户显式接受后写入。
///
/// 说明：T1 落地 Companion Bridge 后，可将指纹对齐为 design 2.4 的
/// SHA-256 SPKI pin；当前 leaf-cert DER 哈希只用于手动连接 TOFU 的
/// 服务器身份标识，不影响主链路传输行为。
class ServerFingerprintProbe implements FingerprintProbe {
  factory ServerFingerprintProbe({
    Sha256? sha256,
    Duration timeout = const Duration(seconds: 8),
    HttpClient Function()? clientFactory,
  }) => ServerFingerprintProbe._(
    sha256 ?? Sha256(),
    timeout,
    clientFactory ?? HttpClient.new,
  );

  ServerFingerprintProbe._(this._sha256, this._timeout, this._clientFactory);

  final Sha256 _sha256;
  final Duration _timeout;
  final HttpClient Function() _clientFactory;

  @override
  Future<String> probe(Uri serverOrigin) async {
    if (serverOrigin.scheme.toLowerCase() != 'https') {
      throw const FingerprintProbeException(
        'probe_not_https',
        '手动连接指纹探测只允许 HTTPS 地址。',
      );
    }
    if (serverOrigin.host.isEmpty ||
        serverOrigin.hasQuery ||
        serverOrigin.hasFragment ||
        serverOrigin.userInfo.isNotEmpty) {
      throw const FingerprintProbeException(
        'probe_invalid_origin',
        '指纹探测需要精确的 HTTPS 主机地址，不能带查询参数或片段。',
      );
    }
    final bareOrigin = Uri(
      scheme: serverOrigin.scheme,
      host: serverOrigin.host,
      port: serverOrigin.hasPort ? serverOrigin.port : 443,
    );
    X509Certificate? capturedCertificate;
    final client = _clientFactory();
    try {
      client.connectionTimeout = _timeout;
      client.idleTimeout = _timeout;
      client.badCertificateCallback = (certificate, host, port) {
        capturedCertificate = certificate;
        return true;
      };
      final request = await client.headUrl(bareOrigin).timeout(_timeout);
      final response = await request.close().timeout(
        _timeout,
        onTimeout: () {
          throw const FingerprintProbeException(
            'probe_timeout',
            '连接超时，无法获取服务器指纹。请检查地址后重试。',
          );
        },
      );
      try {
        await response.drain<void>();
      } on Object {
        // 响应体无关紧要；握手已完成，指纹已可从证书获得。
      }
      final certificate = response.certificate ?? capturedCertificate;
      final der = certificate?.der;
      if (der == null || der.isEmpty) {
        throw const FingerprintProbeException(
          'probe_no_certificate',
          '未获取到服务器证书。请检查地址是否为 HTTPS 服务器，或等 Bridge（T1）接入后再试。',
        );
      }
      return formatServerFingerprint(der, sha256: _sha256);
    } on FingerprintProbeException {
      rethrow;
    } on SocketException {
      throw const FingerprintProbeException(
        'probe_unreachable',
        '无法连接目标服务器，未建立任何信任。请检查地址与网络后重试。',
      );
    } on HttpException {
      throw const FingerprintProbeException(
        'probe_unreachable',
        '目标服务器未响应，未建立任何信任。请检查地址后重试。',
      );
    } on TimeoutException {
      throw const FingerprintProbeException(
        'probe_timeout',
        '连接超时，未建立任何信任。请检查地址后重试。',
      );
    } on Object {
      throw const FingerprintProbeException(
        'probe_failed',
        '未能获取服务器指纹，未建立任何信任。请稍后重试。',
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// 由证书 DER 计算 `sha256:<hex>` 指纹。
Future<String> formatServerFingerprint(List<int> der, {Sha256? sha256}) async {
  final digest = await (sha256 ?? Sha256()).hash(der);
  final hex = digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'sha256:$hex';
}
