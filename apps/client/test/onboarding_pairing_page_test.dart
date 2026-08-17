import 'dart:convert';

import 'package:agent_talk_client/application/onboarding_pairing_controller.dart';
import 'package:agent_talk_client/domain/onboarding_device_key.dart';
import 'package:agent_talk_client/domain/onboarding_credential.dart';
import 'package:agent_talk_client/domain/onboarding_pairing.dart';
import 'package:agent_talk_client/presentation/onboarding_pairing_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows device name and waiting state after scanning', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 12);
    final expiry = now.add(const Duration(minutes: 3));
    final controller = OnboardingPairingController(
      deviceKeyPort: _FakeDeviceKeyPort(),
      keyReferenceStore: _FakeKeyReferenceStore(),
      exchangePort: _FakeExchange(
        OnboardingPairingExchangeResult(
          pairingRequestId: 'pairing-1',
          deviceId: 'device-1',
          deviceName: 'vivo V2359A',
          deviceFingerprint: _FakeDeviceKeyPort().identity.fingerprint,
          challenge: 'challenge-1',
          status: OnboardingPairingRemoteStatus.awaitingConfirmation,
          expiresAt: expiry,
        ),
      ),
      now: () => now,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPairingPage(
          controller: controller,
          scanQr: (_) async => _qr(expiry),
        ),
      ),
    );
    expect(
      find.byKey(const Key('onboarding-device-name-field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding-scan-button')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onboarding-device-name-field')),
      'vivo V2359A',
    );
    await tester.tap(find.byKey(const Key('onboarding-scan-button')));
    await tester.pumpAndSettle();

    expect(find.text('请在主机上确认这台设备'), findsOneWidget);
    expect(find.text('等待主机确认'), findsOneWidget);
    expect(find.text('vivo V2359A'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-confirmation-code')), findsNothing);
  });
}

String _qr(DateTime expiresAt) => jsonEncode({
  'protocol_version': 1,
  'bridge_endpoint': 'https://bridge.example/companion',
  'server_id': 'synthetic-server',
  'pairing_session_id': 'synthetic-session',
  'spki_pin': 'sha256/${base64Encode(List<int>.filled(32, 7))}',
  'pairing_token': 'synthetic-token-only-for-test',
  'expires_at': expiresAt.toIso8601String(),
});

class _FakeDeviceKeyPort implements OnboardingDeviceKeyPort {
  final identity = OnboardingDeviceKeyIdentity(
    keyReference: '0123456789abcdef0123456789abcdef',
    publicKeySpkiDer: List<int>.filled(91, 4),
    fingerprint: 'sha256${':'}${'a' * 64}',
    hardwareBacked: true,
    strongBoxBacked: false,
  );

  @override
  Future<OnboardingDeviceKeyIdentity> create() async => identity;

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
  Future<void> delete(String keyReference) async {}
}

class _FakeKeyReferenceStore implements OnboardingDeviceKeyReferenceStore {
  @override
  Future<void> save(String keyReference) async {}

  @override
  Future<void> delete() async {}
}

class _FakeExchange implements OnboardingPairingExchangePort {
  _FakeExchange(this.result);

  final OnboardingPairingExchangeResult result;

  @override
  Future<OnboardingPairingExchangeResult> exchange({
    required payload,
    required deviceName,
    required deviceKey,
  }) async => result;

  @override
  Future<OnboardingPairingStatusResult> status({
    required payload,
    required pairingRequestId,
    required backupSpkiPin,
  }) async => OnboardingPairingStatusResult(
    pairingRequestId: pairingRequestId,
    status: OnboardingPairingRemoteStatus.awaitingConfirmation,
    expiresAt: DateTime.utc(2026, 8, 17, 12, 3),
  );

  @override
  Future<OnboardingCredentialMaterial> complete({
    required payload,
    required pairingRequestId,
    required deviceId,
    required deviceKey,
    required deviceSignature,
    required backupSpkiPin,
  }) async => OnboardingCredentialMaterial(
    credentialId: 'credential-synthetic-1',
    credential: 'synthetic-device-credential-only',
    bridgeEndpoint: payload.bridgeEndpoint,
    serverId: payload.serverId,
    deviceKeyReference: deviceKey.keyReference,
    spkiPin: payload.spkiPin,
    issuedAt: DateTime.utc(2026, 8, 17, 12),
  );

  @override
  Future<void> cancel({
    required payload,
    required pairingRequestId,
    required backupSpkiPin,
  }) async {}
}
