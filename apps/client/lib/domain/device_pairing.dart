enum PairingPhase {
  idle,
  beginning,
  awaitingOwnerApproval,
  completing,
  awaitingConfirmation,
  confirming,
  paired,
  failed,
  uncertain,
}

enum PairingOperation {
  localValidation,
  begin,
  complete,
  confirm,
  credentialCommit,
}

enum PairingCheckpointPhase {
  beginPrepared,
  begun,
  proofPrepared,
  completed,
  confirmationPrepared,
}

enum PairingGatewayDisposition { rejected, uncertain }

class DevicePublicIdentity {
  DevicePublicIdentity({
    required this.keyReference,
    required List<int> publicKeySpkiDer,
    required this.fingerprint,
  }) : publicKeySpkiDer = List.unmodifiable(publicKeySpkiDer);

  final String keyReference;
  final List<int> publicKeySpkiDer;
  final String fingerprint;

  @override
  String toString() =>
      'DevicePublicIdentity(keyReference: $keyReference, fingerprint: $fingerprint)';
}

abstract interface class DeviceKeyVaultPort {
  Future<DevicePublicIdentity> createPendingKey();

  Future<DevicePublicIdentity> inspect(String keyReference);

  Future<List<int>> sign(String keyReference, List<int> payload);

  Future<void> discard(String keyReference);

  Future<void> promotePendingKey(String keyReference, String credentialId);
}

class PairingState {
  PairingState({
    this.phase = PairingPhase.idle,
    this.operation,
    this.deviceDisplayName,
    this.pairingId,
    this.userCode,
    this.verificationUri,
    this.deviceFingerprint,
    this.gatewayFingerprint,
    this.gatewayAudience,
    Iterable<String> requestedScopes = const [],
    Iterable<String> approvedScopes = const [],
    this.deviceId,
    this.credentialId,
    this.safeErrorCode,
    this.safeErrorMessage,
  }) : requestedScopes = List.unmodifiable(requestedScopes),
       approvedScopes = List.unmodifiable(approvedScopes);

  final PairingPhase phase;
  final PairingOperation? operation;
  final String? deviceDisplayName;
  final String? pairingId;
  final String? userCode;
  final Uri? verificationUri;
  final String? deviceFingerprint;
  final String? gatewayFingerprint;
  final String? gatewayAudience;
  final List<String> requestedScopes;
  final List<String> approvedScopes;
  final String? deviceId;
  final String? credentialId;
  final String? safeErrorCode;
  final String? safeErrorMessage;

  bool get canComplete => phase == PairingPhase.awaitingOwnerApproval;
  bool get canConfirm => phase == PairingPhase.awaitingConfirmation;
  bool get requiresExplicitRecovery => phase == PairingPhase.uncertain;

  @override
  String toString() =>
      'PairingState(phase: $phase, operation: $operation, pairingId: $pairingId, '
      'deviceFingerprint: $deviceFingerprint, gatewayFingerprint: '
      '$gatewayFingerprint, safeErrorCode: $safeErrorCode)';
}

class BeginPairingCommand {
  BeginPairingCommand({
    required this.deviceDisplayName,
    required List<int> devicePublicKeySpkiDer,
    required Iterable<String> requestedScopes,
    required this.expectedGatewayAudience,
  }) : devicePublicKeySpkiDer = List.unmodifiable(devicePublicKeySpkiDer),
       requestedScopes = List.unmodifiable(requestedScopes);

  final String deviceDisplayName;
  final List<int> devicePublicKeySpkiDer;
  final List<String> requestedScopes;
  final String expectedGatewayAudience;
}

class BegunPairing {
  BegunPairing({
    required this.pairingId,
    required this.userCode,
    required this.verificationUri,
    required this.expiresInSeconds,
    required List<int> deviceProofPayload,
    required this.deviceFingerprint,
    required this.gatewayFingerprint,
    required this.gatewayAudience,
  }) : deviceProofPayload = List.unmodifiable(deviceProofPayload);

