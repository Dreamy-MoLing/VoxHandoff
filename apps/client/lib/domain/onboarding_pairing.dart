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
    this.pairingId,
    this.confirmationCode,
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
  final String? pairingId;
  final String? confirmationCode;
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
    Object? pairingId = _unset,
    Object? confirmationCode = _unset,
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
    pairingId: identical(pairingId, _unset)
        ? this.pairingId
        : pairingId as String?,
    confirmationCode: identical(confirmationCode, _unset)
        ? this.confirmationCode
        : confirmationCode as String?,
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
      'pairingId: ${pairingId == null ? 'none' : 'present'}, '
      'confirmationCode: ${confirmationCode == null ? 'none' : 'present'}, '
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
    required List<int> proofSignature,
  });

  Future<OnboardingPairingStatusResult> status({
    required QrPairingPayload payload,
    required String pairingId,
    required String? backupSpkiPin,
  });

  Future<void> cancel({
    required QrPairingPayload payload,
    required String pairingId,
    required String? backupSpkiPin,
  });
}

class OnboardingPairingExchangeResult {
  OnboardingPairingExchangeResult({
    required this.pairingId,
    required this.confirmationCode,
    required this.expiresAt,
    this.backupSpkiPin,
  }) {
    if (pairingId.isEmpty || pairingId.length > 256) {
      throw const OnboardingPairingException(
        'invalid_pairing_id',
        'The Bridge returned an invalid pairing identifier.',
      );
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(confirmationCode)) {
      throw const OnboardingPairingException(
        'invalid_confirmation_code',
        'The Bridge returned an invalid host confirmation code.',
      );
    }
  }

  final String pairingId;
  final String confirmationCode;
  final DateTime expiresAt;
  final String? backupSpkiPin;
}

enum OnboardingPairingRemoteStatus {
  waitingHostConfirmation,
  confirmed,
  expired,
  cancelled,
}

class OnboardingPairingStatusResult {
  const OnboardingPairingStatusResult(this.status, {this.credential});

  final OnboardingPairingRemoteStatus status;
  final OnboardingCredentialMaterial? credential;
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
