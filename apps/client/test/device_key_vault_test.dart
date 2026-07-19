import 'dart:convert';
import 'dart:math';

import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

List<int> hexBytes(String value) => [
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
];

String hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final rfcSeed = hexBytes(
    '9d61b19deffd5a60ba844af492ec2cc4'
    '4449c5697b326919703bac031cae7f60',
  );

  test(
    'creates canonical SPKI identity and RFC 8032 Ed25519 signature',
    () async {
      final store = FakeSecureValueStore();
      final vault = DeviceKeyVault(
        store: store,
        random: Random(7),
        seedFactory: () async => rfcSeed,
      );

      final identity = await vault.createPendingKey();
      expect(
        hex(identity.publicKeySpkiDer),
        '302a300506032b6570032100'
        'd75a980182b10ab7d54bfed3c964073a'
        '0ee172f3daa62325af021a68f707511a',
      );
      expect(
        identity.fingerprint,
        'sha256:06e3fd8fda29bb60ab59557de61edb0a'
        'ecdb231134be30e75b455f8e1b792fa9',
      );
      expect(
        hex(await vault.sign(identity.keyReference, const [])),
        'e5564300c360ac729086e2cc806e828a'
        '84877f1eb8e5d974d873e06522490155'
        '5fb8821590a33bacc61e39701cf9b46b'
        'd25bf5f0595bbe24655141438e7a100b',
      );
      expect(identity.toString(), isNot(contains(base64UrlEncode(rfcSeed))));
    },
  );

  test(
    'reloads pending keys and signs without exposing seed in identity',
    () async {
      final store = FakeSecureValueStore();
      final firstVault = DeviceKeyVault(
        store: store,
        random: Random(9),
        seedFactory: () async => rfcSeed,
      );
      final identity = await firstVault.createPendingKey();
      final rebuiltVault = DeviceKeyVault(store: store);

      final rebuiltIdentity = await rebuiltVault.inspect(identity.keyReference);
      expect(rebuiltIdentity.publicKeySpkiDer, identity.publicKeySpkiDer);
      final signature = await rebuiltVault.sign(
        identity.keyReference,
        utf8.encode('pairing proof'),
      );
      final publicKey = SimplePublicKey(
        identity.publicKeySpkiDer.sublist(12),
        type: KeyPairType.ed25519,
      );
      expect(
        await Ed25519().verify(
          utf8.encode('pairing proof'),
          signature: Signature(signature, publicKey: publicKey),
        ),
        isTrue,
      );
    },
  );

  test(
    'rejects corrupted key records and erases discarded pending keys',
    () async {
      final store = FakeSecureValueStore();
      final vault = DeviceKeyVault(
        store: store,
        random: Random(11),
        seedFactory: () async => rfcSeed,
      );
      final identity = await vault.createPendingKey();
      final recordKey = store.values.keys.single;
      final record =
          jsonDecode(store.values[recordKey]!) as Map<String, Object?>;
      record['public_key'] = base64UrlEncode(List.filled(32, 0));
      store.values[recordKey] = jsonEncode(record);

      expect(
        () => vault.sign(identity.keyReference, const [1]),
        throwsA(
          isA<DeviceKeyVaultException>().having(
            (error) => error.code,
            'code',
            'corrupt_key',
          ),
        ),
      );
      await vault.discard(identity.keyReference);
      expect(store.values, isEmpty);
    },
  );
}
