import 'dart:convert';

import 'package:agent_talk_client/application/device_pairing_coordinator.dart';
import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureValueStore implements SecureValueStore {
  final values = <String, String>{};
  var failNextActiveWrite = false;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failNextActiveWrite && key.contains('active-device-key')) {
      failNextActiveWrite = false;
      throw StateError('injected active-key write failure');
    }
    values[key] = value;
  }
}

class FakePairingCheckpointStore implements PairingCheckpointStore {
  PairingCheckpoint? value;

  @override
  Future<void> delete() async {
    value = null;
  }

  @override
  Future<PairingCheckpoint?> load() async => value;

  @override
  Future<void> save(PairingCheckpoint checkpoint) async {
    value = checkpoint;
  }
}

class FakeDeviceCredentialStore implements DeviceCredentialStore {
  DeviceCredentialBundle? value;
  var failNextSave = false;
  var saveCalls = 0;

  @override
  Future<DeviceCredentialBundle?> load(String credentialId) async {
    final current = value;
    return current?.credentialId == credentialId ? current : null;
  }

  @override
  Future<void> save(DeviceCredentialBundle credential) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('injected secure storage failure');
    }
    final current = value;
    if (current != null && current.credentialId != credential.credentialId) {
      throw StateError('credential conflict');
    }
    value = credential;
  }
}

class FakePairingGateway implements PairingGatewayPort {
  FakePairingGateway(this.now);

  final DateTime now;
  BeginPairingCommand? begunCommand;
  late List<int> proofPayload;
  late List<int> confirmationPayload;
  var beginCalls = 0;
  var completeCalls = 0;
  var confirmCalls = 0;
  var rejectCompleteOnce = false;
  var uncertainConfirmOnce = false;
  var conflictConfirmAfterUncertain = false;
  var tamperBeginAudience = false;
  var returnPrematureToken = false;
  final completeProofs = <List<int>>[];
  final confirmationProofs = <List<int>>[];
  var _confirmWasUncertain = false;

  static const audience = 'https://gateway.example';
  static const gatewayFingerprint =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  static const pairingId = 'pairing_00000000-0000-4000-8000-000000000001';
  static const deviceId = 'device_00000000-0000-4000-8000-000000000002';
  static const credentialId = 'credential_00000000-0000-4000-8000-000000000003';
  static const scopes = ['observe'];

  @override
  Future<BegunPairing> begin(BeginPairingCommand command) async {
    beginCalls += 1;
    begunCommand = command;
    final digest = await Sha256().hash(command.devicePublicKeySpkiDer);
    final fingerprint = 'sha256:${_hex(digest.bytes)}';
    proofPayload = pairingProofPayload(
      pairingId: pairingId,
      challenge: List.filled(32, 7),
      gatewayAudience: audience,
      deviceFingerprint: fingerprint,
      requestedScopes: command.requestedScopes,
    );
    return BegunPairing(
      pairingId: pairingId,
      userCode: 'ABCD-EFGH',
      verificationUri: 'https://gateway.example/pair',
      expiresInSeconds: 600,
      deviceProofPayload: proofPayload,
      deviceFingerprint: fingerprint,
      gatewayFingerprint: gatewayFingerprint,
      gatewayAudience: tamperBeginAudience ? 'https://evil.example' : audience,
    );
  }

  @override
  Future<CompletedPairing> complete(
    String submittedPairingId,
    DeviceSignatureProof proof,
  ) async {
    completeCalls += 1;
    completeProofs.add(List.of(proof.signature));
    if (rejectCompleteOnce) {
      rejectCompleteOnce = false;
      throw const PairingGatewayCallException(
        operation: PairingOperation.complete,
        disposition: PairingGatewayDisposition.rejected,
        code: 'pairing_not_approved',
        safeMessage: 'The owner has not approved this device yet.',
      );
    }
    expect(submittedPairingId, pairingId);
    expect(proof.credentialId, isEmpty);
    expect(proof.nonce, isEmpty);
    expect(await _verify(proofPayload, proof.signature), isTrue);

    final command = begunCommand!;
    final digest = await Sha256().hash(command.devicePublicKeySpkiDer);
    confirmationPayload = pairingConfirmationPayload(
      pairingId: pairingId,
      credentialId: credentialId,
      deviceId: deviceId,
      challenge: List.filled(32, 9),
      gatewayAudience: audience,
      deviceFingerprint: 'sha256:${_hex(digest.bytes)}',
      approvedScopes: scopes,
    );
    return CompletedPairing(
      deviceId: deviceId,
      legacyAccessToken: returnPrematureToken ? 'must-not-exist' : '',
      approvedScopes: scopes,
      credentialId: credentialId,
      confirmationPayload: confirmationPayload,
      gatewayAudience: audience,
      confirmationExpiresInSeconds: 120,
    );
  }

