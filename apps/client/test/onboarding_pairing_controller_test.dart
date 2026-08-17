import 'dart:convert';

import 'package:agent_talk_client/application/onboarding_pairing_controller.dart';
import 'package:agent_talk_client/domain/onboarding_device_key.dart';
import 'package:agent_talk_client/domain/onboarding_credential.dart';
import 'package:agent_talk_client/domain/onboarding_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 17, 12);
  final expiry = now.add(const Duration(minutes: 3));

  test(
    'follows scan, keygen, exchange, host confirmation, complete and confirmed',
    () async {
      final keyPort = _FakeDeviceKeyPort();
      final keyStore = _FakeKeyReferenceStore();
      final exchange = _FakeExchange(
        _exchangeResult(keyPort.identity, deviceName: 'vivo V2359A'),
      )
        ..statusResult = OnboardingPairingStatusResult(
          pairingRequestId: 'pairing-1',
          status: OnboardingPairingRemoteStatus.confirmed,
          expiresAt: expiry,
        );
      final controller = OnboardingPairingController(
        deviceKeyPort: keyPort,
        keyReferenceStore: keyStore,
        exchangePort: exchange,
        now: () => now,
      );
      addTearDown(controller.dispose);

      final phases = <OnboardingPairingPhase>[];
      controller.addListener(() => phases.add(controller.state.phase));
      controller.startScanning();
      await controller.acceptQrCode(_qr(expiry), deviceName: 'vivo V2359A');

      expect(
        controller.state.phase,
        OnboardingPairingPhase.waitingHostConfirmation,
      );
      expect(controller.state.deviceName, 'vivo V2359A');
      expect(controller.state.pairingRequestId, 'pairing-1');
      expect(controller.state.challenge, 'challenge-1');
      expect(controller.state.backupSpkiPin, isNull);
      expect(keyStore.savedReference, keyPort.identity.keyReference);
      expect(
        keyPort.signedPayload,
        isNull,
      );
      expect(
        phases,
        containsAllInOrder([
          OnboardingPairingPhase.scanning,
          OnboardingPairingPhase.keygen,
          OnboardingPairingPhase.exchange,
          OnboardingPairingPhase.waitingHostConfirmation,
        ]),
      );

      await controller.refreshHostStatus();
      expect(controller.state.phase, OnboardingPairingPhase.confirmed);
      expect(exchange.completeCalls, 1);
      expect(
        keyPort.signedPayload,
        utf8.encode(
          'voxhandoff/companion-bridge/pairing-complete/v1\u0000'
          'pairing-1\u0000challenge-1',
        ),
      );
      expect(keyPort.deletedReferences, isEmpty);
    },
  );

  test('rejects an invalid QR before generating a device key', () async {
    final keyPort = _FakeDeviceKeyPort();
    final controller = OnboardingPairingController(
      deviceKeyPort: keyPort,
      keyReferenceStore: _FakeKeyReferenceStore(),
      exchangePort: _FakeExchange(),
      now: () => now,
    );
    addTearDown(controller.dispose);

    controller.startScanning();
    await controller.acceptQrCode('{"protocol_version":99}');

    expect(controller.state.phase, OnboardingPairingPhase.pending);
    expect(controller.state.errorCode, 'unsupported_protocol_version');
    expect(keyPort.createCalls, 0);
  });

  test('keeps an uncertain exchange from being retried silently', () async {
    final keyPort = _FakeDeviceKeyPort();
    final keyStore = _FakeKeyReferenceStore();
    final exchange = _FakeExchange()
      ..exchangeError = const _ExchangeFailure();
    final controller = OnboardingPairingController(
      deviceKeyPort: keyPort,
      keyReferenceStore: keyStore,
      exchangePort: exchange,
      now: () => now,
    );
    addTearDown(controller.dispose);

    await controller.acceptQrCode(_qr(expiry));

    expect(controller.state.phase, OnboardingPairingPhase.uncertain);
    expect(controller.state.errorCode, 'exchange_failed');
    expect(keyStore.savedReference, isNotNull);
    expect(keyPort.deletedReferences, isEmpty);
  });

  test('complete failure remains uncertain and keeps the device key', () async {
    final keyPort = _FakeDeviceKeyPort();
    final exchange = _FakeExchange(_exchangeResult(keyPort.identity))
      ..statusResult = OnboardingPairingStatusResult(
        pairingRequestId: 'pairing-1',
        status: OnboardingPairingRemoteStatus.confirmed,
        expiresAt: expiry,
      )
      ..completeError = const _CompleteFailure();
    final controller = OnboardingPairingController(
      deviceKeyPort: keyPort,
      keyReferenceStore: _FakeKeyReferenceStore(),
      exchangePort: exchange,
      now: () => now,
    );
    addTearDown(controller.dispose);

    await controller.acceptQrCode(_qr(expiry));
    await controller.refreshHostStatus();

    expect(controller.state.phase, OnboardingPairingPhase.uncertain);
    expect(controller.state.errorCode, 'complete_failed');
    expect(keyPort.deletedReferences, isEmpty);
  });

  test('cancelling waiting confirmation revokes the pending local key', () async {
    final keyPort = _FakeDeviceKeyPort();
    final keyStore = _FakeKeyReferenceStore();
    final controller = OnboardingPairingController(
      deviceKeyPort: keyPort,
      keyReferenceStore: keyStore,
      exchangePort: _FakeExchange(_exchangeResult(keyPort.identity)),
      now: () => now,
    );
    addTearDown(controller.dispose);

    await controller.acceptQrCode(_qr(expiry));
    await controller.cancel();

    expect(controller.state.phase, OnboardingPairingPhase.cancelled);
    expect(keyPort.deletedReferences, [keyPort.identity.keyReference]);
    expect(keyStore.deleted, isTrue);
  });

  test('persists the per-device credential only after complete', () async {
    final keyPort = _FakeDeviceKeyPort();
    final credentialVault = _FakeCredentialVault();
    final exchange = _FakeExchange(_exchangeResult(keyPort.identity))
      ..statusResult = OnboardingPairingStatusResult(
        pairingRequestId: 'pairing-1',
        status: OnboardingPairingRemoteStatus.confirmed,
        expiresAt: expiry,
      )
      ..completeResult = OnboardingCredentialMaterial(
        credentialId: 'credential-synthetic-1',
        credential: 'synthetic-device-credential-only',
        bridgeEndpoint: Uri.parse('https://bridge.example/companion'),
        serverId: 'synthetic-server',
        deviceKeyReference: keyPort.identity.keyReference,
        spkiPin: _pin(0x07),
        issuedAt: now,
      );
    final controller = OnboardingPairingController(
      deviceKeyPort: keyPort,
      keyReferenceStore: _FakeKeyReferenceStore(),
      exchangePort: exchange,
      credentialVault: credentialVault,
      now: () => now,
    );
    addTearDown(controller.dispose);

    await controller.acceptQrCode(_qr(expiry));
    await controller.refreshHostStatus();

    expect(controller.state.phase, OnboardingPairingPhase.confirmed);
    expect(
      controller.state.credentialReference?.credentialId,
      'credential-synthetic-1',
    );
    expect(credentialVault.saved, isTrue);
  });
}

