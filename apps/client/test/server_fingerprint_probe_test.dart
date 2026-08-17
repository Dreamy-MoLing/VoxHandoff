import 'package:agent_talk_client/infrastructure/security/server_fingerprint_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatServerFingerprint', () {
    test('空输入哈希对 sha256(空字节) 已知向量', () async {
      // SHA-256 of empty input.
      expect(
        await formatServerFingerprint(const []),
        'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('确定性：相同证书字节得到相同指纹', () async {
      final der = List<int>.generate(32, (i) => i);
      final first = await formatServerFingerprint(der);
      final second = await formatServerFingerprint(der);
      expect(first, second);
      expect(first.startsWith('sha256:'), isTrue);
      expect(first.length, 'sha256:'.length + 64);
    });
  });

  group('ServerFingerprintProbe 校验（不触网）', () {
    final probe = ServerFingerprintProbe();

    test('拒绝非 HTTPS 源', () async {
      await expectLater(
        probe.probe(Uri.parse('http://host')),
        throwsA(
          isA<FingerprintProbeException>().having(
            (e) => e.code,
            'code',
            'probe_not_https',
          ),
        ),
      );
    });

    test('拒绝带查询参数的源', () async {
      await expectLater(
        probe.probe(Uri.parse('https://host?x=1')),
        throwsA(
          isA<FingerprintProbeException>().having(
            (e) => e.code,
            'code',
            'probe_invalid_origin',
          ),
        ),
      );
    });

    test('拒绝空主机', () async {
      await expectLater(
        probe.probe(Uri.parse('https://')),
        throwsA(
          isA<FingerprintProbeException>().having(
            (e) => e.code,
            'code',
            'probe_invalid_origin',
          ),
        ),
      );
    });
  });
}
