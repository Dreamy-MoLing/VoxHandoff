import 'package:agent_talk_client/domain/manual_trust.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/tofu_trust_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeTofuOrigin', () {
    test('去掉路径/查询/片段，端口缺省记 443', () {
      expect(
        normalizeTofuOrigin(Uri.parse('https://Hermes.Example.test/x')),
        'https://hermes.example.test:443',
      );
      expect(
        normalizeTofuOrigin(Uri.parse('https://host:8443')),
        'https://host:8443',
      );
      expect(
        normalizeTofuOrigin(Uri.parse('https://host')),
        'https://host:443',
      );
    });

    test('拒绝非 HTTPS 与带用户信息/查询/片段', () {
      expect(
        () => normalizeTofuOrigin(Uri.parse('http://host')),
        throwsFormatException,
      );
      expect(
        () => normalizeTofuOrigin(Uri.parse('https://user@host')),
        throwsFormatException,
      );
      expect(
        () => normalizeTofuOrigin(Uri.parse('https://host?x=1')),
        throwsFormatException,
      );
      expect(
        () => normalizeTofuOrigin(Uri.parse('https://host#frag')),
        throwsFormatException,
      );
    });
  });

  group('TofuTrustRecord.matches', () {
    test('绑定 origin + fingerprint；任一变化即不匹配', () {
      final record = TofuTrustRecord(
        origin: 'https://host:443',
        fingerprint: 'sha256:aaaa',
        acceptedAt: DateTime.utc(2026, 8, 17),
      );
      expect(record.matches('https://host:443', 'sha256:aaaa'), isTrue);
      expect(record.matches('https://host:8443', 'sha256:aaaa'), isFalse);
      expect(record.matches('https://host:443', 'sha256:bbbb'), isFalse);
    });
  });

  group('shortenFingerprint', () {
    test('掩码长指纹', () {
      final long = 'sha256:${'a' * 64}';
      expect(shortenFingerprint(long), 'sha256:${'a' * 16}…');
      expect(shortenFingerprint('short'), 'short');
    });
  });

  group('SecureTofuTrustStore', () {
    test('record 后同源同指纹受信；异源或异指纹不受信', () async {
      final store = SecureTofuTrustStore(
        _MemorySecureStore(),
        clock: () => DateTime.utc(2026, 8, 17),
      );
      const fingerprint = 'sha256:deadbeef';
      const other = 'sha256:cafe';

      expect(
        await store.isTrusted(Uri.parse('https://host'), fingerprint),
        isFalse,
      );
      await store.record(Uri.parse('https://host/p/profile'), fingerprint);
      expect(
        await store.isTrusted(Uri.parse('https://host'), fingerprint),
        isTrue,
      );
      expect(
        await store.isTrusted(Uri.parse('https://host:8443'), fingerprint),
        isFalse,
      );
      expect(
        await store.isTrusted(Uri.parse('https://other'), fingerprint),
        isFalse,
      );
      expect(await store.isTrusted(Uri.parse('https://host'), other), isFalse);
    });

    test('重复 record 幂等', () async {
      final store = SecureTofuTrustStore(_MemorySecureStore());
      const fingerprint = 'sha256:aaaa';
      await store.record(Uri.parse('https://host'), fingerprint);
      await store.record(Uri.parse('https://host'), fingerprint);
      expect((await store.records()).length, 1);
    });

    test('record 只接受 HTTPS 源', () async {
      final store = SecureTofuTrustStore(_MemorySecureStore());
      expect(
        () => store.record(Uri.parse('http://host'), 'sha256:aaaa'),
        throwsA(isA<FormatException>()),
      );
    });

    test('损坏的存储按无信任记录处理（fail-safe）', () async {
      final backing = _MemorySecureStore();
      await backing.write('voxhandoff.v1.tofu-trust', '{ not json');
      final store = SecureTofuTrustStore(backing);
      expect(await store.records(), isEmpty);
      expect(
        await store.isTrusted(Uri.parse('https://host'), 'sha256:aaaa'),
        isFalse,
      );
    });

    test('结构不完整的记录被跳过，其余保留', () async {
      final backing = _MemorySecureStore();
      await backing.write(
        'voxhandoff.v1.tofu-trust',
        '{"version":1,"records":['
            '{"origin":"https://a:443","fingerprint":"sha256:aaaa","accepted_at":"2026-08-17T00:00:00Z"},'
            '{"origin":"https://b:443","fingerprint":"sha256:bbbb"},'
            '{"origin":42,"fingerprint":"sha256:cccc","accepted_at":"2026-08-17T00:00:00Z"}'
            ']}',
      );
      final store = SecureTofuTrustStore(backing);
      final records = await store.records();
      expect(records.length, 1);
      expect(records.single.origin, 'https://a:443');
    });
  });
}

class _MemorySecureStore implements SecureValueStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
