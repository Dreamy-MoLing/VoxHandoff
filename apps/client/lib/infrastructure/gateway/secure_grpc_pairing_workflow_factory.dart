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
  }) async => _createSession(
    gatewayAudience: gatewayAudience,
    onStateChanged: onStateChanged,
    trustedRootCertificates: trustedRootCertificates,
  );

  @override
  Future<DevicePairingWorkflowSession?> restore({
    required void Function(PairingState state) onStateChanged,
  }) async {
    final checkpointStore = SecurePairingCheckpointStore(_store);
    final checkpoint = await checkpointStore.load();
    if (checkpoint == null) return null;
    final session = _createSession(
      gatewayAudience: checkpoint.expectedGatewayAudience,
      onStateChanged: onStateChanged,
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
