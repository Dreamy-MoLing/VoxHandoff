part of 'device_pairing_coordinator.dart';

extension _DevicePairingCoordinatorHelpers on DevicePairingCoordinator {
  Future<void> _commitCredential(
    DeviceCredentialBundle credential,
    PairingCheckpoint checkpoint,
  ) async {
    try {
      await _credentialStore.save(credential);
      await _keyVault.promotePendingKey(
        credential.keyReference,
        credential.credentialId,
      );
      await _checkpointStore.delete();
      _checkpoint = null;
      _uncommittedCredential = null;
      _publish(
        PairingState(
          phase: PairingPhase.paired,
          deviceDisplayName: checkpoint.deviceDisplayName,
          pairingId: checkpoint.pairingId,
          deviceFingerprint: checkpoint.deviceFingerprint,
          gatewayFingerprint: checkpoint.gatewayFingerprint,
          gatewayAudience: credential.gatewayAudience,
          requestedScopes: checkpoint.requestedScopes,
          approvedScopes: credential.scopes,
          deviceId: credential.deviceId,
          credentialId: credential.credentialId,
        ),
      );
    } catch (_) {
      await _markUncertain(PairingOperation.credentialCommit);
    }
  }

  Future<PairingCheckpoint> _clearCheckpointUncertainty() async {
    final checkpoint = (await _requireCheckpoint()).copyWith(
      clearUncertainOperation: true,
    );
    await _checkpointStore.save(checkpoint);
    _checkpoint = checkpoint;
    return checkpoint;
  }

  Future<PairingCheckpoint> _requireCheckpoint() async {
    final checkpoint = _checkpoint ?? await _checkpointStore.load();
    if (checkpoint == null) {
      throw StateError('The secure pairing checkpoint is missing.');
    }
    _checkpoint = checkpoint;
    return checkpoint;
  }

  Future<void> _markUncertain(PairingOperation operation) async {
    final checkpoint = _checkpoint;
    if (checkpoint != null) {
      final uncertain = checkpoint.copyWith(uncertainOperation: operation);
      try {
        await _checkpointStore.save(uncertain);
        _checkpoint = uncertain;
      } catch (_) {
        // The public state must still fail closed even if checkpoint persistence
        // itself is unavailable. No network retry is attempted here.
      }
    }
    _publish(
      checkpoint == null
          ? PairingState(
              phase: PairingPhase.uncertain,
              operation: operation,
              safeErrorCode: 'outcome_uncertain',
              safeErrorMessage:
                  'The Gateway outcome is unknown. No automatic retry was made.',
            )
          : _visibleState(
              _checkpoint ?? checkpoint,
              phase: PairingPhase.uncertain,
              operation: operation,
              safeErrorCode: 'outcome_uncertain',
              safeErrorMessage:
                  'The Gateway outcome is unknown. No automatic retry was made.',
            ),
    );
  }

  Future<void> _cleanRejectedBegin(DevicePublicIdentity? identity) async {
    if (identity != null) {
      try {
        await _keyVault.discard(identity.keyReference);
      } catch (_) {
        // Cleanup failure must not turn a deterministic rejection into a retry.
      }
    }
    try {
      await _checkpointStore.delete();
    } catch (_) {
      // The next restore will expose the checkpoint rather than submitting it.
    }
    _checkpoint = null;
  }