  @override
  Future<ConfirmedPairing> confirm(
    String submittedPairingId,
    String submittedCredentialId,
    DeviceSignatureProof proof,
  ) async {
    confirmCalls += 1;
    confirmationProofs.add(List.of(proof.signature));
    if (uncertainConfirmOnce) {
      uncertainConfirmOnce = false;
      _confirmWasUncertain = true;
      throw const PairingGatewayCallException(
        operation: PairingOperation.confirm,
        disposition: PairingGatewayDisposition.uncertain,
        code: 'transport_lost',
        safeMessage: 'The confirmation response was not received.',
      );
    }
    if (conflictConfirmAfterUncertain && _confirmWasUncertain) {
      throw const PairingGatewayCallException(
        operation: PairingOperation.confirm,
        disposition: PairingGatewayDisposition.rejected,
        code: 'pairing_conflict',
        safeMessage: 'The pairing is no longer awaiting confirmation.',
      );
    }
    expect(submittedPairingId, pairingId);
    expect(submittedCredentialId, credentialId);
    expect(proof.credentialId, credentialId);
    expect(proof.nonce, isEmpty);
    expect(await _verify(confirmationPayload, proof.signature), isTrue);
    return ConfirmedPairing(
      paired: true,
      deviceId: deviceId,
      credentialId: credentialId,
      accessToken: 'ACCESS_TOKEN_0123456789_abcdef',
      refreshToken: 'REFRESH_TOKEN_0123456789_abcdefghijklmnop',
      approvedScopes: scopes,
      accessExpiresAt: now.add(const Duration(minutes: 15)),
      refreshExpiresAt: now.add(const Duration(days: 30)),
      gatewayAudience: audience,
    );
  }