OnboardingPairingExchangeResult _exchangeResult(
  OnboardingDeviceKeyIdentity identity, {
  String deviceName = '此设备',
}) => OnboardingPairingExchangeResult(
  pairingRequestId: 'pairing-1',
  deviceId: 'device-1',
  deviceName: deviceName,
  deviceFingerprint: identity.fingerprint,
  challenge: 'challenge-1',
  status: OnboardingPairingRemoteStatus.awaitingConfirmation,
  expiresAt: DateTime.utc(2026, 8, 17, 12, 3),
);

String _qr(DateTime expiresAt) => jsonEncode({
  'protocol_version': 1,
  'bridge_endpoint': 'https://bridge.example/companion',
  'server_id': 'synthetic-server',
  'pairing_session_id': 'synthetic-session',
  'spki_pin': _pin(0x07),
  'pairing_token': 'synthetic-token-only-for-test',
  'expires_at': expiresAt.toIso8601String(),
});

String _pin(int byte) => 'sha256/${base64Encode(List<int>.filled(32, byte))}';

class _FakeDeviceKeyPort implements OnboardingDeviceKeyPort {
  final identity = OnboardingDeviceKeyIdentity(
    keyReference: '0123456789abcdef0123456789abcdef',
    publicKeySpkiDer: List<int>.filled(91, 4),
    fingerprint: 'sha256${':'}${'a' * 64}',
    hardwareBacked: true,
    strongBoxBacked: false,
  );
  var createCalls = 0;
  final deletedReferences = <String>[];
  List<int>? signedPayload;

