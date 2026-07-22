import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';

import '../../domain/client_event.dart';
import '../../domain/gateway_sync.dart';
import 'gateway_event_mapper.dart';
import 'grpc_gateway_live_transport.dart';

class GatewayFrameMappingException implements Exception {
  const GatewayFrameMappingException({
    required this.code,
    required this.safeMessage,
  });

  final String code;
  final String safeMessage;

  @override
  String toString() => 'GatewayFrameMappingException(code: $code)';
}

class GatewayFrameMapper {
  GatewayFrameMapper({GatewayEventMapper? eventMapper})
    : _eventMapper = eventMapper ?? GatewayEventMapper();

  final GatewayEventMapper _eventMapper;

  Future<ClientGatewayFrame> map(GatewayLiveFrame frame) async {
    try {
      return switch (frame) {
        GatewayEventFrame() => ClientGatewayEventFrame(
          await _eventMapper.map(frame.event),
        ),
        GatewayRequestStatusFrame() => ClientGatewayRequestStatusFrame(
          _requestStatus(frame.status),
        ),
        GatewayReplayCompletedFrame() => ClientGatewayReplayCompletedFrame(
          _replayCompletion(frame.completion),
        ),
        GatewayHeartbeatFrame() => ClientGatewayHeartbeatFrame(
          _uint64(frame.heartbeat.lastReceivedSequence),
        ),
        GatewayControlLeaseFrame() => ClientGatewayControlLeaseFrame(
          _controlLease(frame.lease),
        ),
      };
    } on GatewayEventMappingException {
      rethrow;
    } on GatewayFrameMappingException {
      rethrow;
    } on Object {
      throw const GatewayFrameMappingException(
        code: 'gateway_frame_invalid',
        safeMessage: 'The Gateway frame is invalid.',
      );
    }
  }

  ClientRequestStatusSnapshot _requestStatus(RequestStatus status) {
    final state = switch (status.state) {
      'accepted' => ClientRequestState.accepted,
      'working' => ClientRequestState.working,
      'completed' => ClientRequestState.completed,
      'failed' => ClientRequestState.failed,
      'cancelled' => ClientRequestState.cancelled,
      'interrupted' => ClientRequestState.interrupted,
      _ => throw const GatewayFrameMappingException(
        code: 'request_state_unknown',
        safeMessage: 'The request state requires a protocol upgrade.',
      ),
    };
    try {
      return ClientRequestStatusSnapshot(
        requestId: status.requestId,
        originDeviceId: status.originDeviceId,
        conversationId: status.conversationId,
        sessionId: status.sessionId.isEmpty ? null : status.sessionId,
        state: state,
        nodeId: status.nodeId,
        agentId: status.agentId,
        capabilityRevision: status.capabilityRevision,
        acceptedSequence: _uint64Required(status.acceptedSequence),
        failure: status.hasFailure() ? _failure(status.failure) : null,
      );
    } on FormatException {
      throw const GatewayFrameMappingException(
        code: 'request_status_invalid',
        safeMessage: 'The request status identity is invalid.',
      );
    }
  }

  ClientReplayCompletion _replayCompletion(ReplayCompleted completion) {
    try {
      return ClientReplayCompletion(
        commandId: completion.commandId,
        conversationId: completion.conversationId,
        afterSequence: _uint64(completion.afterSequence),
        throughSequence: _uint64(completion.throughSequence),
        eventCount: completion.eventCount,
        mayHaveMore: completion.mayHaveMore,
      );
    } on FormatException {
      throw const GatewayFrameMappingException(
        code: 'replay_completion_invalid',
        safeMessage: 'The replay completion fact is invalid.',
      );
    }
  }

  ClientControlLeaseSnapshot _controlLease(ControlLease lease) {
    if (!lease.hasExpiresAt()) {
      throw const GatewayFrameMappingException(
        code: 'control_lease_invalid',
        safeMessage: 'The control lease is incomplete.',
      );
    }
    try {
      return ClientControlLeaseSnapshot(
        leaseId: lease.leaseId,
        conversationId: lease.conversationId,
        deviceId: lease.deviceId,
        revision: _uint64Required(lease.revision),
        expiresAt: _timestamp(lease.expiresAt.seconds, lease.expiresAt.nanos),
      );
    } on FormatException {
      throw const GatewayFrameMappingException(
        code: 'control_lease_invalid',
        safeMessage: 'The control lease identity is invalid.',
      );
    }
  }

  ClientStageFailure _failure(StageFailure failure) => ClientStageFailure(
    stage: switch (failure.stage.value) {
      0 => ClientFailureStage.unspecified,
      1 => ClientFailureStage.recording,
      2 => ClientFailureStage.stt,
      3 => ClientFailureStage.connection,
      4 => ClientFailureStage.authentication,
      5 => ClientFailureStage.authorization,
      6 => ClientFailureStage.protocol,
      7 => ClientFailureStage.agent,
      8 => ClientFailureStage.summary,
      9 => ClientFailureStage.tts,
      10 => ClientFailureStage.playback,
      11 => ClientFailureStage.storage,
      12 => ClientFailureStage.sync,
      13 => ClientFailureStage.configuration,
      _ => throw const GatewayFrameMappingException(
        code: 'failure_stage_unknown',
        safeMessage: 'The failure stage requires a protocol upgrade.',
      ),
    },
    category: switch (failure.category.value) {
      0 => ClientFailureCategory.unspecified,
      1 => ClientFailureCategory.validation,
      2 => ClientFailureCategory.unavailable,
      3 => ClientFailureCategory.authentication,
      4 => ClientFailureCategory.authorization,
      5 => ClientFailureCategory.protocol,
      6 => ClientFailureCategory.timeout,
      7 => ClientFailureCategory.rateLimit,
      8 => ClientFailureCategory.upstream,
      9 => ClientFailureCategory.storage,
      10 => ClientFailureCategory.privacy,
      11 => ClientFailureCategory.unknown,
      _ => throw const GatewayFrameMappingException(
        code: 'failure_category_unknown',
        safeMessage: 'The failure category requires a protocol upgrade.',
      ),
    },
    code: failure.code,
    safeMessage: failure.safeMessage,
    retryable: failure.retryable,
  );

  BigInt _uint64(Int64 value) => BigInt.parse(value.toStringUnsigned());

  BigInt _uint64Required(Int64 value) {
    if (value == Int64.ZERO) {
      throw const GatewayFrameMappingException(
        code: 'uint64_zero',
        safeMessage: 'The Gateway sequence is incomplete.',
      );
    }
    return _uint64(value);
  }

  DateTime _timestamp(Int64 seconds, int nanos) {
    if (seconds < Int64(-62135596800) ||
        seconds > Int64(253402300799) ||
        nanos < 0 ||
        nanos > 999999999) {
      throw const GatewayFrameMappingException(
        code: 'timestamp_invalid',
        safeMessage: 'The Gateway timestamp is invalid.',
      );
    }
    return DateTime.fromMicrosecondsSinceEpoch(
      seconds.toInt() * Duration.microsecondsPerSecond + nanos ~/ 1000,
      isUtc: true,
    );
  }
}