  final String pairingId;
  final String userCode;
  final String verificationUri;
  final int expiresInSeconds;
  final List<int> deviceProofPayload;
  final String deviceFingerprint;
  final String gatewayFingerprint;
  final String gatewayAudience;
}

class DeviceSignatureProof {
  DeviceSignatureProof({
    this.credentialId = '',
    Iterable<int> nonce = const [],
    required Iterable<int> signature,
  }) : nonce = List.unmodifiable(nonce),
       signature = List.unmodifiable(signature);

  final String credentialId;
  final List<int> nonce;
  final List<int> signature;

  @override
  String toString() =>
      'DeviceSignatureProof(credentialId: $credentialId, redacted: true)';
}

class CompletedPairing {
  CompletedPairing({
    required this.deviceId,
    this.legacyAccessToken = '',
    this.legacyRefreshToken = '',
    required Iterable<String> approvedScopes,
    required this.credentialId,
    required Iterable<int> confirmationPayload,
    required this.gatewayAudience,
    required this.confirmationExpiresInSeconds,
  }) : approvedScopes = List.unmodifiable(approvedScopes),
       confirmationPayload = List.unmodifiable(confirmationPayload);

  final String deviceId;
  final String legacyAccessToken;
  final String legacyRefreshToken;
  final List<String> approvedScopes;
  final String credentialId;
  final List<int> confirmationPayload;
  final String gatewayAudience;
  final int confirmationExpiresInSeconds;
}

class ConfirmedPairing {
  ConfirmedPairing({
    required this.paired,
    required this.deviceId,
    required this.credentialId,
    required this.accessToken,
    required this.refreshToken,
    required Iterable<String> approvedScopes,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.gatewayAudience,
  }) : approvedScopes = List.unmodifiable(approvedScopes);

  final bool paired;
  final String deviceId;
  final String credentialId;
  final String accessToken;
  final String refreshToken;
  final List<String> approvedScopes;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;
  final String gatewayAudience;

  @override
  String toString() =>
      'ConfirmedPairing(paired: $paired, deviceId: $deviceId, '
      'credentialId: $credentialId, redacted: true)';
}

abstract interface class PairingGatewayPort {
  Future<BegunPairing> begin(BeginPairingCommand command);

  Future<CompletedPairing> complete(
    String pairingId,
    DeviceSignatureProof proof,
  );

  Future<ConfirmedPairing> confirm(
    String pairingId,
    String credentialId,
    DeviceSignatureProof proof,
  );
}

class PairingGatewayCallException implements Exception {
  const PairingGatewayCallException({
    required this.operation,
    required this.disposition,
    required this.code,
    required this.safeMessage,
  });

  final PairingOperation operation;
  final PairingGatewayDisposition disposition;
  final String code;
  final String safeMessage;

  @override
  String toString() =>
      'PairingGatewayCallException(operation: $operation, disposition: '
      '$disposition, code: $code)';
}

class PairingCheckpoint {
  PairingCheckpoint({
    required this.phase,
    required this.keyReference,
    required this.deviceDisplayName,
    required this.expectedGatewayAudience,
    required Iterable<String> requestedScopes,
    this.pairingId,
    this.userCode,
    this.verificationUri,
    this.expiresAt,
    this.deviceFingerprint,
    this.gatewayFingerprint,
    this.gatewayAudience,
    Iterable<int>? deviceProofPayload,
    Iterable<int>? proofSignature,
    this.deviceId,
    this.credentialId,
    Iterable<String> approvedScopes = const [],
    Iterable<int>? confirmationPayload,
    Iterable<int>? confirmationSignature,
    this.confirmationExpiresAt,
    this.uncertainOperation,
  }) : requestedScopes = List.unmodifiable(requestedScopes),
       approvedScopes = List.unmodifiable(approvedScopes),
       deviceProofPayload = deviceProofPayload == null
           ? null
           : List.unmodifiable(deviceProofPayload),
       proofSignature = proofSignature == null
           ? null
           : List.unmodifiable(proofSignature),
       confirmationPayload = confirmationPayload == null
           ? null
           : List.unmodifiable(confirmationPayload),
       confirmationSignature = confirmationSignature == null
           ? null
           : List.unmodifiable(confirmationSignature);

