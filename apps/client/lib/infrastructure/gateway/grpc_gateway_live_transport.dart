import 'dart:async';

import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart';

import '../../domain/device_pairing.dart';

abstract interface class GatewayControlStreamingRpc {
  Stream<ConnectClientResponse> connectClient(
    Stream<ConnectClientRequest> requests, {
    CallOptions? options,
  });
}

class GeneratedGatewayControlStreamingRpc
    implements GatewayControlStreamingRpc {
  GeneratedGatewayControlStreamingRpc(this._client);

  final GatewayControlServiceClient _client;

  @override
  Stream<ConnectClientResponse> connectClient(
    Stream<ConnectClientRequest> requests, {
    CallOptions? options,
  }) => _client.connectClient(requests, options: options);
}

class GrpcGatewayLiveTransport {
  GrpcGatewayLiveTransport(
    this._rpc, {
    this.handshakeTimeout = const Duration(seconds: 10),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    if (handshakeTimeout <= Duration.zero ||
        handshakeTimeout > const Duration(seconds: 30)) {
      throw const FormatException(
        'The Gateway handshake timeout is outside its supported bound.',
      );
    }
  }

  static const schemaBuild = 'agent-talk-proto-v1.1';
  static const schemaSha256 =
      'd9953c98a2c699d12f9e17c8d0fae57761daf17db8192534087077ab380d914a';
  static const componentVersion = '0.1.0';
  static const capabilityRevision = 'client-m2-live-v1';

  final GatewayControlStreamingRpc _rpc;
  final Duration handshakeTimeout;
  final DateTime Function() _now;

  Future<GatewayLiveConnection> open(DeviceCredentialBundle credential) async {
    _validateCredential(credential, _now().toUtc());
    final requests = StreamController<ConnectClientRequest>(sync: true);
    final frames = StreamController<GatewayLiveFrame>();
    final accepted = Completer<HandshakeAccepted>();
    var handshaken = false;
    var closed = false;

    late final StreamSubscription<ConnectClientResponse> subscription;
    void fail(GatewayLiveTransportException error) {
      if (closed) return;
      closed = true;
      if (!accepted.isCompleted) {
        accepted.completeError(error);
      } else {
        frames.addError(error);
      }
      unawaited(frames.close());
      unawaited(requests.close());
    }

    late final Stream<ConnectClientResponse> responses;
    try {
      responses = _rpc.connectClient(
        requests.stream,
        options: CallOptions(
          metadata: {'authorization': 'Bearer ${credential.accessToken}'},
        ),
      );
    } on Object {
      closed = true;
      unawaited(requests.close());
      unawaited(frames.close());
      throw const GatewayLiveTransportException(
        code: 'stream_unavailable',
        safeMessage: 'The authenticated Gateway stream could not be opened.',
        outcomeUncertain: true,
      );
    }
    subscription = responses.listen(
      (response) {
        if (!handshaken) {
          if (response.whichBody() != ConnectClientResponse_Body.handshake) {
            fail(
              const GatewayLiveTransportException(
                code: 'handshake_missing',
                safeMessage:
                    'The Gateway sent data before accepting the protocol handshake.',
              ),
            );
            return;
          }
          try {
            _validateHandshake(response.handshake, credential.scopes);
          } on GatewayLiveTransportException catch (error) {
            fail(error);
            return;
          }
          handshaken = true;
          accepted.complete(response.handshake.deepCopy());
          return;
        }
        try {
          final frame = _mapFrame(response);
          if (!closed) frames.add(frame);
        } on GatewayLiveTransportException catch (error) {
          fail(error);
        }
      },
      onError: (Object _) {
        fail(
          const GatewayLiveTransportException(
            code: 'stream_unavailable',
            safeMessage: 'The authenticated Gateway stream ended unexpectedly.',
            outcomeUncertain: true,
          ),
        );
      },
      onDone: () {
        if (!handshaken) {
          fail(
            const GatewayLiveTransportException(
              code: 'handshake_incomplete',
              safeMessage:
                  'The Gateway stream closed before the handshake completed.',
            ),
          );
        } else if (!closed) {
          closed = true;
          unawaited(frames.close());
          unawaited(requests.close());
        }
      },
    );

    requests.add(ConnectClientRequest(handshake: _offer(credential.scopes)));
    try {
      final handshake = await accepted.future.timeout(
        handshakeTimeout,
        onTimeout: () => throw const GatewayLiveTransportException(
          code: 'handshake_timeout',
          safeMessage: 'The Gateway did not complete the protocol handshake.',
          outcomeUncertain: true,
        ),
      );
      return GatewayLiveConnection._(
        handshake: handshake,
        frames: frames,
        requests: requests,
        subscription: subscription,
      );
    } on Object {
      closed = true;
      await subscription.cancel();
      if (!requests.isClosed) await requests.close();
      if (!frames.isClosed) unawaited(frames.close());
      rethrow;
    }
  }

  HandshakeOffer _offer(Iterable<String> scopes) => HandshakeOffer(
    currentProtocol: ProtocolVersion(major: 1, minor: 1),
    acceptedProtocols: ProtocolVersionRange(
      major: 1,
      minimumMinor: 0,
      maximumMinor: 1,
    ),
    schemaBuild: schemaBuild,
    schemaSha256: schemaSha256,
    componentVersion: componentVersion,
    componentRole: ComponentRole.COMPONENT_ROLE_CLIENT,
    capabilityRevision: capabilityRevision,
    capabilities: AgentCapabilities(
      deltaMode: DeltaMode.DELTA_MODE_REVISABLE,
      eventStream: true,
      sessionHistory: true,
      idempotency: true,
      replay: true,
      sequenceRecovery: true,
      attachments: false,
    ),
    scopes: scopes,
  );

  void _validateCredential(DeviceCredentialBundle credential, DateTime now) {
    if (!_opaque(credential.deviceId) ||
        !_opaque(credential.credentialId) ||
        !_secret(credential.accessToken) ||
        !_secret(credential.refreshToken) ||
        credential.accessExpiresAt.toUtc().isBefore(now) ||
        credential.accessExpiresAt.toUtc().isAtSameMomentAs(now) ||
        credential.refreshExpiresAt.toUtc().isBefore(now) ||
        credential.refreshExpiresAt.toUtc().isAtSameMomentAs(now) ||
        credential.generation <= 0 ||
        credential.scopes.isEmpty ||
        credential.scopes.toSet().length != credential.scopes.length) {
      throw const GatewayLiveTransportException(
        code: 'credential_invalid',
        safeMessage: 'The active device credential is invalid or expired.',
      );
    }
  }

  void _validateHandshake(
    HandshakeAccepted handshake,
    List<String> expectedScopes,
  ) {
    final selected = handshake.selectedProtocol;
    if (!handshake.hasSelectedProtocol() ||
        selected.major != 1 ||
        selected.minor < 0 ||
        selected.minor > 1 ||
        handshake.componentRole != ComponentRole.COMPONENT_ROLE_GATEWAY ||
        !_opaque(handshake.connectionId) ||
        !_metadata(handshake.schemaBuild) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(handshake.schemaSha256) ||
        !_metadata(handshake.componentVersion) ||
        !_metadata(handshake.capabilityRevision) ||
        !handshake.hasCapabilities() ||
        !handshake.capabilities.eventStream ||
        !handshake.capabilities.replay ||
        !handshake.capabilities.sequenceRecovery ||
        handshake.capabilities.attachments ||
        !_sameStrings(handshake.scopes, expectedScopes)) {
      throw const GatewayLiveTransportException(
        code: 'handshake_invalid',
        safeMessage: 'The Gateway handshake identity is invalid.',
      );
    }
  }

  GatewayLiveFrame _mapFrame(ConnectClientResponse response) =>
      switch (response.whichBody()) {
        ConnectClientResponse_Body.heartbeat => GatewayHeartbeatFrame(
          response.heartbeat.deepCopy(),
        ),
        ConnectClientResponse_Body.event => GatewayEventFrame(
          response.event.deepCopy(),
        ),
        ConnectClientResponse_Body.requestStatus => GatewayRequestStatusFrame(
          response.requestStatus.deepCopy(),
        ),
        ConnectClientResponse_Body.controlLease => GatewayControlLeaseFrame(
          response.controlLease.deepCopy(),
        ),
        ConnectClientResponse_Body.replayCompleted =>
          GatewayReplayCompletedFrame(response.replayCompleted.deepCopy()),
        ConnectClientResponse_Body.directory => GatewayDirectoryFrame(
          response.directory.deepCopy(),
        ),
        ConnectClientResponse_Body.conversation => GatewayConversationFrame(
          response.conversation.deepCopy(),
        ),
        ConnectClientResponse_Body.protocolError =>
          throw const GatewayLiveTransportException(
            code: 'remote_protocol_error',
            safeMessage: 'The Gateway rejected the live protocol stream.',
          ),
        ConnectClientResponse_Body.handshake =>
          throw const GatewayLiveTransportException(
            code: 'handshake_repeated',
            safeMessage: 'The Gateway repeated an established handshake.',
          ),
        ConnectClientResponse_Body.notSet =>
          throw const GatewayLiveTransportException(
            code: 'frame_missing',
            safeMessage: 'The Gateway sent an empty live frame.',
          ),
      };

  bool _opaque(String value) =>
      value.isNotEmpty &&
      value.length <= 256 &&
      !value.contains(RegExp(r'[\u0000-\u001f\u007f]'));

  bool _metadata(String value) =>
      value.isNotEmpty &&
      value.length <= 256 &&
      !value.contains(RegExp(r'[\u0000-\u001f\u007f]'));

  bool _secret(String value) =>
      RegExp(r'^[A-Za-z0-9_-]{24,512}$').hasMatch(value);

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

abstract interface class GatewayLiveEventConnection {
  Stream<GatewayLiveFrame> get frames;

  void sendCommand(ClientCommand command);

  void acknowledge(Ack acknowledgement);

  Future<void> close();
}

class GatewayLiveConnection implements GatewayLiveEventConnection {
  GatewayLiveConnection._({
    required this.handshake,
    required this._frames,
    required this._requests,
    required this._subscription,
  });

  final HandshakeAccepted handshake;
  final StreamController<GatewayLiveFrame> _frames;
  final StreamController<ConnectClientRequest> _requests;
  final StreamSubscription<ConnectClientResponse> _subscription;
  bool _closed = false;

  @override
  Stream<GatewayLiveFrame> get frames => _frames.stream;

  @override
  void sendCommand(ClientCommand command) {
    if (command.whichCommand() == ClientCommand_Command.notSet) {
      throw const FormatException('The Client command body is missing.');
    }
    _send(ConnectClientRequest(command: command.deepCopy()));
  }

  @override
  void acknowledge(Ack acknowledgement) {
    if (acknowledgement.conversationId.isEmpty ||
        acknowledgement.eventId.isEmpty ||
        acknowledgement.sequence <= Int64.ZERO) {
      throw const FormatException('The event acknowledgement is incomplete.');
    }
    _send(ConnectClientRequest(ack: acknowledgement.deepCopy()));
  }

  void heartbeat(Int64 lastReceivedSequence) {
    if (lastReceivedSequence.isNegative) {
      throw const FormatException('The heartbeat sequence cannot be negative.');
    }
    _send(
      ConnectClientRequest(
        heartbeat: Heartbeat(lastReceivedSequence: lastReceivedSequence),
      ),
    );
  }

  void _send(ConnectClientRequest request) {
    if (_closed || _requests.isClosed) {
      throw StateError('The Gateway live connection is closed.');
    }
    _requests.add(request);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_requests.isClosed) await _requests.close();
    await _subscription.cancel();
    if (!_frames.isClosed) unawaited(_frames.close());
  }
}

sealed class GatewayLiveFrame {
  const GatewayLiveFrame();
}

class GatewayHeartbeatFrame extends GatewayLiveFrame {
  const GatewayHeartbeatFrame(this.heartbeat);
  final Heartbeat heartbeat;
}

class GatewayEventFrame extends GatewayLiveFrame {
  const GatewayEventFrame(this.event);
  final EventEnvelope event;
}

class GatewayRequestStatusFrame extends GatewayLiveFrame {
  const GatewayRequestStatusFrame(this.status);
  final RequestStatus status;
}

class GatewayControlLeaseFrame extends GatewayLiveFrame {
  const GatewayControlLeaseFrame(this.lease);
  final ControlLease lease;
}

class GatewayReplayCompletedFrame extends GatewayLiveFrame {
  const GatewayReplayCompletedFrame(this.completion);
  final ReplayCompleted completion;
}

class GatewayDirectoryFrame extends GatewayLiveFrame {
  const GatewayDirectoryFrame(this.directory);
  final GatewayDirectory directory;
}

class GatewayConversationFrame extends GatewayLiveFrame {
  const GatewayConversationFrame(this.conversation);
  final ConversationDescriptor conversation;
}

class GatewayLiveTransportException implements Exception {
  const GatewayLiveTransportException({
    required this.code,
    required this.safeMessage,
    this.outcomeUncertain = false,
  });

  final String code;
  final String safeMessage;
  final bool outcomeUncertain;

  @override
  String toString() =>
      'GatewayLiveTransportException(code: $code, outcomeUncertain: '
      '$outcomeUncertain)';
}