  _VerifiedBegin _verifyBeginResponse(
    BegunPairing response,
    DevicePublicIdentity identity,
    String expectedAudience,
    List<String> requestedScopes,
  ) {
    _requireOpaque(response.pairingId, 'pairing ID');
    if (!RegExp(
      r'^[2-9A-HJ-NP-Z]{4}-[2-9A-HJ-NP-Z]{4}$',
    ).hasMatch(response.userCode)) {
      throw const FormatException('invalid user code');
    }
    final verificationUri = _requireHttpUri(response.verificationUri);
    if (response.expiresInSeconds <= 0 || response.expiresInSeconds > 600) {
      throw const FormatException('invalid pairing expiry');
    }
    if (response.gatewayAudience != expectedAudience ||
        response.deviceFingerprint != identity.fingerprint ||
        !_fingerprintPattern.hasMatch(response.gatewayFingerprint)) {
      throw const FormatException('pairing identity mismatch');
    }
    verifyPairingProofPayload(
      payload: response.deviceProofPayload,
      pairingId: response.pairingId,
      gatewayAudience: expectedAudience,
      deviceFingerprint: identity.fingerprint,
      requestedScopes: requestedScopes,
    );
    return _VerifiedBegin(
      pairingId: response.pairingId,
      userCode: response.userCode,
      verificationUri: verificationUri,
      expiresAt: _now().add(Duration(seconds: response.expiresInSeconds)),
      gatewayFingerprint: response.gatewayFingerprint,
      gatewayAudience: response.gatewayAudience,
      deviceProofPayload: response.deviceProofPayload,
    );
  }

  _VerifiedComplete _verifyCompleteResponse(
    CompletedPairing response,
    PairingCheckpoint checkpoint,
  ) {
    if (response.legacyAccessToken.isNotEmpty ||
        response.legacyRefreshToken.isNotEmpty) {
      throw const FormatException('credentials arrived before confirmation');
    }
    _requireOpaque(response.deviceId, 'device ID');
    _requireOpaque(response.credentialId, 'credential ID');
    if (response.gatewayAudience != checkpoint.gatewayAudience ||
        response.confirmationExpiresInSeconds <= 0 ||
        response.confirmationExpiresInSeconds > 120) {
      throw const FormatException('invalid confirmation facts');
    }
    final scopes = normalizeDeviceScopes(response.approvedScopes);
    if (!_isScopeSubset(scopes, checkpoint.requestedScopes)) {
      throw const FormatException('approved scope escalation');
    }
    verifyPairingConfirmationPayload(
      payload: response.confirmationPayload,
      pairingId: checkpoint.pairingId!,
      credentialId: response.credentialId,
      deviceId: response.deviceId,
      gatewayAudience: checkpoint.gatewayAudience!,
      deviceFingerprint: checkpoint.deviceFingerprint!,
      approvedScopes: scopes,
    );
    return _VerifiedComplete(
      deviceId: response.deviceId,
      credentialId: response.credentialId,
      approvedScopes: scopes,
      confirmationPayload: response.confirmationPayload,
      confirmationExpiresAt: _now().add(
        Duration(seconds: response.confirmationExpiresInSeconds),
      ),
    );
  }

  DeviceCredentialBundle _verifyConfirmedCredential(
    ConfirmedPairing response,
    PairingCheckpoint checkpoint,
  ) {
    if (!response.paired ||
        response.deviceId != checkpoint.deviceId ||
        response.credentialId != checkpoint.credentialId ||
        response.gatewayAudience != checkpoint.gatewayAudience) {
      throw const FormatException('confirmed credential identity mismatch');
    }
    final scopes = normalizeDeviceScopes(response.approvedScopes);
    if (!_sameStrings(scopes, checkpoint.approvedScopes) ||
        !_validOpaqueSecret(response.accessToken) ||
        !_validOpaqueSecret(response.refreshToken) ||
        !response.accessExpiresAt.isAfter(_now()) ||
        !response.refreshExpiresAt.isAfter(response.accessExpiresAt)) {
      throw const FormatException('invalid confirmed credential');
    }
    return DeviceCredentialBundle(
      keyReference: checkpoint.keyReference,
      deviceId: response.deviceId,
      credentialId: response.credentialId,
      gatewayAudience: response.gatewayAudience,
      scopes: scopes,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      accessExpiresAt: response.accessExpiresAt,
      refreshExpiresAt: response.refreshExpiresAt,
    );
  }

