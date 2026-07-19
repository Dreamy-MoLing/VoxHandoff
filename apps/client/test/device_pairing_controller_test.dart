import 'package:agent_talk_client/application/device_pairing_controller.dart';
import 'package:agent_talk_client/application/device_pairing_workflow.dart';
import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePairingWorkflow implements DevicePairingWorkflow {
  FakePairingWorkflow(this.publish);

  final void Function(PairingState state) publish;
  PairingState _state = PairingState();
  var restoreCalls = 0;
  var beginCalls = 0;
  var completeCalls = 0;
  var confirmCalls = 0;
  var retryCalls = 0;
  var abandonCalls = 0;
  var acknowledgedRemoteCredential = false;
  String? deviceDisplayName;
  String? gatewayAudience;
  List<String>? scopes;

  @override
  PairingState get state => _state;

  @override
  Future<void> restore() async {
    restoreCalls += 1;
  }

  @override
  Future<void> begin({
    required String deviceDisplayName,
    required String expectedGatewayAudience,
    required Iterable<String> requestedScopes,
  }) async {
    beginCalls += 1;
    this.deviceDisplayName = deviceDisplayName;
    gatewayAudience = expectedGatewayAudience;
    scopes = List.of(requestedScopes);
    setState(
      PairingState(
        phase: PairingPhase.awaitingOwnerApproval,
        deviceDisplayName: deviceDisplayName,
        gatewayAudience: expectedGatewayAudience,
        requestedScopes: requestedScopes,
      ),
    );
  }

  @override
  Future<void> completeAfterOwnerApproval() async {
    completeCalls += 1;
    setState(
      PairingState(
        phase: PairingPhase.awaitingConfirmation,
        gatewayAudience: gatewayAudience,
        requestedScopes: scopes ?? const [],
      ),
    );
  }

  @override
  Future<void> confirm() async {
    confirmCalls += 1;
    setState(
      PairingState(
        phase: PairingPhase.paired,
        gatewayAudience: gatewayAudience,
        approvedScopes: scopes ?? const [],
        credentialId: 'credential-1',
      ),
    );
  }

  @override
  Future<void> retryUncertain() async {
    retryCalls += 1;
  }

  @override
  Future<void> abandon({
    bool acknowledgeRemoteCredentialMayExist = false,
  }) async {
    abandonCalls += 1;
    acknowledgedRemoteCredential = acknowledgeRemoteCredentialMayExist;
    setState(PairingState());
  }

  void setState(PairingState next) {
    _state = next;
    publish(next);
  }
}

class FakePairingWorkflowFactory implements DevicePairingWorkflowFactory {
  FakePairingWorkflow? workflow;
  PairingState? restoredState;
  Object? createError;
  var createCalls = 0;
  var restoreCalls = 0;
  var closeCalls = 0;
  String? gatewayAudience;
  List<int>? trustedRoots;

  @override
  Future<DevicePairingWorkflowSession> create({
    required String gatewayAudience,
    required void Function(PairingState state) onStateChanged,
    List<int>? trustedRootCertificates,
  }) async {
    createCalls += 1;
    this.gatewayAudience = gatewayAudience;
    trustedRoots = trustedRootCertificates;
    if (createError case final Object error) throw error;
    final created = FakePairingWorkflow(onStateChanged);
    workflow = created;
    return DevicePairingWorkflowSession(
      workflow: created,
      closeCallback: () => closeCalls += 1,
    );
  }

  @override
  Future<DevicePairingWorkflowSession?> restore({
    required void Function(PairingState state) onStateChanged,
  }) async {
    restoreCalls += 1;
    final restored = restoredState;
    if (restored == null) return null;
    final created = FakePairingWorkflow(onStateChanged)..setState(restored);
    workflow = created;
    return DevicePairingWorkflowSession(
      workflow: created,
      closeCallback: () => closeCalls += 1,
    );
  }
}

