import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/device_pairing.dart';
import '../infrastructure/gateway/secure_grpc_pairing_workflow_factory.dart';
import 'device_pairing_workflow.dart';

final pairingWorkflowFactoryProvider = Provider<DevicePairingWorkflowFactory>(
  (ref) => SecureGrpcPairingWorkflowFactory(),
);

final devicePairingProvider =
    NotifierProvider<DevicePairingController, PairingState>(
      DevicePairingController.new,
    );

class DevicePairingController extends Notifier<PairingState> {
  DevicePairingWorkflowFactory? _factory;
  DevicePairingWorkflowSession? _session;
  bool _restoreAttempted = false;

  @override
  PairingState build() {
    _factory = ref.watch(pairingWorkflowFactoryProvider);
    ref.onDispose(() {
      final session = _session;
      _session = null;
      if (session != null) unawaited(session.close());
    });
    return PairingState();
  }

  Future<void> restore() async {
    if (_restoreAttempted || _session != null) return;
    _restoreAttempted = true;
    try {
      _session = await _factory!.restore(onStateChanged: _publish);
    } catch (_) {
      state = PairingState(
        phase: PairingPhase.failed,
        operation: PairingOperation.localValidation,
        safeErrorCode: 'pairing_restore_failed',
        safeErrorMessage:
            'The saved pairing could not be opened safely on this device.',
      );
    }
  }

  Future<void> begin({
    required String deviceDisplayName,
    required String gatewayAudience,
    required Iterable<String> requestedScopes,
    List<int>? trustedRootCertificates,
  }) async {
    if (_session != null || state.phase != PairingPhase.idle) {
      throw StateError('A pairing workflow is already active.');
    }
    try {
      final session = await _factory!.create(
        gatewayAudience: gatewayAudience,
        onStateChanged: _publish,
        trustedRootCertificates: trustedRootCertificates,
      );
      _session = session;
      await session.workflow.begin(
        deviceDisplayName: deviceDisplayName,
        expectedGatewayAudience: gatewayAudience,
        requestedScopes: requestedScopes,
      );
    } catch (_) {
      if (state.phase == PairingPhase.idle) {
        await _closeSession();
        state = PairingState(
          phase: PairingPhase.failed,
          operation: PairingOperation.localValidation,
          safeErrorCode: 'gateway_setup_failed',
          safeErrorMessage:
              'Check the HTTPS Gateway address and imported CA certificate.',
        );
      }
    }
  }

  Future<void> completeAfterOwnerApproval() async {
    await _requiredWorkflow().completeAfterOwnerApproval();
  }

  Future<void> confirm() async {
    await _requiredWorkflow().confirm();
    await _closeIfFinished();
  }

  Future<void> retryUncertain() async {
    await _requiredWorkflow().retryUncertain();
    await _closeIfFinished();
  }

  Future<void> abandon({
    bool acknowledgeRemoteCredentialMayExist = false,
  }) async {
    await _requiredWorkflow().abandon(
      acknowledgeRemoteCredentialMayExist: acknowledgeRemoteCredentialMayExist,
    );
    await _closeSession();
  }

  Future<void> resetFailure() async {
    if (state.phase != PairingPhase.failed) {
      throw StateError('Only a failed pairing workflow can be reset.');
    }
    final workflow = _session?.workflow;
    if (workflow == null) {
      state = PairingState();
      return;
    }
    await workflow.abandon();
    await _closeSession();
  }

  DevicePairingWorkflow _requiredWorkflow() {
    final workflow = _session?.workflow;
    if (workflow == null) {
      throw StateError('There is no active pairing workflow.');
    }
    return workflow;
  }

  void _publish(PairingState next) {
    state = next;
  }

  Future<void> _closeIfFinished() async {
    if (state.phase == PairingPhase.paired) await _closeSession();
  }

  Future<void> _closeSession() async {
    final session = _session;
    _session = null;
    if (session != null) await session.close();
  }
}
