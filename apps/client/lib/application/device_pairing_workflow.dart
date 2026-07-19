import 'dart:async';

import '../domain/device_pairing.dart';

abstract interface class DevicePairingWorkflow {
  PairingState get state;

  Future<void> restore();

  Future<void> begin({
    required String deviceDisplayName,
    required String expectedGatewayAudience,
    required Iterable<String> requestedScopes,
  });

  Future<void> completeAfterOwnerApproval();

  Future<void> confirm();

  Future<void> retryUncertain();

  Future<void> abandon({bool acknowledgeRemoteCredentialMayExist = false});
}

abstract interface class DevicePairingWorkflowFactory {
  Future<DevicePairingWorkflowSession> create({
    required String gatewayAudience,
    required void Function(PairingState state) onStateChanged,
    List<int>? trustedRootCertificates,
  });

  Future<DevicePairingWorkflowSession?> restore({
    required void Function(PairingState state) onStateChanged,
  });
}

class DevicePairingWorkflowSession {
  DevicePairingWorkflowSession({
    required this.workflow,
    required this.closeCallback,
  });

  final DevicePairingWorkflow workflow;
  final FutureOr<void> Function() closeCallback;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await closeCallback();
  }
}
