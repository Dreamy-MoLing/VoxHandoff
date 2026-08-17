import 'dart:convert';

import 'package:agent_talk_client/application/onboarding_credential_controller.dart';
import 'package:agent_talk_client/domain/onboarding_credential.dart';
import 'package:agent_talk_client/infrastructure/security/onboarding_credential_store.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stores credential material in secure storage and exposes only a reference',
    () async {
      final values = _MemorySecureStore();
      final store = SecureOnboardingCredentialStore(values);
      final material = _material();

      final reference = await store.save(material);
      expect(reference.credentialId, material.credentialId);
      expect(
        reference.spkiPin,
        'sha256/${base64Encode(List<int>.filled(32, 7))}',
      );
      expect(reference.toString(), isNot(contains(material.credential)));

      final loadedReference = await store.loadReference();
      expect(loadedReference?.credentialId, material.credentialId);
      final loadedMaterial = await store.readMaterial(material.credentialId);
      expect(loadedMaterial?.credential, material.credential);
      expect(loadedMaterial?.deviceKeyReference, material.deviceKeyReference);

      await store.revoke(material.credentialId);
      expect(await store.loadReference(), isNull);
      expect(await store.readMaterial(material.credentialId), isNull);
    },
  );

  test('rejects a corrupt secure credential reference', () async {
    final values = _MemorySecureStore();
    final store = SecureOnboardingCredentialStore(values);
    await values.write(
      'voxhandoff.m6.onboarding-active-credential-reference',
      '{"version":99}',
    );

    await expectLater(
      store.loadReference(),
      throwsA(
        isA<OnboardingCredentialException>().having(
          (error) => error.code,
          'code',
          'corrupt_reference',
        ),
      ),
    );
  });

  test(
    'revocation sends the secure material before deleting it locally',
    () async {
      final vault = _FakeVault(_material());
      final revoker = _FakeRevoker();
      final controller = OnboardingCredentialController(
        vault: vault,
        revocationPort: revoker,
      );

      await controller.revokeActive();

      expect(revoker.revokedCredentialId, vault.material.credentialId);
      expect(vault.revokedCredentialId, vault.material.credentialId);
    },
  );
}

OnboardingCredentialMaterial _material() => OnboardingCredentialMaterial(
  credentialId: 'credential-synthetic-1',
  credential: 'synthetic-device-credential-only',
  bridgeEndpoint: Uri.parse('https://bridge.example/companion'),
  serverId: 'synthetic-server',
  deviceKeyReference: '0123456789abcdef0123456789abcdef',
  spkiPin: 'sha256/${base64Encode(List<int>.filled(32, 7))}',
  backupSpkiPin: 'sha256/${base64Encode(List<int>.filled(32, 8))}',
  issuedAt: DateTime.utc(2026, 8, 17, 12),
);

class _MemorySecureStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeVault implements OnboardingCredentialVault {
  _FakeVault(this.material);

  final OnboardingCredentialMaterial material;
  String? revokedCredentialId;

  @override
  Future<OnboardingCredentialReference> save(
    OnboardingCredentialMaterial material,
  ) async => OnboardingCredentialReference(
    credentialId: material.credentialId,
    bridgeEndpoint: material.bridgeEndpoint,
    serverId: material.serverId,
    deviceKeyReference: material.deviceKeyReference,
    spkiPin: material.spkiPin,
    backupSpkiPin: material.backupSpkiPin,
    issuedAt: material.issuedAt,
  );

  @override
  Future<OnboardingCredentialReference?> loadReference() async =>
      OnboardingCredentialReference(
        credentialId: material.credentialId,
        bridgeEndpoint: material.bridgeEndpoint,
        serverId: material.serverId,
        deviceKeyReference: material.deviceKeyReference,
        spkiPin: material.spkiPin,
        backupSpkiPin: material.backupSpkiPin,
        issuedAt: material.issuedAt,
      );

  @override
  Future<OnboardingCredentialMaterial?> readMaterial(
    String credentialId,
  ) async => material;

  @override
  Future<void> revoke(String credentialId) async =>
      revokedCredentialId = credentialId;
}

class _FakeRevoker implements OnboardingCredentialRevocationPort {
  String? revokedCredentialId;

  @override
  Future<void> revoke(OnboardingCredentialMaterial material) async {
    revokedCredentialId = material.credentialId;
  }
}
