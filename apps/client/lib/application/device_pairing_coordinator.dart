import 'dart:convert';

import 'package:agent_talk_protocol/agent_talk_protocol.dart';

import '../domain/device_pairing.dart';

class DevicePairingCoordinator {
  factory DevicePairingCoordinator({
    required DeviceKeyVaultPort keyVault,
    required PairingCheckpointStore checkpointStore,
    required DeviceCredentialStore credentialStore,
    required PairingGatewayPort gateway,
    DateTime Function()? now,
    void Function(PairingState state)? onStateChanged,
  }) => DevicePairingCoordinator._(
    keyVault,
    checkpointStore,
    credentialStore,
    gateway,
    now ?? DateTime.now,
    onStateChanged,
  );

  DevicePairingCoordinator._(
    this._keyVault,
    this._checkpointStore,
    this._credentialStore,
    this._gateway,
    this._now,
    this._onStateChanged,
  );

  final DeviceKeyVaultPort _keyVault;
  final PairingCheckpointStore _checkpointStore;
  final DeviceCredentialStore _credentialStore;
  final PairingGatewayPort _gateway;
  final DateTime Function() _now;
  final void Function(PairingState state)? _onStateChanged;

  PairingState _state = PairingState();
  PairingCheckpoint? _checkpoint;
  DeviceCredentialBundle? _uncommittedCredential;
  PairingOperation? _explicitRecovery;

  PairingState get state => _state;

  Future<void> restore() async {
    if (_state.phase != PairingPhase.idle) {
      throw StateError('Pairing state can only be restored from idle.');
    }
    final checkpoint = await _checkpointStore.load();
    if (checkpoint == null) {
      return;
    }
    _checkpoint = checkpoint;
    if (checkpoint.uncertainOperation != null) {
      _publish(
        _visibleState(
          checkpoint,
          phase: PairingPhase.uncertain,
          operation: checkpoint.uncertainOperation,
          safeErrorCode: 'outcome_uncertain',
          safeErrorMessage:
              'The previous pairing operation may have reached the Gateway. '
              'Review it before choosing recovery.',
        ),
      );
      return;
    }
    final phase = switch (checkpoint.phase) {
      PairingCheckpointPhase.beginPrepared => PairingPhase.uncertain,
      PairingCheckpointPhase.begun || PairingCheckpointPhase.proofPrepared =>
        PairingPhase.awaitingOwnerApproval,
      PairingCheckpointPhase.completed ||
      PairingCheckpointPhase.confirmationPrepared =>
        PairingPhase.awaitingConfirmation,
    };
    _publish(
      _visibleState(
        checkpoint,
        phase: phase,
        operation: checkpoint.phase == PairingCheckpointPhase.beginPrepared
            ? PairingOperation.begin
            : null,
        safeErrorCode: checkpoint.phase == PairingCheckpointPhase.beginPrepared
            ? 'outcome_uncertain'
            : null,
        safeErrorMessage:
            checkpoint.phase == PairingCheckpointPhase.beginPrepared
            ? 'A prepared Begin request has no confirmed Gateway result.'
            : null,
      ),
    );
  }