void main() {
  test(
    'delegates the explicit pairing phases and closes the unary channel',
    () async {
      final factory = FakePairingWorkflowFactory();
      final container = ProviderContainer(
        overrides: [pairingWorkflowFactoryProvider.overrideWithValue(factory)],
      );
      addTearDown(container.dispose);
      final controller = container.read(devicePairingProvider.notifier);

      await controller.begin(
        deviceDisplayName: 'Desk relay',
        gatewayAudience: 'https://gateway.example',
        requestedScopes: ['observe', 'send'],
        trustedRootCertificates: [1, 2],
      );
      expect(
        container.read(devicePairingProvider).phase,
        PairingPhase.awaitingOwnerApproval,
      );
      expect(factory.gatewayAudience, 'https://gateway.example');
      expect(factory.trustedRoots, [1, 2]);
      expect(factory.workflow!.beginCalls, 1);

      await controller.completeAfterOwnerApproval();
      expect(
        container.read(devicePairingProvider).phase,
        PairingPhase.awaitingConfirmation,
      );
      await controller.confirm();

      expect(container.read(devicePairingProvider).phase, PairingPhase.paired);
      expect(factory.workflow!.completeCalls, 1);
      expect(factory.workflow!.confirmCalls, 1);
      expect(factory.closeCalls, 1);
    },
  );

  test('restores a persisted uncertain workflow only once', () async {
    final factory = FakePairingWorkflowFactory()
      ..restoredState = PairingState(
        phase: PairingPhase.uncertain,
        operation: PairingOperation.confirm,
        safeErrorCode: 'outcome_uncertain',
      );
    final container = ProviderContainer(
      overrides: [pairingWorkflowFactoryProvider.overrideWithValue(factory)],
    );
    addTearDown(container.dispose);
    final controller = container.read(devicePairingProvider.notifier);

    await controller.restore();
    await controller.restore();

    expect(factory.restoreCalls, 1);
    expect(container.read(devicePairingProvider).phase, PairingPhase.uncertain);
    expect(
      container.read(devicePairingProvider).operation,
      PairingOperation.confirm,
    );
  });

  test(
    'fails closed when TLS or secure workflow setup cannot be created',
    () async {
      final factory = FakePairingWorkflowFactory()
        ..createError = StateError('secret-bearing platform diagnostics');
      final container = ProviderContainer(
        overrides: [pairingWorkflowFactoryProvider.overrideWithValue(factory)],
      );
      addTearDown(container.dispose);
      final controller = container.read(devicePairingProvider.notifier);

      await controller.begin(
        deviceDisplayName: 'Desk relay',
        gatewayAudience: 'https://gateway.example',
        requestedScopes: ['observe'],
      );

      final state = container.read(devicePairingProvider);
      expect(state.phase, PairingPhase.failed);
      expect(state.safeErrorCode, 'gateway_setup_failed');
      expect(state.safeErrorMessage, isNot(contains('secret-bearing')));
      expect(factory.closeCalls, 0);
      await controller.resetFailure();
      expect(container.read(devicePairingProvider).phase, PairingPhase.idle);
    },
  );

  test(
    'requires explicit remote-credential acknowledgement when abandoning',
    () async {
      final factory = FakePairingWorkflowFactory();
      final container = ProviderContainer(
        overrides: [pairingWorkflowFactoryProvider.overrideWithValue(factory)],
      );
      addTearDown(container.dispose);
      final controller = container.read(devicePairingProvider.notifier);
      await controller.begin(
        deviceDisplayName: 'Desk relay',
        gatewayAudience: 'https://gateway.example',
        requestedScopes: ['observe'],
      );
      factory.workflow!.setState(
        PairingState(
          phase: PairingPhase.uncertain,
          operation: PairingOperation.confirm,
        ),
      );

      await controller.abandon(acknowledgeRemoteCredentialMayExist: true);

      expect(factory.workflow!.acknowledgedRemoteCredential, isTrue);
      expect(factory.closeCalls, 1);
      expect(container.read(devicePairingProvider).phase, PairingPhase.idle);
    },
  );
}
