import '../../application/gateway_frame_router.dart';
import 'gateway_frame_mapper.dart';
import 'grpc_gateway_command_port.dart';
import 'grpc_gateway_live_transport.dart';

/// Binds the raw gRPC stream to the one central application frame router.
class GatewaySyncSession {
  const GatewaySyncSession(this._router, this._mapper);

  final GatewayFrameRouter _router;
  final GatewayFrameMapper _mapper;

  Future<void> run(GatewayLiveEventConnection connection) => _router.run(
    connection.frames.asyncMap(_mapper.map),
    GrpcGatewayCommandPort(connection),
  );
}