  Future<void> begin({
    required String deviceDisplayName,
    required String expectedGatewayAudience,
    required Iterable<String> requestedScopes,
  }) async {
    if (_state.phase != PairingPhase.idle) {
      throw StateError('A pairing attempt is already present.');
    }

    late final String displayName;
    late final String audience;
    late final List<String> scopes;
    try {
      displayName = _requireDisplayName(deviceDisplayName);
      audience = _canonicalGatewayAudience(expectedGatewayAudience);
      scopes = normalizeDeviceScopes(requestedScopes);
    } catch (_) {
      _fail(
        PairingOperation.localValidation,
        'invalid_pairing_input',
        'Check the device name, Gateway HTTPS origin, and requested scopes.',
      );
      return;
    }

    _publish(
      PairingState(
        phase: PairingPhase.beginning,
        operation: PairingOperation.begin,
        deviceDisplayName: displayName,
        gatewayAudience: audience,
        requestedScopes: scopes,
      ),
    );

    DevicePublicIdentity? identity;
    var gatewayCallStarted = false;
    try {
      identity = await _keyVault.createPendingKey();
      var checkpoint = PairingCheckpoint(
        phase: PairingCheckpointPhase.beginPrepared,
        keyReference: identity.keyReference,
        deviceDisplayName: displayName,
        expectedGatewayAudience: audience,
        requestedScopes: scopes,
        deviceFingerprint: identity.fingerprint,
      );
      await _checkpointStore.save(checkpoint);
      _checkpoint = checkpoint;

      gatewayCallStarted = true;
      final response = await _gateway.begin(
        BeginPairingCommand(
          deviceDisplayName: displayName,
          devicePublicKeySpkiDer: identity.publicKeySpkiDer,
          requestedScopes: scopes,
          expectedGatewayAudience: audience,
        ),
      );
      final verified = _verifyBeginResponse(
        response,
        identity,
        audience,
        scopes,
      );
      checkpoint = checkpoint.copyWith(
        phase: PairingCheckpointPhase.begun,
        pairingId: verified.pairingId,
        userCode: verified.userCode,
        verificationUri: verified.verificationUri,
        expiresAt: verified.expiresAt,
        gatewayFingerprint: verified.gatewayFingerprint,
        gatewayAudience: verified.gatewayAudience,
        deviceProofPayload: verified.deviceProofPayload,
        clearUncertainOperation: true,
      );
      await _checkpointStore.save(checkpoint);
      _checkpoint = checkpoint;
      _publish(
        _visibleState(checkpoint, phase: PairingPhase.awaitingOwnerApproval),
      );
    } on PairingGatewayCallException catch (error) {
      if (error.disposition == PairingGatewayDisposition.uncertain) {
        await _markUncertain(PairingOperation.begin);
      } else {
        await _cleanRejectedBegin(identity);
        _fail(PairingOperation.begin, error.code, error.safeMessage);
      }
    } catch (_) {
      if (gatewayCallStarted) {
        await _markUncertain(PairingOperation.begin);
      } else {
        await _cleanRejectedBegin(identity);
        _fail(
          PairingOperation.begin,
          'local_pairing_setup_failed',
          'The pending device key or secure checkpoint could not be prepared.',
        );
      }
    }
  }

