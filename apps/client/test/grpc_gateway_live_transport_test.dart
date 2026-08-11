import 'dart:async';

import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_gateway_live_transport.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

class FakeGatewayControlStreamingRpc implements GatewayControlStreamingRpc {
  final responses = StreamController<ConnectClientResponse>.broadcast();
  final requests = <ConnectClientRequest>[];
  final _requestChanged = StreamController<void>.broadcast();
  CallOptions? options;
  var connectCalls = 0;

  @override
  Stream<ConnectClientResponse> connectClient(
    Stream<ConnectClientRequest> requestStream, {
    CallOptions? options,
  }) {
    connectCalls += 1;
    this.options = options;
    requestStream.listen((request) {
      requests.add(request.deepCopy());
      _requestChanged.add(null);
    });
    return responses.stream;
  }

  Future<void> waitForRequests(int count) async {
    while (requests.length < count) {
      await _requestChanged.stream.first;
    }
  }

  Future<void> close() async {
    await responses.close();
    await _requestChanged.close();
  }
}

class ThrowingGatewayControlStreamingRpc implements GatewayControlStreamingRpc {
  @override
  Stream<ConnectClientResponse> connectClient(
    Stream<ConnectClientRequest> requestStream, {
    CallOptions? options,
  }) {
    throw StateError('secret-bearing local channel diagnostic');
  }
}

DeviceCredentialBundle credential({DateTime? accessExpiresAt}) =>
    DeviceCredentialBundle(
      keyReference: '0123456789abcdef0123456789abcdef',
      deviceId: 'device-1',
      credentialId: 'credential-1',
      gatewayAudience: 'https://gateway.example',
      scopes: const ['observe', 'send'],
      accessToken: 'ACCESS_TOKEN_0123456789_abcdef',
      refreshToken: 'REFRESH_TOKEN_0123456789_abcdefghijklmnop',
      accessExpiresAt: accessExpiresAt ?? DateTime.utc(2030, 1, 1, 0, 15),
      refreshExpiresAt: DateTime.utc(2030, 1, 31),
    );

HandshakeAccepted accepted({
  Iterable<String> scopes = const ['observe', 'send'],
  bool eventStream = true,
  bool attachments = false,
}) => HandshakeAccepted(
  selectedProtocol: ProtocolVersion(major: 1, minor: 0),
  connectionId: 'connection-1',
  schemaBuild: 'gateway-build-1',
  schemaSha256: List.filled(64, 'a').join(),
  componentVersion: '0.1.0',
  componentRole: ComponentRole.COMPONENT_ROLE_GATEWAY,
  capabilityRevision: 'gateway-capabilities-1',
  capabilities: AgentCapabilities(
    eventStream: eventStream,
    replay: true,
    sequenceRecovery: true,
    attachments: attachments,
  ),
  scopes: scopes,
);

Future<GatewayLiveConnection> openWithHandshake(
  GrpcGatewayLiveTransport transport,
  FakeGatewayControlStreamingRpc rpc, {
  HandshakeAccepted? handshake,
}) async {
  final opening = transport.open(credential());
  await rpc.waitForRequests(1);
  rpc.responses.add(ConnectClientResponse(handshake: handshake ?? accepted()));
  return opening;
}

