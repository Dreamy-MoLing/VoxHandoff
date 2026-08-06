import 'package:agent_talk_protocol/agent_talk_protocol.dart';

import '../../application/device_pairing_coordinator.dart';
import '../../application/device_pairing_workflow.dart';
import '../../domain/device_pairing.dart';
import '../security/device_key_vault.dart';
import '../security/flutter_secure_value_store.dart';
import '../security/secure_pairing_stores.dart';
import 'gateway_grpc_channel_factory.dart';
import 'grpc_pairing_gateway.dart';

class SecureGrpcPairingWorkflowFactory implements DevicePairingWorkflowFactory {
  SecureGrpcPairingWorkflowFactory({
    SecureValueStore? secureValueStore,
    GatewayGrpcChannelFactory? channelFactory,
  }) : _store = secureValueStore ?? FlutterSecureValueStore(),
       _channelFactory = channelFactory ?? GatewayGrpcChannelFactory();

  final SecureValueStore _store;
  final GatewayGrpcChannelFactory _channelFactory;

  @override
  Future<DevicePairingWorkflowSession> create({
    required String gatewayAudience,
    required void Function(PairingState state) onStateChanged,
    List<int>? trustedRootCertificates,
  }) async {
    await SecureGatewayConnectionProfileStore(_store).save(
      GatewayConnectionProfile(
        gatewayAudience: gatewayAudience,
        trustedRootCertificates: trustedRootCertificates,
      ),
    );
    return _createSession(
      gatewayAudience: gatewayAudience,
      onStateChanged: onStateChanged,
      trustedRootCertificates: trustedRootCertificates,
    );
  }

  @override
  Future<DevicePairingWorkflowSession?> restore({
    required void Function(PairingState state) onStateChanged,
  }) async {
    final checkpointStore = SecurePairingCheckpointStore(_store);
    final checkpoint = await checkpointStore.load();
    final profile = await SecureGatewayConnectionProfileStore(_store).load();
    if (checkpoint == null) {
      final credential = await SecureDeviceCredentialStore(_store).loadActive();
      if (credential == null && profile == null) return null;
      if (credential == null ||
          profile == null ||
          credential.gatewayAudience != profile.gatewayAudience) {
        throw const SecurePairingStoreException(
          'active_pairing_incomplete',
          'The active Gateway pairing record is incomplete.',
        );
      }
      final workflow = _RestoredActiveCredentialWorkflow(
        credential,
        onStateChanged,
      );
      await workflow.restore();
      return DevicePairingWorkflowSession(
        workflow: workflow,
        closeCallback: () {},
      );
    }
    if (profile == null ||
        profile.gatewayAudience != checkpoint.expectedGatewayAudience) {
      throw const SecurePairingStoreException(
        'gateway_profile_missing',
        'The saved pairing has no matching Gateway connection profile.',
      );
    }
    final session = _createSession(
      gatewayAudience: checkpoint.expectedGatewayAudience,
      onStateChanged: onStateChanged,
      trustedRootCertificates: profile.trustedRootCertificates,
    );
    try {
      await session.workflow.restore();
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  DevicePairingWorkflowSession _createSession({
    required String gatewayAudience,
    required void Function(PairingState state) onStateChanged,
    List<int>? trustedRootCertificates,
  }) {
    final channel = _channelFactory.create(
      gatewayAudience: gatewayAudience,
      trustedRootCertificates: trustedRootCertificates,
    );
    final gateway = GrpcPairingGateway(
      GeneratedPairingUnaryRpc(PairingServiceClient(channel)),
    );
    final workflow = DevicePairingCoordinator(
      keyVault: DeviceKeyVault(store: _store),
      checkpointStore: SecurePairingCheckpointStore(_store),
      credentialStore: SecureDeviceCredentialStore(_store),
      gateway: gateway,
      onStateChanged: onStateChanged,
    );
    return DevicePairingWorkflowSession(
      workflow: workflow,
      closeCallback: channel.shutdown,
    );
  }
}

class _RestoredActiveCredentialWorkflow implements DevicePairingWorkflow {
  _RestoredActiveCredentialWorkflow(this._credential, this._onStateChanged);

  final DeviceCredentialBundle _credential;
  final void Function(PairingState state) _onStateChanged;
  PairingState _state = PairingState();

  @override
  PairingState get state => _state;

  @override
  Future<void> restore() async {
    _state = PairingState(
      phase: PairingPhase.paired,
      deviceDisplayName: 'This device',
      gatewayAudience: _credential.gatewayAudience,
      requestedScopes: _credential.scopes,
      approvedScopes: _credential.scopes,
      deviceId: _credential.deviceId,
      credentialId: _credential.credentialId,
    );
    _onStateChanged(_state);
  }

  Never _active() =>
      throw StateError('An active credential cannot restart pairing.');

  @override
  Future<void> abandon({
    bool acknowledgeRemoteCredentialMayExist = false,
  }) async => _active();

  @override
  Future<void> begin({
    required String deviceDisplayName,
    required String expectedGatewayAudience,
    required Iterable<String> requestedScopes,
  }) async => _active();

  @override
  Future<void> completeAfterOwnerApproval() async => _active();

  @override
  Future<void> confirm() async => _active();

  @override
  Future<void> retryUncertain() async => _active();
}