  Future<void> completeAfterOwnerApproval() async {
    if (!_state.canComplete) {
      throw StateError('Pairing is not awaiting owner approval.');
    }
    var checkpoint = await _requireCheckpoint();
    if (checkpoint.pairingId == null ||
        checkpoint.deviceProofPayload == null ||
        checkpoint.deviceFingerprint == null ||
        checkpoint.gatewayAudience == null) {
      _fail(
        PairingOperation.complete,
        'invalid_checkpoint',
        'The secure pairing checkpoint is incomplete.',
      );
      return;
    }
    if (_expired(checkpoint.expiresAt)) {
      _fail(
        PairingOperation.complete,
        'pairing_expired',
        'The pairing code expired. Abandon it and begin again.',
      );
      return;
    }

    var gatewayCallStarted = false;
    try {
      verifyPairingProofPayload(
        payload: checkpoint.deviceProofPayload!,
        pairingId: checkpoint.pairingId!,
        gatewayAudience: checkpoint.gatewayAudience!,
        deviceFingerprint: checkpoint.deviceFingerprint!,
        requestedScopes: checkpoint.requestedScopes,
      );
      final signature =
          checkpoint.proofSignature ??
          await _keyVault.sign(
            checkpoint.keyReference,
            checkpoint.deviceProofPayload!,
          );
      checkpoint = checkpoint.copyWith(
        phase: PairingCheckpointPhase.proofPrepared,
        proofSignature: signature,
        clearUncertainOperation: true,
      );
      await _checkpointStore.save(checkpoint);
      _checkpoint = checkpoint;
      _publish(
        _visibleState(
          checkpoint,
          phase: PairingPhase.completing,
          operation: PairingOperation.complete,
        ),
      );

      gatewayCallStarted = true;
      final response = await _gateway.complete(
        checkpoint.pairingId!,
        DeviceSignatureProof(signature: signature),
      );
      final verified = _verifyCompleteResponse(response, checkpoint);
      checkpoint = checkpoint.copyWith(
        phase: PairingCheckpointPhase.completed,
        deviceId: verified.deviceId,
        credentialId: verified.credentialId,
        approvedScopes: verified.approvedScopes,
        confirmationPayload: verified.confirmationPayload,
        confirmationExpiresAt: verified.confirmationExpiresAt,
        clearUncertainOperation: true,
      );
      await _checkpointStore.save(checkpoint);
      _checkpoint = checkpoint;
      _publish(
        _visibleState(checkpoint, phase: PairingPhase.awaitingConfirmation),
      );
    } on PairingGatewayCallException catch (error) {
      if (error.disposition == PairingGatewayDisposition.uncertain) {
        await _markUncertain(PairingOperation.complete);
      } else if (error.code == 'pairing_not_approved') {
        _publish(
          _visibleState(
            checkpoint,
            phase: PairingPhase.awaitingOwnerApproval,
            safeErrorCode: error.code,
            safeErrorMessage: error.safeMessage,
          ),
        );
      } else if (_explicitRecovery == PairingOperation.complete) {
        await _markUncertain(PairingOperation.complete);
      } else {
        _fail(PairingOperation.complete, error.code, error.safeMessage);
      }
    } catch (_) {
      if (gatewayCallStarted) {
        await _markUncertain(PairingOperation.complete);
      } else {
        _fail(
          PairingOperation.complete,
          'local_proof_failed',
          'The pairing proof could not be verified or signed locally.',
        );
      }
    }
  }

  Future<void> confirm() async {
    if (!_state.canConfirm) {
      throw StateError('Pairing is not awaiting device confirmation.');
    }
    var checkpoint = await _requireCheckpoint();
    if (checkpoint.pairingId == null ||
        checkpoint.credentialId == null ||
        checkpoint.deviceId == null ||
        checkpoint.confirmationPayload == null ||
        checkpoint.deviceFingerprint == null ||
        checkpoint.gatewayAudience == null ||
        checkpoint.approvedScopes.isEmpty) {
      _fail(
        PairingOperation.confirm,
        'invalid_checkpoint',
        'The secure pairing confirmation checkpoint is incomplete.',
      );
      return;
    }
    if (_expired(checkpoint.confirmationExpiresAt)) {
      _fail(
        PairingOperation.confirm,
        'confirmation_expired',
        'The pairing confirmation expired. Abandon it and begin again.',
      );
      return;
    }

    var gatewayCallStarted = false;
    try {
      verifyPairingConfirmationPayload(
        payload: checkpoint.confirmationPayload!,
        pairingId: checkpoint.pairingId!,
        credentialId: checkpoint.credentialId!,
        deviceId: checkpoint.deviceId!,
        gatewayAudience: checkpoint.gatewayAudience!,
        deviceFingerprint: checkpoint.deviceFingerprint!,
        approvedScopes: checkpoint.approvedScopes,
      );
      final signature =
          checkpoint.confirmationSignature ??
          await _keyVault.sign(
            checkpoint.keyReference,
            checkpoint.confirmationPayload!,
          );
      checkpoint = checkpoint.copyWith(
        phase: PairingCheckpointPhase.confirmationPrepared,
        confirmationSignature: signature,
        clearUncertainOperation: true,
      );
      await _checkpointStore.save(checkpoint);
      _checkpoint = checkpoint;
      _publish(
        _visibleState(
          checkpoint,
          phase: PairingPhase.confirming,
          operation: PairingOperation.confirm,
        ),
      );

      gatewayCallStarted = true;
      final response = await _gateway.confirm(
        checkpoint.pairingId!,
        checkpoint.credentialId!,
        DeviceSignatureProof(
          credentialId: checkpoint.credentialId!,
          signature: signature,
        ),
      );
      final credential = _verifyConfirmedCredential(response, checkpoint);
      _uncommittedCredential = credential;
      await _commitCredential(credential, checkpoint);
    } on PairingGatewayCallException catch (error) {
      if (error.disposition == PairingGatewayDisposition.uncertain) {
        await _markUncertain(PairingOperation.confirm);
      } else if (_explicitRecovery == PairingOperation.confirm) {
        await _markUncertain(PairingOperation.confirm);
      } else {
        _fail(PairingOperation.confirm, error.code, error.safeMessage);
      }
    } catch (_) {
      if (gatewayCallStarted) {
        await _markUncertain(PairingOperation.confirm);
      } else {
        _fail(
          PairingOperation.confirm,
          'local_confirmation_failed',
          'The pairing confirmation could not be verified or signed locally.',
        );
      }
    }
  }