  Future<bool> _verify(List<int> payload, List<int> signature) async {
    final publicKey = SimplePublicKey(
      begunCommand!.devicePublicKeySpkiDer.sublist(12),
      type: KeyPairType.ed25519,
    );
    return Ed25519().verify(
      payload,
      signature: Signature(signature, publicKey: publicKey),
    );
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

class PairingHarness {
  PairingHarness({
    this.rejectCompleteOnce = false,
    this.uncertainConfirmOnce = false,
    this.conflictConfirmAfterUncertain = false,
    this.tamperBeginAudience = false,
    this.returnPrematureToken = false,
  }) {
    gateway = FakePairingGateway(now);
    keyVault = DeviceKeyVault(store: secureValues);
    gateway
      ..rejectCompleteOnce = rejectCompleteOnce
      ..uncertainConfirmOnce = uncertainConfirmOnce
      ..conflictConfirmAfterUncertain = conflictConfirmAfterUncertain
      ..tamperBeginAudience = tamperBeginAudience
      ..returnPrematureToken = returnPrematureToken;
    coordinator = DevicePairingCoordinator(
      keyVault: keyVault,
      checkpointStore: checkpoints,
      credentialStore: credentials,
      gateway: gateway,
      now: () => now,
    );
  }

  final bool rejectCompleteOnce;
  final bool uncertainConfirmOnce;
  final bool conflictConfirmAfterUncertain;
  final bool tamperBeginAudience;
  final bool returnPrematureToken;
  final now = DateTime.utc(2026, 7, 19, 12);
  final secureValues = FakeSecureValueStore();
  final checkpoints = FakePairingCheckpointStore();
  final credentials = FakeDeviceCredentialStore();
  late final FakePairingGateway gateway;
  late final DeviceKeyVault keyVault;
  late final DevicePairingCoordinator coordinator;

  Future<void> begin() => coordinator.begin(
    deviceDisplayName: 'Roco desktop',
    expectedGatewayAudience: FakePairingGateway.audience,
    requestedScopes: const ['send', 'observe'],
  );
}

void main() {
  test(
    'activates credentials only after two locally verified signatures',
    () async {
      final harness = PairingHarness();

      await harness.begin();
      expect(
        harness.coordinator.state.phase,
        PairingPhase.awaitingOwnerApproval,
        reason:
            '${harness.coordinator.state} '
            '${harness.coordinator.state.safeErrorMessage}',
      );
      expect(harness.credentials.value, isNull);

      await harness.coordinator.completeAfterOwnerApproval();
      expect(
        harness.coordinator.state.phase,
        PairingPhase.awaitingConfirmation,
      );
      expect(harness.credentials.value, isNull);

      await harness.coordinator.confirm();
      expect(harness.coordinator.state.phase, PairingPhase.paired);
      expect(
        harness.credentials.value?.credentialId,
        FakePairingGateway.credentialId,
      );
      expect(harness.checkpoints.value, isNull);
      expect(
        harness.secureValues.values.keys.single,
        contains('active-device-key'),
      );
      expect(
        harness.coordinator.state.toString(),
        isNot(
          anyOf(
            contains(harness.credentials.value!.accessToken),
            contains(harness.credentials.value!.refreshToken),
          ),
        ),
      );
    },
  );

  test(
    'does not retry owner approval or confirmation without an explicit action',
    () async {
      final harness = PairingHarness(
        rejectCompleteOnce: true,
        uncertainConfirmOnce: true,
      );
      await harness.begin();

      await harness.coordinator.completeAfterOwnerApproval();
      expect(harness.gateway.completeCalls, 1);
      expect(
        harness.coordinator.state.phase,
        PairingPhase.awaitingOwnerApproval,
      );

      await harness.coordinator.completeAfterOwnerApproval();
      expect(harness.gateway.completeCalls, 2);
      expect(
        harness.gateway.completeProofs[1],
        harness.gateway.completeProofs[0],
      );
      await harness.coordinator.confirm();
      expect(harness.gateway.confirmCalls, 1);
      expect(harness.coordinator.state.phase, PairingPhase.uncertain);
      expect(harness.credentials.value, isNull);

      await harness.coordinator.retryUncertain();
      expect(harness.gateway.confirmCalls, 2);
      expect(
        harness.gateway.confirmationProofs[1],
        harness.gateway.confirmationProofs[0],
      );
      expect(harness.coordinator.state.phase, PairingPhase.paired);
    },
  );

  test(
    'treats changed Gateway facts and premature tokens as uncertain',
    () async {
      final changedAudience = PairingHarness(tamperBeginAudience: true);
      await changedAudience.begin();
      expect(changedAudience.gateway.beginCalls, 1);
      expect(changedAudience.coordinator.state.phase, PairingPhase.uncertain);
      expect(
        changedAudience.coordinator.state.operation,
        PairingOperation.begin,
      );
      await expectLater(
        changedAudience.coordinator.retryUncertain(),
        throwsStateError,
      );

      final prematureToken = PairingHarness(returnPrematureToken: true);
      await prematureToken.begin();
      await prematureToken.coordinator.completeAfterOwnerApproval();
      expect(prematureToken.coordinator.state.phase, PairingPhase.uncertain);
      expect(prematureToken.credentials.value, isNull);
    },
  );

  test(
    'retries only local credential persistence after Confirm succeeds',
    () async {
      final harness = PairingHarness();
      await harness.begin();
      await harness.coordinator.completeAfterOwnerApproval();
      harness.credentials.failNextSave = true;

      await harness.coordinator.confirm();
      expect(harness.gateway.confirmCalls, 1);
      expect(
        harness.coordinator.state.operation,
        PairingOperation.credentialCommit,
      );
      expect(harness.coordinator.state.phase, PairingPhase.uncertain);
      await expectLater(harness.coordinator.abandon(), throwsStateError);

      await harness.coordinator.retryUncertain();
      expect(harness.gateway.confirmCalls, 1);
      expect(harness.credentials.saveCalls, 2);
      expect(harness.coordinator.state.phase, PairingPhase.paired);
    },
  );

  test('keeps an explicit Confirm recovery conflict uncertain', () async {
    final harness = PairingHarness(
      uncertainConfirmOnce: true,
      conflictConfirmAfterUncertain: true,
    );
    await harness.begin();
    await harness.coordinator.completeAfterOwnerApproval();
    await harness.coordinator.confirm();

    await harness.coordinator.retryUncertain();
    expect(harness.gateway.confirmCalls, 2);
    expect(harness.coordinator.state.phase, PairingPhase.uncertain);
    expect(harness.coordinator.state.operation, PairingOperation.confirm);
    await expectLater(harness.coordinator.abandon(), throwsStateError);

    await harness.coordinator.abandon(
      acknowledgeRemoteCredentialMayExist: true,
    );
    expect(harness.coordinator.state.phase, PairingPhase.idle);
  });

  test(
    'restores a saved credential when key promotion was interrupted',
    () async {
      final harness = PairingHarness();
      await harness.begin();
      await harness.coordinator.completeAfterOwnerApproval();
      harness.secureValues.failNextActiveWrite = true;
      await harness.coordinator.confirm();

      expect(harness.credentials.value, isNotNull);
      expect(
        harness.coordinator.state.operation,
        PairingOperation.credentialCommit,
      );
      final restored = DevicePairingCoordinator(
        keyVault: harness.keyVault,
        checkpointStore: harness.checkpoints,
        credentialStore: harness.credentials,
        gateway: harness.gateway,
        now: () => harness.now,
      );
      await restored.restore();
      await restored.retryUncertain();

      expect(restored.state.phase, PairingPhase.paired);
      expect(harness.gateway.confirmCalls, 1);
      expect(
        harness.secureValues.values.keys.single,
        contains('active-device-key'),
      );
    },
  );

  test(
    'restores an uncertain checkpoint without issuing a network call',
    () async {
      final harness = PairingHarness(uncertainConfirmOnce: true);
      await harness.begin();
      await harness.coordinator.completeAfterOwnerApproval();
      await harness.coordinator.confirm();
      expect(harness.coordinator.state.phase, PairingPhase.uncertain);

      final restored = DevicePairingCoordinator(
        keyVault: harness.keyVault,
        checkpointStore: harness.checkpoints,
        credentialStore: harness.credentials,
        gateway: harness.gateway,
        now: () => harness.now,
      );
      await restored.restore();

      expect(restored.state.phase, PairingPhase.uncertain);
      expect(restored.state.operation, PairingOperation.confirm);
      expect(harness.gateway.confirmCalls, 1);
      expect(
        restored.state.toString(),
        isNot(contains(base64UrlEncode(harness.gateway.confirmationPayload))),
      );
    },
  );
}
