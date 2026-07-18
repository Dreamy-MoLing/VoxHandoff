// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/gateway.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pb.dart' as $3;
import 'control.pb.dart' as $1;
import 'event.pb.dart' as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

enum ConnectClientRequest_Body {
  handshake,
  heartbeat,
  ack,
  command,
  protocolError,
  notSet
}

class ConnectClientRequest extends $pb.GeneratedMessage {
  factory ConnectClientRequest({
    $1.HandshakeOffer? handshake,
    $1.Heartbeat? heartbeat,
    $1.Ack? ack,
    $1.ClientCommand? command,
    $1.ProtocolError? protocolError,
  }) {
    final result = create();
    if (handshake != null) result.handshake = handshake;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (ack != null) result.ack = ack;
    if (command != null) result.command = command;
    if (protocolError != null) result.protocolError = protocolError;
    return result;
  }

  ConnectClientRequest._();

  factory ConnectClientRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectClientRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ConnectClientRequest_Body>
      _ConnectClientRequest_BodyByTag = {
    1: ConnectClientRequest_Body.handshake,
    2: ConnectClientRequest_Body.heartbeat,
    3: ConnectClientRequest_Body.ack,
    4: ConnectClientRequest_Body.command,
    5: ConnectClientRequest_Body.protocolError,
    0: ConnectClientRequest_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectClientRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOM<$1.HandshakeOffer>(1, _omitFieldNames ? '' : 'handshake',
        subBuilder: $1.HandshakeOffer.create)
    ..aOM<$1.Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: $1.Heartbeat.create)
    ..aOM<$1.Ack>(3, _omitFieldNames ? '' : 'ack', subBuilder: $1.Ack.create)
    ..aOM<$1.ClientCommand>(4, _omitFieldNames ? '' : 'command',
        subBuilder: $1.ClientCommand.create)
    ..aOM<$1.ProtocolError>(5, _omitFieldNames ? '' : 'protocolError',
        subBuilder: $1.ProtocolError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectClientRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectClientRequest copyWith(void Function(ConnectClientRequest) updates) =>
      super.copyWith((message) => updates(message as ConnectClientRequest))
          as ConnectClientRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectClientRequest create() => ConnectClientRequest._();
  @$core.override
  ConnectClientRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectClientRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectClientRequest>(create);
  static ConnectClientRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  ConnectClientRequest_Body whichBody() =>
      _ConnectClientRequest_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $1.HandshakeOffer get handshake => $_getN(0);
  @$pb.TagNumber(1)
  set handshake($1.HandshakeOffer value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHandshake() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandshake() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.HandshakeOffer ensureHandshake() => $_ensure(0);

  @$pb.TagNumber(2)
  $1.Heartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat($1.Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Heartbeat ensureHeartbeat() => $_ensure(1);

  @$pb.TagNumber(3)
  $1.Ack get ack => $_getN(2);
  @$pb.TagNumber(3)
  set ack($1.Ack value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAck() => $_has(2);
  @$pb.TagNumber(3)
  void clearAck() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Ack ensureAck() => $_ensure(2);

  @$pb.TagNumber(4)
  $1.ClientCommand get command => $_getN(3);
  @$pb.TagNumber(4)
  set command($1.ClientCommand value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasCommand() => $_has(3);
  @$pb.TagNumber(4)
  void clearCommand() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.ClientCommand ensureCommand() => $_ensure(3);

  @$pb.TagNumber(5)
  $1.ProtocolError get protocolError => $_getN(4);
  @$pb.TagNumber(5)
  set protocolError($1.ProtocolError value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasProtocolError() => $_has(4);
  @$pb.TagNumber(5)
  void clearProtocolError() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.ProtocolError ensureProtocolError() => $_ensure(4);
}

enum ConnectClientResponse_Body {
  handshake,
  heartbeat,
  event,
  requestStatus,
  controlLease,
  protocolError,
  notSet
}

class ConnectClientResponse extends $pb.GeneratedMessage {
  factory ConnectClientResponse({
    $1.HandshakeAccepted? handshake,
    $1.Heartbeat? heartbeat,
    $2.EventEnvelope? event,
    $1.RequestStatus? requestStatus,
    $1.ControlLease? controlLease,
    $1.ProtocolError? protocolError,
  }) {
    final result = create();
    if (handshake != null) result.handshake = handshake;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (event != null) result.event = event;
    if (requestStatus != null) result.requestStatus = requestStatus;
    if (controlLease != null) result.controlLease = controlLease;
    if (protocolError != null) result.protocolError = protocolError;
    return result;
  }

  ConnectClientResponse._();

  factory ConnectClientResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectClientResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ConnectClientResponse_Body>
      _ConnectClientResponse_BodyByTag = {
    1: ConnectClientResponse_Body.handshake,
    2: ConnectClientResponse_Body.heartbeat,
    3: ConnectClientResponse_Body.event,
    4: ConnectClientResponse_Body.requestStatus,
    5: ConnectClientResponse_Body.controlLease,
    6: ConnectClientResponse_Body.protocolError,
    0: ConnectClientResponse_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectClientResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6])
    ..aOM<$1.HandshakeAccepted>(1, _omitFieldNames ? '' : 'handshake',
        subBuilder: $1.HandshakeAccepted.create)
    ..aOM<$1.Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: $1.Heartbeat.create)
    ..aOM<$2.EventEnvelope>(3, _omitFieldNames ? '' : 'event',
        subBuilder: $2.EventEnvelope.create)
    ..aOM<$1.RequestStatus>(4, _omitFieldNames ? '' : 'requestStatus',
        subBuilder: $1.RequestStatus.create)
    ..aOM<$1.ControlLease>(5, _omitFieldNames ? '' : 'controlLease',
        subBuilder: $1.ControlLease.create)
    ..aOM<$1.ProtocolError>(6, _omitFieldNames ? '' : 'protocolError',
        subBuilder: $1.ProtocolError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectClientResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectClientResponse copyWith(
          void Function(ConnectClientResponse) updates) =>
      super.copyWith((message) => updates(message as ConnectClientResponse))
          as ConnectClientResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectClientResponse create() => ConnectClientResponse._();
  @$core.override
  ConnectClientResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectClientResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectClientResponse>(create);
  static ConnectClientResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  ConnectClientResponse_Body whichBody() =>
      _ConnectClientResponse_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $1.HandshakeAccepted get handshake => $_getN(0);
  @$pb.TagNumber(1)
  set handshake($1.HandshakeAccepted value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHandshake() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandshake() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.HandshakeAccepted ensureHandshake() => $_ensure(0);

  @$pb.TagNumber(2)
  $1.Heartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat($1.Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Heartbeat ensureHeartbeat() => $_ensure(1);

  @$pb.TagNumber(3)
  $2.EventEnvelope get event => $_getN(2);
  @$pb.TagNumber(3)
  set event($2.EventEnvelope value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasEvent() => $_has(2);
  @$pb.TagNumber(3)
  void clearEvent() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.EventEnvelope ensureEvent() => $_ensure(2);

  @$pb.TagNumber(4)
  $1.RequestStatus get requestStatus => $_getN(3);
  @$pb.TagNumber(4)
  set requestStatus($1.RequestStatus value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRequestStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequestStatus() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.RequestStatus ensureRequestStatus() => $_ensure(3);

  @$pb.TagNumber(5)
  $1.ControlLease get controlLease => $_getN(4);
  @$pb.TagNumber(5)
  set controlLease($1.ControlLease value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasControlLease() => $_has(4);
  @$pb.TagNumber(5)
  void clearControlLease() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.ControlLease ensureControlLease() => $_ensure(4);

  @$pb.TagNumber(6)
  $1.ProtocolError get protocolError => $_getN(5);
  @$pb.TagNumber(6)
  set protocolError($1.ProtocolError value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasProtocolError() => $_has(5);
  @$pb.TagNumber(6)
  void clearProtocolError() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.ProtocolError ensureProtocolError() => $_ensure(5);
}

class NodeDescriptor extends $pb.GeneratedMessage {
  factory NodeDescriptor({
    $core.String? nodeId,
    $core.String? displayName,
    $core.String? platform,
    $core.String? version,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (displayName != null) result.displayName = displayName;
    if (platform != null) result.platform = platform;
    if (version != null) result.version = version;
    return result;
  }

  NodeDescriptor._();

  factory NodeDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..aOS(2, _omitFieldNames ? '' : 'displayName')
    ..aOS(3, _omitFieldNames ? '' : 'platform')
    ..aOS(4, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeDescriptor copyWith(void Function(NodeDescriptor) updates) =>
      super.copyWith((message) => updates(message as NodeDescriptor))
          as NodeDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeDescriptor create() => NodeDescriptor._();
  @$core.override
  NodeDescriptor createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeDescriptor>(create);
  static NodeDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get displayName => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get platform => $_getSZ(2);
  @$pb.TagNumber(3)
  set platform($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlatform() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlatform() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get version => $_getSZ(3);
  @$pb.TagNumber(4)
  set version($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearVersion() => $_clearField(4);
}

class AgentDescriptor extends $pb.GeneratedMessage {
  factory AgentDescriptor({
    $core.String? agentId,
    $core.String? displayName,
    $core.String? adapter,
    $core.String? version,
    $core.String? capabilityRevision,
    $3.AgentCapabilities? capabilities,
  }) {
    final result = create();
    if (agentId != null) result.agentId = agentId;
    if (displayName != null) result.displayName = displayName;
    if (adapter != null) result.adapter = adapter;
    if (version != null) result.version = version;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    if (capabilities != null) result.capabilities = capabilities;
    return result;
  }

  AgentDescriptor._();

  factory AgentDescriptor.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AgentDescriptor.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentDescriptor',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'agentId')
    ..aOS(2, _omitFieldNames ? '' : 'displayName')
    ..aOS(3, _omitFieldNames ? '' : 'adapter')
    ..aOS(4, _omitFieldNames ? '' : 'version')
    ..aOS(5, _omitFieldNames ? '' : 'capabilityRevision')
    ..aOM<$3.AgentCapabilities>(6, _omitFieldNames ? '' : 'capabilities',
        subBuilder: $3.AgentCapabilities.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentDescriptor clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentDescriptor copyWith(void Function(AgentDescriptor) updates) =>
      super.copyWith((message) => updates(message as AgentDescriptor))
          as AgentDescriptor;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AgentDescriptor create() => AgentDescriptor._();
  @$core.override
  AgentDescriptor createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AgentDescriptor getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentDescriptor>(create);
  static AgentDescriptor? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set agentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get displayName => $_getSZ(1);
  @$pb.TagNumber(2)
  set displayName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayName() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get adapter => $_getSZ(2);
  @$pb.TagNumber(3)
  set adapter($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAdapter() => $_has(2);
  @$pb.TagNumber(3)
  void clearAdapter() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get version => $_getSZ(3);
  @$pb.TagNumber(4)
  set version($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get capabilityRevision => $_getSZ(4);
  @$pb.TagNumber(5)
  set capabilityRevision($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCapabilityRevision() => $_has(4);
  @$pb.TagNumber(5)
  void clearCapabilityRevision() => $_clearField(5);

  @$pb.TagNumber(6)
  $3.AgentCapabilities get capabilities => $_getN(5);
  @$pb.TagNumber(6)
  set capabilities($3.AgentCapabilities value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCapabilities() => $_has(5);
  @$pb.TagNumber(6)
  void clearCapabilities() => $_clearField(6);
  @$pb.TagNumber(6)
  $3.AgentCapabilities ensureCapabilities() => $_ensure(5);
}

class NodeRegistration extends $pb.GeneratedMessage {
  factory NodeRegistration({
    NodeDescriptor? node,
    $core.Iterable<AgentDescriptor>? agents,
  }) {
    final result = create();
    if (node != null) result.node = node;
    if (agents != null) result.agents.addAll(agents);
    return result;
  }

  NodeRegistration._();

  factory NodeRegistration.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory NodeRegistration.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'NodeRegistration',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOM<NodeDescriptor>(1, _omitFieldNames ? '' : 'node',
        subBuilder: NodeDescriptor.create)
    ..pPM<AgentDescriptor>(2, _omitFieldNames ? '' : 'agents',
        subBuilder: AgentDescriptor.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeRegistration clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  NodeRegistration copyWith(void Function(NodeRegistration) updates) =>
      super.copyWith((message) => updates(message as NodeRegistration))
          as NodeRegistration;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static NodeRegistration create() => NodeRegistration._();
  @$core.override
  NodeRegistration createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static NodeRegistration getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<NodeRegistration>(create);
  static NodeRegistration? _defaultInstance;

  @$pb.TagNumber(1)
  NodeDescriptor get node => $_getN(0);
  @$pb.TagNumber(1)
  set node(NodeDescriptor value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasNode() => $_has(0);
  @$pb.TagNumber(1)
  void clearNode() => $_clearField(1);
  @$pb.TagNumber(1)
  NodeDescriptor ensureNode() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<AgentDescriptor> get agents => $_getList(1);
}

class DispatchRequest extends $pb.GeneratedMessage {
  factory DispatchRequest({
    $core.String? dispatchId,
    $core.String? requestId,
    $core.String? idempotencyKey,
    $core.String? conversationId,
    $core.String? sessionId,
    $core.String? nodeId,
    $core.String? agentId,
    $core.String? capabilityRevision,
    $core.String? confirmedText,
  }) {
    final result = create();
    if (dispatchId != null) result.dispatchId = dispatchId;
    if (requestId != null) result.requestId = requestId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (conversationId != null) result.conversationId = conversationId;
    if (sessionId != null) result.sessionId = sessionId;
    if (nodeId != null) result.nodeId = nodeId;
    if (agentId != null) result.agentId = agentId;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    if (confirmedText != null) result.confirmedText = confirmedText;
    return result;
  }

  DispatchRequest._();

  factory DispatchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DispatchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DispatchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dispatchId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(4, _omitFieldNames ? '' : 'conversationId')
    ..aOS(5, _omitFieldNames ? '' : 'sessionId')
    ..aOS(6, _omitFieldNames ? '' : 'nodeId')
    ..aOS(7, _omitFieldNames ? '' : 'agentId')
    ..aOS(8, _omitFieldNames ? '' : 'capabilityRevision')
    ..aOS(9, _omitFieldNames ? '' : 'confirmedText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchRequest copyWith(void Function(DispatchRequest) updates) =>
      super.copyWith((message) => updates(message as DispatchRequest))
          as DispatchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DispatchRequest create() => DispatchRequest._();
  @$core.override
  DispatchRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DispatchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DispatchRequest>(create);
  static DispatchRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dispatchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dispatchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDispatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDispatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get idempotencyKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set idempotencyKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdempotencyKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdempotencyKey() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get conversationId => $_getSZ(3);
  @$pb.TagNumber(4)
  set conversationId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConversationId() => $_has(3);
  @$pb.TagNumber(4)
  void clearConversationId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sessionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set sessionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get nodeId => $_getSZ(5);
  @$pb.TagNumber(6)
  set nodeId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNodeId() => $_has(5);
  @$pb.TagNumber(6)
  void clearNodeId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get agentId => $_getSZ(6);
  @$pb.TagNumber(7)
  set agentId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAgentId() => $_has(6);
  @$pb.TagNumber(7)
  void clearAgentId() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get capabilityRevision => $_getSZ(7);
  @$pb.TagNumber(8)
  set capabilityRevision($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCapabilityRevision() => $_has(7);
  @$pb.TagNumber(8)
  void clearCapabilityRevision() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get confirmedText => $_getSZ(8);
  @$pb.TagNumber(9)
  set confirmedText($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasConfirmedText() => $_has(8);
  @$pb.TagNumber(9)
  void clearConfirmedText() => $_clearField(9);
}

class DispatchInterrupt extends $pb.GeneratedMessage {
  factory DispatchInterrupt({
    $core.String? dispatchId,
    $core.String? requestId,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (dispatchId != null) result.dispatchId = dispatchId;
    if (requestId != null) result.requestId = requestId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  DispatchInterrupt._();

  factory DispatchInterrupt.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DispatchInterrupt.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DispatchInterrupt',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dispatchId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchInterrupt clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchInterrupt copyWith(void Function(DispatchInterrupt) updates) =>
      super.copyWith((message) => updates(message as DispatchInterrupt))
          as DispatchInterrupt;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DispatchInterrupt create() => DispatchInterrupt._();
  @$core.override
  DispatchInterrupt createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DispatchInterrupt getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DispatchInterrupt>(create);
  static DispatchInterrupt? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dispatchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dispatchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDispatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDispatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get idempotencyKey => $_getSZ(2);
  @$pb.TagNumber(3)
  set idempotencyKey($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIdempotencyKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearIdempotencyKey() => $_clearField(3);
}

class DispatchApproval extends $pb.GeneratedMessage {
  factory DispatchApproval({
    $core.String? dispatchId,
    $core.String? requestId,
    $core.String? approvalId,
    $core.String? idempotencyKey,
    $1.ApprovalDecision? decision,
    $core.String? operationSummarySha256,
  }) {
    final result = create();
    if (dispatchId != null) result.dispatchId = dispatchId;
    if (requestId != null) result.requestId = requestId;
    if (approvalId != null) result.approvalId = approvalId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (decision != null) result.decision = decision;
    if (operationSummarySha256 != null)
      result.operationSummarySha256 = operationSummarySha256;
    return result;
  }

  DispatchApproval._();

  factory DispatchApproval.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DispatchApproval.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DispatchApproval',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dispatchId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'approvalId')
    ..aOS(4, _omitFieldNames ? '' : 'idempotencyKey')
    ..aE<$1.ApprovalDecision>(5, _omitFieldNames ? '' : 'decision',
        enumValues: $1.ApprovalDecision.values)
    ..aOS(6, _omitFieldNames ? '' : 'operationSummarySha256')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchApproval clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchApproval copyWith(void Function(DispatchApproval) updates) =>
      super.copyWith((message) => updates(message as DispatchApproval))
          as DispatchApproval;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DispatchApproval create() => DispatchApproval._();
  @$core.override
  DispatchApproval createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DispatchApproval getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DispatchApproval>(create);
  static DispatchApproval? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dispatchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dispatchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDispatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDispatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get approvalId => $_getSZ(2);
  @$pb.TagNumber(3)
  set approvalId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasApprovalId() => $_has(2);
  @$pb.TagNumber(3)
  void clearApprovalId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get idempotencyKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set idempotencyKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIdempotencyKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearIdempotencyKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.ApprovalDecision get decision => $_getN(4);
  @$pb.TagNumber(5)
  set decision($1.ApprovalDecision value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDecision() => $_has(4);
  @$pb.TagNumber(5)
  void clearDecision() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get operationSummarySha256 => $_getSZ(5);
  @$pb.TagNumber(6)
  set operationSummarySha256($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOperationSummarySha256() => $_has(5);
  @$pb.TagNumber(6)
  void clearOperationSummarySha256() => $_clearField(6);
}

class DispatchClarification extends $pb.GeneratedMessage {
  factory DispatchClarification({
    $core.String? dispatchId,
    $core.String? requestId,
    $core.String? clarificationId,
    $core.String? idempotencyKey,
    $core.String? confirmedText,
  }) {
    final result = create();
    if (dispatchId != null) result.dispatchId = dispatchId;
    if (requestId != null) result.requestId = requestId;
    if (clarificationId != null) result.clarificationId = clarificationId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (confirmedText != null) result.confirmedText = confirmedText;
    return result;
  }

  DispatchClarification._();

  factory DispatchClarification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DispatchClarification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DispatchClarification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dispatchId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOS(3, _omitFieldNames ? '' : 'clarificationId')
    ..aOS(4, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(5, _omitFieldNames ? '' : 'confirmedText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchClarification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchClarification copyWith(
          void Function(DispatchClarification) updates) =>
      super.copyWith((message) => updates(message as DispatchClarification))
          as DispatchClarification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DispatchClarification create() => DispatchClarification._();
  @$core.override
  DispatchClarification createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DispatchClarification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DispatchClarification>(create);
  static DispatchClarification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dispatchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dispatchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDispatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDispatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get clarificationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set clarificationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasClarificationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearClarificationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get idempotencyKey => $_getSZ(3);
  @$pb.TagNumber(4)
  set idempotencyKey($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIdempotencyKey() => $_has(3);
  @$pb.TagNumber(4)
  void clearIdempotencyKey() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get confirmedText => $_getSZ(4);
  @$pb.TagNumber(5)
  set confirmedText($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasConfirmedText() => $_has(4);
  @$pb.TagNumber(5)
  void clearConfirmedText() => $_clearField(5);
}

class DispatchAck extends $pb.GeneratedMessage {
  factory DispatchAck({
    $core.String? dispatchId,
    $core.String? requestId,
    $core.bool? accepted,
    $3.StageFailure? failure,
  }) {
    final result = create();
    if (dispatchId != null) result.dispatchId = dispatchId;
    if (requestId != null) result.requestId = requestId;
    if (accepted != null) result.accepted = accepted;
    if (failure != null) result.failure = failure;
    return result;
  }

  DispatchAck._();

  factory DispatchAck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DispatchAck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DispatchAck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'dispatchId')
    ..aOS(2, _omitFieldNames ? '' : 'requestId')
    ..aOB(3, _omitFieldNames ? '' : 'accepted')
    ..aOM<$3.StageFailure>(4, _omitFieldNames ? '' : 'failure',
        subBuilder: $3.StageFailure.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchAck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DispatchAck copyWith(void Function(DispatchAck) updates) =>
      super.copyWith((message) => updates(message as DispatchAck))
          as DispatchAck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DispatchAck create() => DispatchAck._();
  @$core.override
  DispatchAck createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DispatchAck getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DispatchAck>(create);
  static DispatchAck? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get dispatchId => $_getSZ(0);
  @$pb.TagNumber(1)
  set dispatchId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDispatchId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDispatchId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get requestId => $_getSZ(1);
  @$pb.TagNumber(2)
  set requestId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRequestId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRequestId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get accepted => $_getBF(2);
  @$pb.TagNumber(3)
  set accepted($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccepted() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccepted() => $_clearField(3);

  @$pb.TagNumber(4)
  $3.StageFailure get failure => $_getN(3);
  @$pb.TagNumber(4)
  set failure($3.StageFailure value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasFailure() => $_has(3);
  @$pb.TagNumber(4)
  void clearFailure() => $_clearField(4);
  @$pb.TagNumber(4)
  $3.StageFailure ensureFailure() => $_ensure(3);
}

enum ConnectNodeRequest_Body {
  handshake,
  heartbeat,
  registration,
  dispatchAck,
  event,
  protocolError,
  notSet
}

class ConnectNodeRequest extends $pb.GeneratedMessage {
  factory ConnectNodeRequest({
    $1.HandshakeOffer? handshake,
    $1.Heartbeat? heartbeat,
    NodeRegistration? registration,
    DispatchAck? dispatchAck,
    $2.EventEnvelope? event,
    $1.ProtocolError? protocolError,
  }) {
    final result = create();
    if (handshake != null) result.handshake = handshake;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (registration != null) result.registration = registration;
    if (dispatchAck != null) result.dispatchAck = dispatchAck;
    if (event != null) result.event = event;
    if (protocolError != null) result.protocolError = protocolError;
    return result;
  }

  ConnectNodeRequest._();

  factory ConnectNodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectNodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ConnectNodeRequest_Body>
      _ConnectNodeRequest_BodyByTag = {
    1: ConnectNodeRequest_Body.handshake,
    2: ConnectNodeRequest_Body.heartbeat,
    3: ConnectNodeRequest_Body.registration,
    4: ConnectNodeRequest_Body.dispatchAck,
    5: ConnectNodeRequest_Body.event,
    6: ConnectNodeRequest_Body.protocolError,
    0: ConnectNodeRequest_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectNodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6])
    ..aOM<$1.HandshakeOffer>(1, _omitFieldNames ? '' : 'handshake',
        subBuilder: $1.HandshakeOffer.create)
    ..aOM<$1.Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: $1.Heartbeat.create)
    ..aOM<NodeRegistration>(3, _omitFieldNames ? '' : 'registration',
        subBuilder: NodeRegistration.create)
    ..aOM<DispatchAck>(4, _omitFieldNames ? '' : 'dispatchAck',
        subBuilder: DispatchAck.create)
    ..aOM<$2.EventEnvelope>(5, _omitFieldNames ? '' : 'event',
        subBuilder: $2.EventEnvelope.create)
    ..aOM<$1.ProtocolError>(6, _omitFieldNames ? '' : 'protocolError',
        subBuilder: $1.ProtocolError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectNodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectNodeRequest copyWith(void Function(ConnectNodeRequest) updates) =>
      super.copyWith((message) => updates(message as ConnectNodeRequest))
          as ConnectNodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectNodeRequest create() => ConnectNodeRequest._();
  @$core.override
  ConnectNodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectNodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectNodeRequest>(create);
  static ConnectNodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  ConnectNodeRequest_Body whichBody() =>
      _ConnectNodeRequest_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $1.HandshakeOffer get handshake => $_getN(0);
  @$pb.TagNumber(1)
  set handshake($1.HandshakeOffer value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHandshake() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandshake() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.HandshakeOffer ensureHandshake() => $_ensure(0);

  @$pb.TagNumber(2)
  $1.Heartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat($1.Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Heartbeat ensureHeartbeat() => $_ensure(1);

  @$pb.TagNumber(3)
  NodeRegistration get registration => $_getN(2);
  @$pb.TagNumber(3)
  set registration(NodeRegistration value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasRegistration() => $_has(2);
  @$pb.TagNumber(3)
  void clearRegistration() => $_clearField(3);
  @$pb.TagNumber(3)
  NodeRegistration ensureRegistration() => $_ensure(2);

  @$pb.TagNumber(4)
  DispatchAck get dispatchAck => $_getN(3);
  @$pb.TagNumber(4)
  set dispatchAck(DispatchAck value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDispatchAck() => $_has(3);
  @$pb.TagNumber(4)
  void clearDispatchAck() => $_clearField(4);
  @$pb.TagNumber(4)
  DispatchAck ensureDispatchAck() => $_ensure(3);

  @$pb.TagNumber(5)
  $2.EventEnvelope get event => $_getN(4);
  @$pb.TagNumber(5)
  set event($2.EventEnvelope value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasEvent() => $_has(4);
  @$pb.TagNumber(5)
  void clearEvent() => $_clearField(5);
  @$pb.TagNumber(5)
  $2.EventEnvelope ensureEvent() => $_ensure(4);

  @$pb.TagNumber(6)
  $1.ProtocolError get protocolError => $_getN(5);
  @$pb.TagNumber(6)
  set protocolError($1.ProtocolError value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasProtocolError() => $_has(5);
  @$pb.TagNumber(6)
  void clearProtocolError() => $_clearField(6);
  @$pb.TagNumber(6)
  $1.ProtocolError ensureProtocolError() => $_ensure(5);
}

enum ConnectNodeResponse_Body {
  handshake,
  heartbeat,
  dispatchRequest,
  dispatchInterrupt,
  dispatchApproval,
  dispatchClarification,
  protocolError,
  notSet
}

class ConnectNodeResponse extends $pb.GeneratedMessage {
  factory ConnectNodeResponse({
    $1.HandshakeAccepted? handshake,
    $1.Heartbeat? heartbeat,
    DispatchRequest? dispatchRequest,
    DispatchInterrupt? dispatchInterrupt,
    DispatchApproval? dispatchApproval,
    DispatchClarification? dispatchClarification,
    $1.ProtocolError? protocolError,
  }) {
    final result = create();
    if (handshake != null) result.handshake = handshake;
    if (heartbeat != null) result.heartbeat = heartbeat;
    if (dispatchRequest != null) result.dispatchRequest = dispatchRequest;
    if (dispatchInterrupt != null) result.dispatchInterrupt = dispatchInterrupt;
    if (dispatchApproval != null) result.dispatchApproval = dispatchApproval;
    if (dispatchClarification != null)
      result.dispatchClarification = dispatchClarification;
    if (protocolError != null) result.protocolError = protocolError;
    return result;
  }

  ConnectNodeResponse._();

  factory ConnectNodeResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectNodeResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ConnectNodeResponse_Body>
      _ConnectNodeResponse_BodyByTag = {
    1: ConnectNodeResponse_Body.handshake,
    2: ConnectNodeResponse_Body.heartbeat,
    3: ConnectNodeResponse_Body.dispatchRequest,
    4: ConnectNodeResponse_Body.dispatchInterrupt,
    5: ConnectNodeResponse_Body.dispatchApproval,
    6: ConnectNodeResponse_Body.dispatchClarification,
    7: ConnectNodeResponse_Body.protocolError,
    0: ConnectNodeResponse_Body.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectNodeResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..oo(0, [1, 2, 3, 4, 5, 6, 7])
    ..aOM<$1.HandshakeAccepted>(1, _omitFieldNames ? '' : 'handshake',
        subBuilder: $1.HandshakeAccepted.create)
    ..aOM<$1.Heartbeat>(2, _omitFieldNames ? '' : 'heartbeat',
        subBuilder: $1.Heartbeat.create)
    ..aOM<DispatchRequest>(3, _omitFieldNames ? '' : 'dispatchRequest',
        subBuilder: DispatchRequest.create)
    ..aOM<DispatchInterrupt>(4, _omitFieldNames ? '' : 'dispatchInterrupt',
        subBuilder: DispatchInterrupt.create)
    ..aOM<DispatchApproval>(5, _omitFieldNames ? '' : 'dispatchApproval',
        subBuilder: DispatchApproval.create)
    ..aOM<DispatchClarification>(
        6, _omitFieldNames ? '' : 'dispatchClarification',
        subBuilder: DispatchClarification.create)
    ..aOM<$1.ProtocolError>(7, _omitFieldNames ? '' : 'protocolError',
        subBuilder: $1.ProtocolError.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectNodeResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectNodeResponse copyWith(void Function(ConnectNodeResponse) updates) =>
      super.copyWith((message) => updates(message as ConnectNodeResponse))
          as ConnectNodeResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectNodeResponse create() => ConnectNodeResponse._();
  @$core.override
  ConnectNodeResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectNodeResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectNodeResponse>(create);
  static ConnectNodeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  ConnectNodeResponse_Body whichBody() =>
      _ConnectNodeResponse_BodyByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(1)
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(6)
  @$pb.TagNumber(7)
  void clearBody() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $1.HandshakeAccepted get handshake => $_getN(0);
  @$pb.TagNumber(1)
  set handshake($1.HandshakeAccepted value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasHandshake() => $_has(0);
  @$pb.TagNumber(1)
  void clearHandshake() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.HandshakeAccepted ensureHandshake() => $_ensure(0);

  @$pb.TagNumber(2)
  $1.Heartbeat get heartbeat => $_getN(1);
  @$pb.TagNumber(2)
  set heartbeat($1.Heartbeat value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasHeartbeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearHeartbeat() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.Heartbeat ensureHeartbeat() => $_ensure(1);

  @$pb.TagNumber(3)
  DispatchRequest get dispatchRequest => $_getN(2);
  @$pb.TagNumber(3)
  set dispatchRequest(DispatchRequest value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDispatchRequest() => $_has(2);
  @$pb.TagNumber(3)
  void clearDispatchRequest() => $_clearField(3);
  @$pb.TagNumber(3)
  DispatchRequest ensureDispatchRequest() => $_ensure(2);

  @$pb.TagNumber(4)
  DispatchInterrupt get dispatchInterrupt => $_getN(3);
  @$pb.TagNumber(4)
  set dispatchInterrupt(DispatchInterrupt value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDispatchInterrupt() => $_has(3);
  @$pb.TagNumber(4)
  void clearDispatchInterrupt() => $_clearField(4);
  @$pb.TagNumber(4)
  DispatchInterrupt ensureDispatchInterrupt() => $_ensure(3);

  @$pb.TagNumber(5)
  DispatchApproval get dispatchApproval => $_getN(4);
  @$pb.TagNumber(5)
  set dispatchApproval(DispatchApproval value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDispatchApproval() => $_has(4);
  @$pb.TagNumber(5)
  void clearDispatchApproval() => $_clearField(5);
  @$pb.TagNumber(5)
  DispatchApproval ensureDispatchApproval() => $_ensure(4);

  @$pb.TagNumber(6)
  DispatchClarification get dispatchClarification => $_getN(5);
  @$pb.TagNumber(6)
  set dispatchClarification(DispatchClarification value) =>
      $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasDispatchClarification() => $_has(5);
  @$pb.TagNumber(6)
  void clearDispatchClarification() => $_clearField(6);
  @$pb.TagNumber(6)
  DispatchClarification ensureDispatchClarification() => $_ensure(5);

  @$pb.TagNumber(7)
  $1.ProtocolError get protocolError => $_getN(6);
  @$pb.TagNumber(7)
  set protocolError($1.ProtocolError value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasProtocolError() => $_has(6);
  @$pb.TagNumber(7)
  void clearProtocolError() => $_clearField(7);
  @$pb.TagNumber(7)
  $1.ProtocolError ensureProtocolError() => $_ensure(6);
}

class BeginPairingRequest extends $pb.GeneratedMessage {
  factory BeginPairingRequest({
    $core.String? deviceDisplayName,
    $core.List<$core.int>? devicePublicKey,
  }) {
    final result = create();
    if (deviceDisplayName != null) result.deviceDisplayName = deviceDisplayName;
    if (devicePublicKey != null) result.devicePublicKey = devicePublicKey;
    return result;
  }

  BeginPairingRequest._();

  factory BeginPairingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginPairingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginPairingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceDisplayName')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'devicePublicKey', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginPairingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginPairingRequest copyWith(void Function(BeginPairingRequest) updates) =>
      super.copyWith((message) => updates(message as BeginPairingRequest))
          as BeginPairingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginPairingRequest create() => BeginPairingRequest._();
  @$core.override
  BeginPairingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeginPairingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginPairingRequest>(create);
  static BeginPairingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceDisplayName => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceDisplayName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceDisplayName() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceDisplayName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get devicePublicKey => $_getN(1);
  @$pb.TagNumber(2)
  set devicePublicKey($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDevicePublicKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearDevicePublicKey() => $_clearField(2);
}

class BeginPairingResponse extends $pb.GeneratedMessage {
  factory BeginPairingResponse({
    $core.String? pairingId,
    $core.String? userCode,
    $core.String? verificationUri,
    $core.int? expiresInSeconds,
  }) {
    final result = create();
    if (pairingId != null) result.pairingId = pairingId;
    if (userCode != null) result.userCode = userCode;
    if (verificationUri != null) result.verificationUri = verificationUri;
    if (expiresInSeconds != null) result.expiresInSeconds = expiresInSeconds;
    return result;
  }

  BeginPairingResponse._();

  factory BeginPairingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginPairingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginPairingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pairingId')
    ..aOS(2, _omitFieldNames ? '' : 'userCode')
    ..aOS(3, _omitFieldNames ? '' : 'verificationUri')
    ..aI(4, _omitFieldNames ? '' : 'expiresInSeconds',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginPairingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginPairingResponse copyWith(void Function(BeginPairingResponse) updates) =>
      super.copyWith((message) => updates(message as BeginPairingResponse))
          as BeginPairingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginPairingResponse create() => BeginPairingResponse._();
  @$core.override
  BeginPairingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeginPairingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginPairingResponse>(create);
  static BeginPairingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairingId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairingId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairingId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairingId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get userCode => $_getSZ(1);
  @$pb.TagNumber(2)
  set userCode($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUserCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearUserCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get verificationUri => $_getSZ(2);
  @$pb.TagNumber(3)
  set verificationUri($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVerificationUri() => $_has(2);
  @$pb.TagNumber(3)
  void clearVerificationUri() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get expiresInSeconds => $_getIZ(3);
  @$pb.TagNumber(4)
  set expiresInSeconds($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresInSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresInSeconds() => $_clearField(4);
}

class CompletePairingRequest extends $pb.GeneratedMessage {
  factory CompletePairingRequest({
    $core.String? pairingId,
    $core.String? deviceProof,
  }) {
    final result = create();
    if (pairingId != null) result.pairingId = pairingId;
    if (deviceProof != null) result.deviceProof = deviceProof;
    return result;
  }

  CompletePairingRequest._();

  factory CompletePairingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompletePairingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompletePairingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'pairingId')
    ..aOS(2, _omitFieldNames ? '' : 'deviceProof')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletePairingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletePairingRequest copyWith(
          void Function(CompletePairingRequest) updates) =>
      super.copyWith((message) => updates(message as CompletePairingRequest))
          as CompletePairingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompletePairingRequest create() => CompletePairingRequest._();
  @$core.override
  CompletePairingRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompletePairingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompletePairingRequest>(create);
  static CompletePairingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get pairingId => $_getSZ(0);
  @$pb.TagNumber(1)
  set pairingId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPairingId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPairingId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get deviceProof => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceProof($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceProof() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceProof() => $_clearField(2);
}

class CompletePairingResponse extends $pb.GeneratedMessage {
  factory CompletePairingResponse({
    $core.String? deviceId,
    $core.String? accessToken,
    $core.String? refreshToken,
    $core.Iterable<$core.String>? scopes,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (accessToken != null) result.accessToken = accessToken;
    if (refreshToken != null) result.refreshToken = refreshToken;
    if (scopes != null) result.scopes.addAll(scopes);
    return result;
  }

  CompletePairingResponse._();

  factory CompletePairingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompletePairingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompletePairingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aOS(2, _omitFieldNames ? '' : 'accessToken')
    ..aOS(3, _omitFieldNames ? '' : 'refreshToken')
    ..pPS(4, _omitFieldNames ? '' : 'scopes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletePairingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompletePairingResponse copyWith(
          void Function(CompletePairingResponse) updates) =>
      super.copyWith((message) => updates(message as CompletePairingResponse))
          as CompletePairingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompletePairingResponse create() => CompletePairingResponse._();
  @$core.override
  CompletePairingResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompletePairingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompletePairingResponse>(create);
  static CompletePairingResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get accessToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set accessToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccessToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccessToken() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get refreshToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set refreshToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRefreshToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearRefreshToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.String> get scopes => $_getList(3);
}

class RevokeDeviceRequest extends $pb.GeneratedMessage {
  factory RevokeDeviceRequest({
    $core.String? deviceId,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  RevokeDeviceRequest._();

  factory RevokeDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceRequest copyWith(void Function(RevokeDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RevokeDeviceRequest))
          as RevokeDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeDeviceRequest create() => RevokeDeviceRequest._();
  @$core.override
  RevokeDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeDeviceRequest>(create);
  static RevokeDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);
}

class RevokeDeviceResponse extends $pb.GeneratedMessage {
  factory RevokeDeviceResponse({
    $core.bool? revoked,
  }) {
    final result = create();
    if (revoked != null) result.revoked = revoked;
    return result;
  }

  RevokeDeviceResponse._();

  factory RevokeDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RevokeDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'revoked')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceResponse copyWith(void Function(RevokeDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as RevokeDeviceResponse))
          as RevokeDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RevokeDeviceResponse create() => RevokeDeviceResponse._();
  @$core.override
  RevokeDeviceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RevokeDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeDeviceResponse>(create);
  static RevokeDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get revoked => $_getBF(0);
  @$pb.TagNumber(1)
  set revoked($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRevoked() => $_has(0);
  @$pb.TagNumber(1)
  void clearRevoked() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