  Future<void> retryUncertain() async {
    if (!_state.requiresExplicitRecovery || _state.operation == null) {
      throw StateError('There is no uncertain pairing operation to recover.');
    }
    final operation = _state.operation!;
    _explicitRecovery = operation;
    try {
      switch (operation) {
        case PairingOperation.begin:
          throw StateError(
            'An uncertain Begin request has no safe retry identity. Abandon it '
            'explicitly before starting again.',
          );
        case PairingOperation.complete:
          final checkpoint = await _clearCheckpointUncertainty();
          _publish(
            _visibleState(
              checkpoint,
              phase: PairingPhase.awaitingOwnerApproval,
            ),
          );
          await completeAfterOwnerApproval();
          return;
        case PairingOperation.confirm:
          final checkpoint = await _clearCheckpointUncertainty();
          _publish(
            _visibleState(checkpoint, phase: PairingPhase.awaitingConfirmation),
          );
          await confirm();
          return;
        case PairingOperation.credentialCommit:
          final checkpoint = await _requireCheckpoint();
          final credential =
              _uncommittedCredential ??
              await _credentialStore.load(checkpoint.credentialId ?? '');
          if (credential == null) {
            throw StateError(
              'The confirmed credential is unavailable locally. Do not retry '
              'Confirm automatically; revoke it from an owner device.',
            );
          }
          await _commitCredential(credential, checkpoint);
          return;
        case PairingOperation.localValidation:
          throw StateError('Local validation never has a recoverable outcome.');
      }
    } finally {
      _explicitRecovery = null;
    }
  }

  Future<void> abandon({
    bool acknowledgeRemoteCredentialMayExist = false,
  }) async {
    if (_state.phase == PairingPhase.paired) {
      throw StateError('An active device must be revoked, not abandoned.');
    }
    if (_state.phase == PairingPhase.uncertain &&
        _state.operation == PairingOperation.credentialCommit) {
      throw StateError(
        'Confirm succeeded, so this credential must be committed or revoked; '
        'it cannot be abandoned as a pending pairing.',
      );
    }
    if (_state.phase == PairingPhase.uncertain &&
        _state.operation == PairingOperation.confirm &&
        !acknowledgeRemoteCredentialMayExist) {
      throw StateError(
        'The Gateway may already hold an active credential. Explicit '
        'acknowledgement is required before local key removal.',
      );
    }
    final checkpoint = _checkpoint ?? await _checkpointStore.load();
    if (checkpoint != null) {
      await _keyVault.discard(checkpoint.keyReference);
    }
    await _checkpointStore.delete();
    _checkpoint = null;
    _uncommittedCredential = null;
    _publish(PairingState());
  }

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
