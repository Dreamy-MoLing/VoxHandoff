import 'dart:convert';

import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/secure_pairing_stores.dart';
import 'package:agent_talk_client/infrastructure/gateway/secure_grpc_pairing_workflow_factory.dart';
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

void main() {
  test('round-trips the pinned Gateway trust profile', () async {
    final values = FakeSecureValueStore();
    final store = SecureGatewayConnectionProfileStore(values);
    final profile = GatewayConnectionProfile(
      gatewayAudience: 'https://gateway.example:8443',
      trustedRootCertificates: const [1, 2, 3, 4],
    );

    await store.save(profile);
    final restored = await store.load();

    expect(restored?.gatewayAudience, profile.gatewayAudience);
    expect(restored?.trustedRootCertificates, [1, 2, 3, 4]);
  });

  test(
    'restores an active credential after the checkpoint is removed',
    () async {
      final values = FakeSecureValueStore();
      await SecureGatewayConnectionProfileStore(values).save(
        GatewayConnectionProfile(gatewayAudience: 'https://gateway.example'),
      );
      await SecureDeviceCredentialStore(values).save(
        DeviceCredentialBundle(
          keyReference: '0123456789abcdef0123456789abcdef',
          deviceId: 'device_1',
          credentialId: 'credential_1',
          gatewayAudience: 'https://gateway.example',
          scopes: const ['observe', 'send'],
          accessToken: 'ACCESS_TOKEN_0123456789_abcdef',
          refreshToken: 'REFRESH_TOKEN_0123456789_abcdefghijklmnop',
          accessExpiresAt: DateTime.utc(2030, 1, 1),
          refreshExpiresAt: DateTime.utc(2030, 2, 1),
        ),
      );
      PairingState? restored;

      final session = await SecureGrpcPairingWorkflowFactory(
        secureValueStore: values,
      ).restore(onStateChanged: (state) => restored = state);

      expect(session, isNotNull);
      expect(restored?.phase, PairingPhase.paired);
      expect(restored?.deviceId, 'device_1');
      await session?.close();
    },
  );

  test('round-trips every secret checkpoint fact without logging bytes', () async {
    final values = FakeSecureValueStore();
    final store = SecurePairingCheckpointStore(values);
    final checkpoint = PairingCheckpoint(
      phase: PairingCheckpointPhase.confirmationPrepared,
      keyReference: '0123456789abcdef0123456789abcdef',
      deviceDisplayName: 'Roco desktop',
      expectedGatewayAudience: 'https://gateway.example',
      requestedScopes: const ['observe', 'send'],
      pairingId: 'pairing_1',
      userCode: 'ABCD-EFGH',
      verificationUri: Uri.parse('https://gateway.example/pair'),
      expiresAt: DateTime.utc(2026, 7, 19, 12, 10),
      deviceFingerprint:
          'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      gatewayFingerprint:
          'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      gatewayAudience: 'https://gateway.example',
      deviceProofPayload: const [1, 2, 3],
      proofSignature: List.filled(64, 4),
      deviceId: 'device_1',
      credentialId: 'credential_1',
      approvedScopes: const ['observe'],
      confirmationPayload: const [5, 6, 7],
      confirmationSignature: List.filled(64, 8),
      confirmationExpiresAt: DateTime.utc(2026, 7, 19, 12, 2),
      uncertainOperation: PairingOperation.confirm,
    );

    await store.save(checkpoint);
    final restored = await store.load();

    expect(restored?.phase, checkpoint.phase);
    expect(restored?.requestedScopes, checkpoint.requestedScopes);
    expect(restored?.deviceProofPayload, checkpoint.deviceProofPayload);
    expect(restored?.confirmationSignature, checkpoint.confirmationSignature);
    expect(restored?.uncertainOperation, PairingOperation.confirm);
    expect(
      restored.toString(),
      isNot(contains(base64UrlEncode(checkpoint.confirmationSignature!))),
    );
  });

  test(
    'rejects malformed checkpoint bytes instead of partially restoring',
    () async {
      final values = FakeSecureValueStore();
      final store = SecurePairingCheckpointStore(values);
      values.values['agent-talk.v1.pairing-checkpoint'] = jsonEncode({
        'version': 1,
        'kind': 'pairing_checkpoint',
        'phase': 'completed',
        'key_reference': '0123456789abcdef0123456789abcdef',
        'device_display_name': 'desktop',
        'expected_gateway_audience': 'https://gateway.example',
        'requested_scopes': ['observe'],
        'approved_scopes': ['observe'],
        'proof_signature': 'not base64!@#',
      });

      await expectLater(
        store.load(),
        throwsA(
          isA<SecurePairingStoreException>().having(
            (error) => error.code,
            'code',
            'corrupt_secure_record',
          ),
        ),
      );
    },
  );

  test(
    'stores credentials by hashed identity and rejects conflicting reuse',
    () async {
      final values = FakeSecureValueStore();
      final store = SecureDeviceCredentialStore(values);
      final credential = DeviceCredentialBundle(
        keyReference: '0123456789abcdef0123456789abcdef',
        deviceId: 'device_1',
        credentialId: 'credential_1',
        gatewayAudience: 'https://gateway.example',
        scopes: const ['observe'],
        accessToken: 'ACCESS_TOKEN_0123456789_abcdef',
        refreshToken: 'REFRESH_TOKEN_0123456789_abcdefghijklmnop',
        accessExpiresAt: DateTime.utc(2026, 7, 19, 12, 15),
        refreshExpiresAt: DateTime.utc(2026, 8, 18, 12),
      );

      await store.save(credential);
      await store.save(credential);
      final restored = await store.load('credential_1');
      final active = await store.loadActive();

      expect(restored?.accessToken, credential.accessToken);
      expect(restored?.refreshToken, credential.refreshToken);
      expect(active?.credentialId, credential.credentialId);
      final credentialRecordKey = values.values.keys.singleWhere(
        (key) => key.startsWith('agent-talk.v1.device-credential.'),
      );
      expect(credentialRecordKey, isNot(contains('credential_1')));
      expect(
        values.values['agent-talk.v1.active-device-credential'],
        credential.credentialId,
      );
      expect(restored.toString(), isNot(contains(credential.refreshToken)));

      await expectLater(
        store.save(
          DeviceCredentialBundle(
            keyReference: credential.keyReference,
            deviceId: credential.deviceId,
            credentialId: credential.credentialId,
            gatewayAudience: credential.gatewayAudience,
            scopes: credential.scopes,
            accessToken: 'DIFFERENT_ACCESS_TOKEN_0123456789',
            refreshToken: credential.refreshToken,
            accessExpiresAt: credential.accessExpiresAt,
            refreshExpiresAt: credential.refreshExpiresAt,
          ),
        ),
        throwsA(
          isA<SecurePairingStoreException>().having(
            (error) => error.code,
            'code',
            'credential_conflict',
          ),
        ),
      );

      await expectLater(
        store.save(
          DeviceCredentialBundle(
            keyReference: 'fedcba9876543210fedcba9876543210',
            deviceId: 'device_2',
            credentialId: 'credential_2',
            gatewayAudience: credential.gatewayAudience,
            scopes: credential.scopes,
            accessToken: credential.accessToken,
            refreshToken: credential.refreshToken,
            accessExpiresAt: credential.accessExpiresAt,
            refreshExpiresAt: credential.refreshExpiresAt,
          ),
        ),
        throwsA(
          isA<SecurePairingStoreException>().having(
            (error) => error.code,
            'code',
            'active_credential_conflict',
          ),
        ),
      );
    },
  );
}
