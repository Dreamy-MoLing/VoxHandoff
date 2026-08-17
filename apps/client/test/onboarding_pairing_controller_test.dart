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
    'follows scan, keygen, exchange, host confirmation and confirmed',
    () async {
      final keyPort = _FakeDeviceKeyPort();
      final keyStore = _FakeKeyReferenceStore();
      final exchange =
          _FakeExchange(
              OnboardingPairingExchangeResult(
                pairingId: 'pairing-1',
                confirmationCode: '482731',
                expiresAt: expiry,
                backupSpkiPin: _pin(0x11),
              ),
            )
            ..statusResult = const OnboardingPairingStatusResult(
              OnboardingPairingRemoteStatus.confirmed,
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
      expect(controller.state.confirmationCode, '482731');
      expect(controller.state.backupSpkiPin, _pin(0x11));
      expect(keyStore.savedReference, keyPort.identity.keyReference);
      expect(exchange.proofSignature, [1, 2, 3]);
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
    final exchange = _FakeExchange()..exchangeError = const _ExchangeFailure();
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

  test(
    'cancelling waiting confirmation revokes the pending local key',
    () async {
      final keyPort = _FakeDeviceKeyPort();
      final keyStore = _FakeKeyReferenceStore();
      final controller = OnboardingPairingController(
        deviceKeyPort: keyPort,
        keyReferenceStore: keyStore,
        exchangePort: _FakeExchange(
          OnboardingPairingExchangeResult(
            pairingId: 'pairing-1',
            confirmationCode: '482731',
            expiresAt: expiry,
          ),
        ),
        now: () => now,
      );
      addTearDown(controller.dispose);

      await controller.acceptQrCode(_qr(expiry));
      await controller.cancel();

      expect(controller.state.phase, OnboardingPairingPhase.cancelled);
      expect(keyPort.deletedReferences, [keyPort.identity.keyReference]);
      expect(keyStore.deleted, isTrue);
    },
  );

  test(
    'persists the per-device credential only after host confirmation',
    () async {
      final credentialVault = _FakeCredentialVault();
      final exchange =
          _FakeExchange(
              OnboardingPairingExchangeResult(
                pairingId: 'pairing-1',
                confirmationCode: '482731',
                expiresAt: expiry,
              ),
            )
            ..statusResult = OnboardingPairingStatusResult(
              OnboardingPairingRemoteStatus.confirmed,
              credential: OnboardingCredentialMaterial(
                credentialId: 'credential-synthetic-1',
                credential: 'synthetic-device-credential-only',
                bridgeEndpoint: Uri.parse('https://bridge.example/companion'),
                serverId: 'synthetic-server',
                deviceKeyReference: '0123456789abcdef0123456789abcdef',
                spkiPin: _pin(0x07),
                issuedAt: now,
              ),
            );
      final controller = OnboardingPairingController(
        deviceKeyPort: _FakeDeviceKeyPort(),
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
    },
  );
}

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

  @override
  Future<OnboardingDeviceKeyIdentity> create() async {
    createCalls += 1;
    return identity;
  }

  @override
  Future<OnboardingDeviceKeyIdentity> inspect(String keyReference) async =>
      identity;

  @override
  Future<List<int>> sign(String keyReference, List<int> payload) async => [
    1,
    2,
    3,
  ];

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
  OnboardingPairingStatusResult statusResult =
      const OnboardingPairingStatusResult(
        OnboardingPairingRemoteStatus.waitingHostConfirmation,
      );
  OnboardingPairingException? exchangeError;
  List<int>? proofSignature;
  var cancelCalls = 0;

  @override
  Future<OnboardingPairingExchangeResult> exchange({
    required payload,
    required deviceName,
    required deviceKey,
    required List<int> proofSignature,
  }) async {
    this.proofSignature = proofSignature;
    final error = exchangeError;
    if (error != null) throw error;
    return exchangeResult!;
  }

  @override
  Future<OnboardingPairingStatusResult> status({
    required payload,
    required pairingId,
    required backupSpkiPin,
  }) async => statusResult;

  @override
  Future<void> cancel({
    required payload,
    required pairingId,
    required backupSpkiPin,
  }) async {
    cancelCalls += 1;
  }
}

class _ExchangeFailure extends OnboardingPairingException {
  const _ExchangeFailure()
    : super('exchange_failed', 'synthetic exchange failure');
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