  final PairingCheckpointPhase phase;
  final String keyReference;
  final String deviceDisplayName;
  final String expectedGatewayAudience;
  final List<String> requestedScopes;
  final String? pairingId;
  final String? userCode;
  final Uri? verificationUri;
  final DateTime? expiresAt;
  final String? deviceFingerprint;
  final String? gatewayFingerprint;
  final String? gatewayAudience;
  final List<int>? deviceProofPayload;
  final List<int>? proofSignature;
  final String? deviceId;
  final String? credentialId;
  final List<String> approvedScopes;
  final List<int>? confirmationPayload;
  final List<int>? confirmationSignature;
  final DateTime? confirmationExpiresAt;
  final PairingOperation? uncertainOperation;

  PairingCheckpoint copyWith({
    PairingCheckpointPhase? phase,
    String? pairingId,
    String? userCode,
    Uri? verificationUri,
    DateTime? expiresAt,
    String? deviceFingerprint,
    String? gatewayFingerprint,
    String? gatewayAudience,
    Iterable<int>? deviceProofPayload,
    Iterable<int>? proofSignature,
    String? deviceId,
    String? credentialId,
    Iterable<String>? approvedScopes,
    Iterable<int>? confirmationPayload,
    Iterable<int>? confirmationSignature,
    DateTime? confirmationExpiresAt,
    PairingOperation? uncertainOperation,
    bool clearUncertainOperation = false,
  }) => PairingCheckpoint(
    phase: phase ?? this.phase,
    keyReference: keyReference,
    deviceDisplayName: deviceDisplayName,
    expectedGatewayAudience: expectedGatewayAudience,
    requestedScopes: requestedScopes,
    pairingId: pairingId ?? this.pairingId,
    userCode: userCode ?? this.userCode,
    verificationUri: verificationUri ?? this.verificationUri,
    expiresAt: expiresAt ?? this.expiresAt,
    deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
    gatewayFingerprint: gatewayFingerprint ?? this.gatewayFingerprint,
    gatewayAudience: gatewayAudience ?? this.gatewayAudience,
    deviceProofPayload: deviceProofPayload ?? this.deviceProofPayload,
    proofSignature: proofSignature ?? this.proofSignature,
    deviceId: deviceId ?? this.deviceId,
    credentialId: credentialId ?? this.credentialId,
    approvedScopes: approvedScopes ?? this.approvedScopes,
    confirmationPayload: confirmationPayload ?? this.confirmationPayload,
    confirmationSignature: confirmationSignature ?? this.confirmationSignature,
    confirmationExpiresAt: confirmationExpiresAt ?? this.confirmationExpiresAt,
    uncertainOperation: clearUncertainOperation
        ? null
        : uncertainOperation ?? this.uncertainOperation,
  );

  @override
  String toString() =>
      'PairingCheckpoint(phase: $phase, keyReference: $keyReference, '
      'pairingId: $pairingId, uncertainOperation: $uncertainOperation, '
      'redacted: true)';
}

abstract interface class PairingCheckpointStore {
  Future<PairingCheckpoint?> load();

  Future<void> save(PairingCheckpoint checkpoint);

  Future<void> delete();
}

class DeviceCredentialBundle {
  DeviceCredentialBundle({
    required this.keyReference,
    required this.deviceId,
    required this.credentialId,
    required this.gatewayAudience,
    required Iterable<String> scopes,
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  }) : scopes = List.unmodifiable(scopes);

  final String keyReference;
  final String deviceId;
  final String credentialId;
  final String gatewayAudience;
  final List<String> scopes;
  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
  final DateTime refreshExpiresAt;

  @override
  String toString() =>
      'DeviceCredentialBundle(keyReference: $keyReference, deviceId: '
      '$deviceId, credentialId: $credentialId, gatewayAudience: '
      '$gatewayAudience, scopes: $scopes, redacted: true)';
}

abstract interface class DeviceCredentialStore {
  Future<DeviceCredentialBundle?> load(String credentialId);

  Future<void> save(DeviceCredentialBundle credential);
}