  @override
  Future<OnboardingDeviceKeyIdentity> create() async {
    createCalls += 1;
    return identity;
  }

  @override
  Future<OnboardingDeviceKeyIdentity> inspect(String keyReference) async =>
      identity;

  @override
  Future<List<int>> sign(String keyReference, List<int> payload) async {
    signedPayload = payload;
    return [1, 2, 3];
  }

  @override
  Future<void> delete(String keyReference) async =>
      deletedReferences.add(keyReference);
}

class _FakeKeyReferenceStore implements OnboardingDeviceKeyReferenceStore {
  String? savedReference;
  var deleted = false;

  @override
  Future<void> save(String keyReference) async => savedReference = keyReference;

  @override
  Future<void> delete() async => deleted = true;
}

class _FakeExchange implements OnboardingPairingExchangePort {
  _FakeExchange([this.exchangeResult]);

  final OnboardingPairingExchangeResult? exchangeResult;
  OnboardingPairingStatusResult statusResult = OnboardingPairingStatusResult(
    pairingRequestId: 'pairing-1',
    status: OnboardingPairingRemoteStatus.awaitingConfirmation,
    expiresAt: DateTime.utc(2026, 8, 17, 12, 3),
  );
  OnboardingCredentialMaterial? completeResult;
  OnboardingPairingException? exchangeError;
  OnboardingPairingException? completeError;
  var completeCalls = 0;

  @override
  Future<OnboardingPairingExchangeResult> exchange({
    required payload,
    required deviceName,
    required deviceKey,
  }) async {
    final error = exchangeError;
    if (error != null) throw error;
    return exchangeResult!;
  }

  @override
  Future<OnboardingPairingStatusResult> status({
    required payload,
    required pairingRequestId,
    required backupSpkiPin,
  }) async => statusResult;

  @override
  Future<OnboardingCredentialMaterial> complete({
    required payload,
    required pairingRequestId,
    required deviceId,
    required deviceKey,
    required deviceSignature,
    required backupSpkiPin,
  }) async {
    completeCalls += 1;
    final error = completeError;
    if (error != null) throw error;
    return completeResult ??
        OnboardingCredentialMaterial(
          credentialId: 'credential-synthetic-1',
          credential: 'synthetic-device-credential-only',
          bridgeEndpoint: payload.bridgeEndpoint,
          serverId: payload.serverId,
          deviceKeyReference: deviceKey.keyReference,
          spkiPin: payload.spkiPin,
          issuedAt: DateTime.utc(2026, 8, 17, 12),
        );
  }

  @override
  Future<void> cancel({
    required payload,
    required pairingRequestId,
    required backupSpkiPin,
  }) async {}
}

class _ExchangeFailure extends OnboardingPairingException {
  const _ExchangeFailure() : super('exchange_failed', 'synthetic exchange failure');
}

class _CompleteFailure extends OnboardingPairingException {
  const _CompleteFailure() : super('complete_failed', 'synthetic complete failure');
}

class _FakeCredentialVault implements OnboardingCredentialVault {
  var saved = false;

  @override
  Future<OnboardingCredentialReference> save(
    OnboardingCredentialMaterial material,
  ) async {
    saved = true;
    return OnboardingCredentialReference(
      credentialId: material.credentialId,
      bridgeEndpoint: material.bridgeEndpoint,
      serverId: material.serverId,
      deviceKeyReference: material.deviceKeyReference,
      spkiPin: material.spkiPin,
      backupSpkiPin: material.backupSpkiPin,
      issuedAt: material.issuedAt,
    );
  }

  @override
  Future<OnboardingCredentialReference?> loadReference() async => null;

  @override
  Future<OnboardingCredentialMaterial?> readMaterial(
    String credentialId,
  ) async => null;

  @override
  Future<void> revoke(String credentialId) async {}
}