  PairingState _visibleState(
    PairingCheckpoint checkpoint, {
    required PairingPhase phase,
    PairingOperation? operation,
    String? safeErrorCode,
    String? safeErrorMessage,
  }) => PairingState(
    phase: phase,
    operation: operation,
    deviceDisplayName: checkpoint.deviceDisplayName,
    pairingId: checkpoint.pairingId,
    userCode: checkpoint.userCode,
    verificationUri: checkpoint.verificationUri,
    deviceFingerprint: checkpoint.deviceFingerprint,
    gatewayFingerprint: checkpoint.gatewayFingerprint,
    gatewayAudience:
        checkpoint.gatewayAudience ?? checkpoint.expectedGatewayAudience,
    requestedScopes: checkpoint.requestedScopes,
    approvedScopes: checkpoint.approvedScopes,
    deviceId: checkpoint.deviceId,
    credentialId: checkpoint.credentialId,
    safeErrorCode: safeErrorCode,
    safeErrorMessage: safeErrorMessage,
  );

  void _fail(PairingOperation operation, String code, String safeMessage) {
    final checkpoint = _checkpoint;
    _publish(
      checkpoint == null
          ? PairingState(
              phase: PairingPhase.failed,
              operation: operation,
              safeErrorCode: code,
              safeErrorMessage: safeMessage,
            )
          : _visibleState(
              checkpoint,
              phase: PairingPhase.failed,
              operation: operation,
              safeErrorCode: code,
              safeErrorMessage: safeMessage,
            ),
    );
  }

  void _publish(PairingState state) {
    _state = state;
    _onStateChanged?.call(state);
  }

  bool _expired(DateTime? deadline) =>
      deadline == null || !deadline.isAfter(_now());

  static final _fingerprintPattern = RegExp(r'^sha256:[0-9a-f]{64}$');

  static String _requireDisplayName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        utf8.encode(normalized).length > 128 ||
        normalized.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
      throw const FormatException('invalid device display name');
    }
    return normalized;
  }

  static String _canonicalGatewayAudience(String value) {
    final uri = Uri.parse(value);
    final loopback = uri.host == '127.0.0.1' || uri.host == '::1';
    if (!uri.hasAuthority ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const FormatException('invalid Gateway audience');
    }
    return uri.replace(path: '').toString();
  }

  static Uri _requireHttpUri(String value) {
    final uri = Uri.parse(value);
    final loopback = uri.host == '127.0.0.1' || uri.host == '::1';
    if (!uri.hasAuthority ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('invalid verification URI');
    }
    return uri;
  }

  static String _requireOpaque(String value, String label) {
    if (value.isEmpty ||
        value.length > 256 ||
        value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
      throw FormatException('invalid $label');
    }
    return value;
  }

  static bool _isScopeSubset(List<String> values, List<String> allowed) {
    final allowedSet = allowed.toSet();
    return values.every(allowedSet.contains);
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static bool _validOpaqueSecret(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{24,512}$').hasMatch(value);
}

class _VerifiedBegin {
  _VerifiedBegin({
    required this.pairingId,
    required this.userCode,
    required this.verificationUri,
    required this.expiresAt,
    required this.gatewayFingerprint,
    required this.gatewayAudience,
    required this.deviceProofPayload,
  });

  final String pairingId;
  final String userCode;
  final Uri verificationUri;
  final DateTime expiresAt;
  final String gatewayFingerprint;
  final String gatewayAudience;
  final List<int> deviceProofPayload;
}

class _VerifiedComplete {
  _VerifiedComplete({
    required this.deviceId,
    required this.credentialId,
    required this.approvedScopes,
    required this.confirmationPayload,
    required this.confirmationExpiresAt,
  });

  final String deviceId;
  final String credentialId;
  final List<String> approvedScopes;
  final List<int> confirmationPayload;
  final DateTime confirmationExpiresAt;
}
