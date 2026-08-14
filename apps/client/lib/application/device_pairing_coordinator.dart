import 'dart:convert';

import 'package:agent_talk_protocol/agent_talk_protocol.dart';

import '../domain/device_pairing.dart';
import 'device_pairing_workflow.dart';

part 'device_pairing_coordinator_helpers.dart';

class DevicePairingCoordinator implements DevicePairingWorkflow {
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

  @override
  PairingState get state => _state;

  @override
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

  @override
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
      displayName = _DevicePairingCoordinatorHelpers._requireDisplayName(
        deviceDisplayName,
      );
      audience = _DevicePairingCoordinatorHelpers._canonicalGatewayAudience(
        expectedGatewayAudience,
      );
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

  @override
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

  @override
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

  @override
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
        case PairingOperation.refresh:
          throw StateError(
            'Credential refresh is not a pairing recovery step.',
          );
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

  @override
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
}
