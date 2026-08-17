import 'onboarding_device_key.dart';
import 'onboarding_credential.dart';
import 'qr_pairing.dart';

enum OnboardingPairingPhase {
  pending,
  scanning,
  keygen,
  exchange,
  waitingHostConfirmation,
  confirmed,
  expired,
  cancelled,
  failed,
  uncertain,
}

class OnboardingPairingState {
  const OnboardingPairingState({
    this.phase = OnboardingPairingPhase.pending,
    this.payload,
    this.deviceKey,
    this.deviceName,
    this.deviceId,
    this.deviceFingerprint,
    this.pairingRequestId,
    this.challenge,
    this.expiresAt,
    this.backupSpkiPin,
    this.credentialReference,
    this.errorCode,
    this.safeErrorMessage,
  });

  final OnboardingPairingPhase phase;
  final QrPairingPayload? payload;
  final OnboardingDeviceKeyIdentity? deviceKey;
  final String? deviceName;
  final String? deviceId;
  final String? deviceFingerprint;
  final String? pairingRequestId;
  final String? challenge;
  final DateTime? expiresAt;
  final String? backupSpkiPin;
  final OnboardingCredentialReference? credentialReference;
  final String? errorCode;
  final String? safeErrorMessage;

  bool get isTerminal => switch (phase) {
    OnboardingPairingPhase.confirmed ||
    OnboardingPairingPhase.expired ||
    OnboardingPairingPhase.cancelled ||
    OnboardingPairingPhase.failed ||
    OnboardingPairingPhase.uncertain => true,
    _ => false,
  };

  OnboardingPairingState copyWith({
    OnboardingPairingPhase? phase,
    Object? payload = _unset,
    Object? deviceKey = _unset,
    Object? deviceName = _unset,
    Object? deviceId = _unset,
    Object? deviceFingerprint = _unset,
    Object? pairingRequestId = _unset,
    Object? challenge = _unset,
    Object? expiresAt = _unset,
    Object? backupSpkiPin = _unset,
    Object? credentialReference = _unset,
    Object? errorCode = _unset,
    Object? safeErrorMessage = _unset,
  }) => OnboardingPairingState(
    phase: phase ?? this.phase,
    payload: identical(payload, _unset)
        ? this.payload
        : payload as QrPairingPayload?,
    deviceKey: identical(deviceKey, _unset)
        ? this.deviceKey
        : deviceKey as OnboardingDeviceKeyIdentity?,
    deviceName: identical(deviceName, _unset)
        ? this.deviceName
        : deviceName as String?,
    deviceId: identical(deviceId, _unset)
        ? this.deviceId
        : deviceId as String?,
    deviceFingerprint: identical(deviceFingerprint, _unset)
        ? this.deviceFingerprint
        : deviceFingerprint as String?,
    pairingRequestId: identical(pairingRequestId, _unset)
        ? this.pairingRequestId
        : pairingRequestId as String?,
    challenge: identical(challenge, _unset)
        ? this.challenge
        : challenge as String?,
    expiresAt: identical(expiresAt, _unset)
        ? this.expiresAt
        : expiresAt as DateTime?,
    backupSpkiPin: identical(backupSpkiPin, _unset)
        ? this.backupSpkiPin
        : backupSpkiPin as String?,
    credentialReference: identical(credentialReference, _unset)
        ? this.credentialReference
        : credentialReference as OnboardingCredentialReference?,
    errorCode: identical(errorCode, _unset)
        ? this.errorCode
        : errorCode as String?,
    safeErrorMessage: identical(safeErrorMessage, _unset)
        ? this.safeErrorMessage
        : safeErrorMessage as String?,
  );

  @override
  String toString() =>
      'OnboardingPairingState(phase: ${phase.name}, '
      'pairingRequestId: ${pairingRequestId == null ? 'none' : 'present'}, '
      'challenge: ${challenge == null ? 'none' : 'present'}, '
      'redacted: true)';
}

abstract interface class OnboardingDeviceKeyReferenceStore {
  Future<void> save(String keyReference);

  Future<void> delete();
}

abstract interface class OnboardingPairingExchangePort {
  Future<OnboardingPairingExchangeResult> exchange({
    required QrPairingPayload payload,
    required String deviceName,
    required OnboardingDeviceKeyIdentity deviceKey,
  });

  Future<OnboardingPairingStatusResult> status({
    required QrPairingPayload payload,
    required String pairingRequestId,
    required String? backupSpkiPin,
  });

  Future<OnboardingCredentialMaterial> complete({
    required QrPairingPayload payload,
    required String pairingRequestId,
    required String deviceId,
    required OnboardingDeviceKeyIdentity deviceKey,
    required List<int> deviceSignature,
    required String? backupSpkiPin,
  });

  Future<void> cancel({
    required QrPairingPayload payload,
    required String pairingRequestId,
    required String? backupSpkiPin,
  });
}

class OnboardingPairingExchangeResult {
  OnboardingPairingExchangeResult({
    required this.pairingRequestId,
    required this.deviceId,
    required this.deviceName,
    required this.deviceFingerprint,
    required this.challenge,
    required this.status,
    required this.expiresAt,
  }) {
    if (pairingRequestId.isEmpty || pairingRequestId.length > 256) {
      throw const OnboardingPairingException(
        'invalid_pairing_request_id',
        'The Bridge returned an invalid pairing identifier.',
      );
    }
    if (deviceId.isEmpty || deviceId.length > 256) {
      throw const OnboardingPairingException(
        'invalid_device_id',
        'The Bridge returned an invalid device identifier.',
      );
    }
    if (deviceName.isEmpty || deviceName.length > 120) {
      throw const OnboardingPairingException(
        'invalid_device_name',
        'The Bridge returned an invalid device name.',
      );
    }
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(deviceFingerprint)) {
      throw const OnboardingPairingException(
        'invalid_device_fingerprint',
        'The Bridge returned an invalid device fingerprint.',
      );
    }
    if (challenge.isEmpty || challenge.length > 256) {
      throw const OnboardingPairingException(
        'invalid_pairing_challenge',
        'The Bridge returned an invalid pairing challenge.',
      );
    }
    if (status != OnboardingPairingRemoteStatus.awaitingConfirmation) {
      throw const OnboardingPairingException(
        'unexpected_exchange_status',
        '主机没有进入等待确认状态。',
      );
    }
  }

  final String pairingRequestId;
  final String deviceId;
  final String deviceName;
  final String deviceFingerprint;
  final String challenge;
  final OnboardingPairingRemoteStatus status;
  final DateTime expiresAt;
}

enum OnboardingPairingRemoteStatus {
  awaitingConfirmation,
  confirmed,
  expired,
  cancelled,
}

class OnboardingPairingStatusResult {
  const OnboardingPairingStatusResult({
    required this.pairingRequestId,
    required this.status,
    required this.expiresAt,
  });

  final String pairingRequestId;
  final OnboardingPairingRemoteStatus status;
  final DateTime expiresAt;
}

class OnboardingPairingException implements Exception {
  const OnboardingPairingException(
    this.code,
    this.message, {
    this.acceptanceUncertain = false,
  });

  final String code;
  final String message;
  final bool acceptanceUncertain;

  @override
  String toString() => 'OnboardingPairingException($code)';
}

const _unset = Object();