void main() {
  test(
    'authenticates once and validates the complete protocol handshake',
    () async {
      final rpc = FakeGatewayControlStreamingRpc();
      addTearDown(rpc.close);
      final transport = GrpcGatewayLiveTransport(
        rpc,
        now: () => DateTime.utc(2030, 1, 1),
      );

      final connection = await openWithHandshake(transport, rpc);
      addTearDown(connection.close);

      expect(rpc.connectCalls, 1);
      expect(
        rpc.options!.metadata['authorization'],
        'Bearer ACCESS_TOKEN_0123456789_abcdef',
      );
      final offer = rpc.requests.single.handshake;
      expect(offer.currentProtocol.major, 1);
      expect(offer.currentProtocol.minor, 1);
      expect(offer.acceptedProtocols.minimumMinor, 0);
      expect(offer.acceptedProtocols.maximumMinor, 1);
      expect(offer.schemaSha256, GrpcGatewayLiveTransport.schemaSha256);
      expect(offer.componentRole, ComponentRole.COMPONENT_ROLE_CLIENT);
      expect(offer.capabilities.attachments, isFalse);
      expect(offer.scopes, ['observe', 'send']);
      expect(connection.handshake.connectionId, 'connection-1');
    },
  );

  test(
    'sends commands, exact acknowledgements, and monotonic heartbeat facts',
    () async {
      final rpc = FakeGatewayControlStreamingRpc();
      addTearDown(rpc.close);
      final connection = await openWithHandshake(
        GrpcGatewayLiveTransport(rpc, now: () => DateTime.utc(2030, 1, 1)),
        rpc,
      );
      addTearDown(connection.close);

      connection.sendCommand(
        ClientCommand(
          requestId: 'request-1',
          commandId: 'command-1',
          idempotencyKey: 'idempotency-1',
          conversationId: 'conversation-1',
          replay: ReplayEvents(afterSequence: Int64.ZERO, maximumEvents: 100),
        ),
      );
      connection.acknowledge(
        Ack(
          conversationId: 'conversation-1',
          sequence: Int64(7),
          eventId: 'event-7',
        ),
      );
      connection.heartbeat(Int64(7));
      await rpc.waitForRequests(4);

      expect(rpc.requests[1].whichBody(), ConnectClientRequest_Body.command);
      expect(rpc.requests[2].ack.eventId, 'event-7');
      expect(rpc.requests[3].heartbeat.lastReceivedSequence, Int64(7));
      expect(
        () => connection.acknowledge(Ack()),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => connection.heartbeat(Int64(-1)),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'maps post-handshake frames without exposing a second handshake',
    () async {
      final rpc = FakeGatewayControlStreamingRpc();
      addTearDown(rpc.close);
      final connection = await openWithHandshake(
        GrpcGatewayLiveTransport(rpc, now: () => DateTime.utc(2030, 1, 1)),
        rpc,
      );
      addTearDown(connection.close);
      final firstFrame = connection.frames.first;

      rpc.responses.add(
        ConnectClientResponse(
          event: EventEnvelope(
            eventId: 'event-1',
            conversationId: 'conversation-1',
            requestId: 'request-1',
            sequence: Int64.ONE,
            event: AgentEvent(
              type: AgentEventType.AGENT_EVENT_TYPE_AGENT_WORKING,
              requestProgress: RequestProgressEvent(safeMessage: 'Working.'),
            ),
          ),
        ),
      );

      final frame = await firstFrame;
      expect(frame, isA<GatewayEventFrame>());
      expect((frame as GatewayEventFrame).event.eventId, 'event-1');
    },
  );

  test('maps replay completion as a distinct central-router frame', () async {
    final rpc = FakeGatewayControlStreamingRpc();
    addTearDown(rpc.close);
    final connection = await openWithHandshake(
      GrpcGatewayLiveTransport(rpc, now: () => DateTime.utc(2030, 1, 1)),
      rpc,
    );
    addTearDown(connection.close);
    final firstFrame = connection.frames.first;

    rpc.responses.add(
      ConnectClientResponse(
        replayCompleted: ReplayCompleted(
          commandId: 'replay-command-1',
          conversationId: 'conversation-1',
          afterSequence: Int64.ZERO,
          throughSequence: Int64(2),
          eventCount: 2,
        ),
      ),
    );

    final frame = await firstFrame;
    expect(frame, isA<GatewayReplayCompletedFrame>());
    expect(
      (frame as GatewayReplayCompletedFrame).completion.commandId,
      'replay-command-1',
    );
  });

  test('closes the public frame stream and rejects later sends', () async {
    final rpc = FakeGatewayControlStreamingRpc();
    addTearDown(rpc.close);
    final connection = await openWithHandshake(
      GrpcGatewayLiveTransport(rpc, now: () => DateTime.utc(2030, 1, 1)),
      rpc,
    );
    final streamDone = connection.frames.drain<void>();

    await connection.close();

    await streamDone;
    expect(() => connection.heartbeat(Int64.ZERO), throwsA(isA<StateError>()));
  });

  test('rejects business data before handshake and never retries', () async {
    final rpc = FakeGatewayControlStreamingRpc();
    addTearDown(rpc.close);
    final transport = GrpcGatewayLiveTransport(
      rpc,
      now: () => DateTime.utc(2030, 1, 1),
    );
    final opening = transport.open(credential());
    await rpc.waitForRequests(1);
    rpc.responses.add(
      ConnectClientResponse(
        event: EventEnvelope(eventId: 'premature-secret-event'),
      ),
    );

    await expectLater(
      opening,
      throwsA(
        isA<GatewayLiveTransportException>().having(
          (error) => error.code,
          'code',
          'handshake_missing',
        ),
      ),
    );
    expect(rpc.connectCalls, 1);
  });

  test('rejects mismatched scopes and attachment capability', () async {
    for (final handshake in [
      accepted(scopes: const ['observe']),
      accepted(eventStream: false),
      accepted(attachments: true),
    ]) {
      final rpc = FakeGatewayControlStreamingRpc();
      final transport = GrpcGatewayLiveTransport(
        rpc,
        now: () => DateTime.utc(2030, 1, 1),
      );
      final opening = transport.open(credential());
      await rpc.waitForRequests(1);
      rpc.responses.add(ConnectClientResponse(handshake: handshake));

      await expectLater(
        opening,
        throwsA(
          isA<GatewayLiveTransportException>().having(
            (error) => error.code,
            'code',
            'handshake_invalid',
          ),
        ),
      );
      await rpc.close();
    }
  });

  test('redacts remote protocol errors and transport diagnostics', () async {
    final rpc = FakeGatewayControlStreamingRpc();
    addTearDown(rpc.close);
    final connection = await openWithHandshake(
      GrpcGatewayLiveTransport(rpc, now: () => DateTime.utc(2030, 1, 1)),
      rpc,
    );
    addTearDown(connection.close);

    final error = expectLater(
      connection.frames,
      emitsError(
        isA<GatewayLiveTransportException>()
            .having((value) => value.code, 'code', 'remote_protocol_error')
            .having(
              (value) => value.toString(),
              'redacted string',
              isNot(contains('secret-bearing')),
            ),
      ),
    );
    rpc.responses.add(
      ConnectClientResponse(
        protocolError: ProtocolError(
          code: 'remote_secret_code',
          safeMessage: 'secret-bearing remote diagnostics',
        ),
      ),
    );
    await error;
  });

  test('times out the first handshake without a silent reconnect', () async {
    final rpc = FakeGatewayControlStreamingRpc();
    addTearDown(rpc.close);
    final transport = GrpcGatewayLiveTransport(
      rpc,
      handshakeTimeout: const Duration(milliseconds: 20),
      now: () => DateTime.utc(2030, 1, 1),
    );

    await expectLater(
      transport.open(credential()),
      throwsA(
        isA<GatewayLiveTransportException>()
            .having((error) => error.code, 'code', 'handshake_timeout')
            .having(
              (error) => error.outcomeUncertain,
              'outcomeUncertain',
              isTrue,
            ),
      ),
    );
    expect(rpc.connectCalls, 1);
  });

  test('rejects expired credentials before opening a network stream', () async {
    final rpc = FakeGatewayControlStreamingRpc();
    addTearDown(rpc.close);
    final transport = GrpcGatewayLiveTransport(
      rpc,
      now: () => DateTime.utc(2030, 1, 1),
    );

    await expectLater(
      transport.open(credential(accessExpiresAt: DateTime.utc(2030, 1, 1))),
      throwsA(
        isA<GatewayLiveTransportException>().having(
          (error) => error.code,
          'code',
          'credential_invalid',
        ),
      ),
    );
    expect(rpc.connectCalls, 0);
  });

  test('redacts a synchronous channel-open failure', () async {
    final transport = GrpcGatewayLiveTransport(
      ThrowingGatewayControlStreamingRpc(),
      now: () => DateTime.utc(2030, 1, 1),
    );

    await expectLater(
      transport.open(credential()),
      throwsA(
        isA<GatewayLiveTransportException>()
            .having((error) => error.code, 'code', 'stream_unavailable')
            .having(
              (error) => error.toString(),
              'redacted string',
              isNot(contains('secret-bearing')),
            ),
      ),
    );
  });
}
