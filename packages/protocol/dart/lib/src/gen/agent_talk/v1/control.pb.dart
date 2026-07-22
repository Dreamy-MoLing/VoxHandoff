// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/control.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $1;

import 'common.pb.dart' as $0;
import 'control.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'control.pbenum.dart';

class HandshakeOffer extends $pb.GeneratedMessage {
  factory HandshakeOffer({
    $0.ProtocolVersion? currentProtocol,
    $0.ProtocolVersionRange? acceptedProtocols,
    $core.String? schemaBuild,
    $core.String? schemaSha256,
    $core.String? componentVersion,
    $0.ComponentRole? componentRole,
    $core.String? capabilityRevision,
    $0.AgentCapabilities? capabilities,
    $core.Iterable<$core.String>? scopes,
  }) {
    final result = create();
    if (currentProtocol != null) result.currentProtocol = currentProtocol;
    if (acceptedProtocols != null) result.acceptedProtocols = acceptedProtocols;
    if (schemaBuild != null) result.schemaBuild = schemaBuild;
    if (schemaSha256 != null) result.schemaSha256 = schemaSha256;
    if (componentVersion != null) result.componentVersion = componentVersion;
    if (componentRole != null) result.componentRole = componentRole;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    if (capabilities != null) result.capabilities = capabilities;
    if (scopes != null) result.scopes.addAll(scopes);
    return result;
  }

  HandshakeOffer._();

  factory HandshakeOffer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HandshakeOffer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HandshakeOffer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOM<$0.ProtocolVersion>(1, _omitFieldNames ? '' : 'currentProtocol',
        subBuilder: $0.ProtocolVersion.create)
    ..aOM<$0.ProtocolVersionRange>(
        2, _omitFieldNames ? '' : 'acceptedProtocols',
        subBuilder: $0.ProtocolVersionRange.create)
    ..aOS(3, _omitFieldNames ? '' : 'schemaBuild')
    ..aOS(4, _omitFieldNames ? '' : 'schemaSha256')
    ..aOS(5, _omitFieldNames ? '' : 'componentVersion')
    ..aE<$0.ComponentRole>(6, _omitFieldNames ? '' : 'componentRole',
        enumValues: $0.ComponentRole.values)
    ..aOS(7, _omitFieldNames ? '' : 'capabilityRevision')
    ..aOM<$0.AgentCapabilities>(8, _omitFieldNames ? '' : 'capabilities',
        subBuilder: $0.AgentCapabilities.create)
    ..pPS(9, _omitFieldNames ? '' : 'scopes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HandshakeOffer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HandshakeOffer copyWith(void Function(HandshakeOffer) updates) =>
      super.copyWith((message) => updates(message as HandshakeOffer))
          as HandshakeOffer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HandshakeOffer create() => HandshakeOffer._();
  @$core.override
  HandshakeOffer createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HandshakeOffer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HandshakeOffer>(create);
  static HandshakeOffer? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ProtocolVersion get currentProtocol => $_getN(0);
  @$pb.TagNumber(1)
  set currentProtocol($0.ProtocolVersion value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrentProtocol() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrentProtocol() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ProtocolVersion ensureCurrentProtocol() => $_ensure(0);

  @$pb.TagNumber(2)
  $0.ProtocolVersionRange get acceptedProtocols => $_getN(1);
  @$pb.TagNumber(2)
  set acceptedProtocols($0.ProtocolVersionRange value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAcceptedProtocols() => $_has(1);
  @$pb.TagNumber(2)
  void clearAcceptedProtocols() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.ProtocolVersionRange ensureAcceptedProtocols() => $_ensure(1);

  @$pb.TagNumber(3)
  $core.String get schemaBuild => $_getSZ(2);
  @$pb.TagNumber(3)
  set schemaBuild($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchemaBuild() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaBuild() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get schemaSha256 => $_getSZ(3);
  @$pb.TagNumber(4)
  set schemaSha256($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchemaSha256() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchemaSha256() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get componentVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set componentVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasComponentVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearComponentVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  $0.ComponentRole get componentRole => $_getN(5);
  @$pb.TagNumber(6)
  set componentRole($0.ComponentRole value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasComponentRole() => $_has(5);
  @$pb.TagNumber(6)
  void clearComponentRole() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get capabilityRevision => $_getSZ(6);
  @$pb.TagNumber(7)
  set capabilityRevision($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCapabilityRevision() => $_has(6);
  @$pb.TagNumber(7)
  void clearCapabilityRevision() => $_clearField(7);

  @$pb.TagNumber(8)
  $0.AgentCapabilities get capabilities => $_getN(7);
  @$pb.TagNumber(8)
  set capabilities($0.AgentCapabilities value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCapabilities() => $_has(7);
  @$pb.TagNumber(8)
  void clearCapabilities() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.AgentCapabilities ensureCapabilities() => $_ensure(7);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get scopes => $_getList(8);
}

class HandshakeAccepted extends $pb.GeneratedMessage {
  factory HandshakeAccepted({
    $0.ProtocolVersion? selectedProtocol,
    $core.String? connectionId,
    $core.String? schemaBuild,
    $core.String? schemaSha256,
    $core.String? componentVersion,
    $0.ComponentRole? componentRole,
    $core.String? capabilityRevision,
    $0.AgentCapabilities? capabilities,
    $core.Iterable<$core.String>? scopes,
  }) {
    final result = create();
    if (selectedProtocol != null) result.selectedProtocol = selectedProtocol;
    if (connectionId != null) result.connectionId = connectionId;
    if (schemaBuild != null) result.schemaBuild = schemaBuild;
    if (schemaSha256 != null) result.schemaSha256 = schemaSha256;
    if (componentVersion != null) result.componentVersion = componentVersion;
    if (componentRole != null) result.componentRole = componentRole;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    if (capabilities != null) result.capabilities = capabilities;
    if (scopes != null) result.scopes.addAll(scopes);
    return result;
  }

  HandshakeAccepted._();

  factory HandshakeAccepted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HandshakeAccepted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HandshakeAccepted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOM<$0.ProtocolVersion>(1, _omitFieldNames ? '' : 'selectedProtocol',
        subBuilder: $0.ProtocolVersion.create)
    ..aOS(2, _omitFieldNames ? '' : 'connectionId')
    ..aOS(3, _omitFieldNames ? '' : 'schemaBuild')
    ..aOS(4, _omitFieldNames ? '' : 'schemaSha256')
    ..aOS(5, _omitFieldNames ? '' : 'componentVersion')
    ..aE<$0.ComponentRole>(6, _omitFieldNames ? '' : 'componentRole',
        enumValues: $0.ComponentRole.values)
    ..aOS(7, _omitFieldNames ? '' : 'capabilityRevision')
    ..aOM<$0.AgentCapabilities>(8, _omitFieldNames ? '' : 'capabilities',
        subBuilder: $0.AgentCapabilities.create)
    ..pPS(9, _omitFieldNames ? '' : 'scopes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HandshakeAccepted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HandshakeAccepted copyWith(void Function(HandshakeAccepted) updates) =>
      super.copyWith((message) => updates(message as HandshakeAccepted))
          as HandshakeAccepted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HandshakeAccepted create() => HandshakeAccepted._();
  @$core.override
  HandshakeAccepted createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HandshakeAccepted getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HandshakeAccepted>(create);
  static HandshakeAccepted? _defaultInstance;

  @$pb.TagNumber(1)
  $0.ProtocolVersion get selectedProtocol => $_getN(0);
  @$pb.TagNumber(1)
  set selectedProtocol($0.ProtocolVersion value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSelectedProtocol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSelectedProtocol() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.ProtocolVersion ensureSelectedProtocol() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get connectionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set connectionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConnectionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConnectionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get schemaBuild => $_getSZ(2);
  @$pb.TagNumber(3)
  set schemaBuild($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSchemaBuild() => $_has(2);
  @$pb.TagNumber(3)
  void clearSchemaBuild() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get schemaSha256 => $_getSZ(3);
  @$pb.TagNumber(4)
  set schemaSha256($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSchemaSha256() => $_has(3);
  @$pb.TagNumber(4)
  void clearSchemaSha256() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get componentVersion => $_getSZ(4);
  @$pb.TagNumber(5)
  set componentVersion($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasComponentVersion() => $_has(4);
  @$pb.TagNumber(5)
  void clearComponentVersion() => $_clearField(5);

  @$pb.TagNumber(6)
  $0.ComponentRole get componentRole => $_getN(5);
  @$pb.TagNumber(6)
  set componentRole($0.ComponentRole value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasComponentRole() => $_has(5);
  @$pb.TagNumber(6)
  void clearComponentRole() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get capabilityRevision => $_getSZ(6);
  @$pb.TagNumber(7)
  set capabilityRevision($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCapabilityRevision() => $_has(6);
  @$pb.TagNumber(7)
  void clearCapabilityRevision() => $_clearField(7);

  @$pb.TagNumber(8)
  $0.AgentCapabilities get capabilities => $_getN(7);
  @$pb.TagNumber(8)
  set capabilities($0.AgentCapabilities value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCapabilities() => $_has(7);
  @$pb.TagNumber(8)
  void clearCapabilities() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.AgentCapabilities ensureCapabilities() => $_ensure(7);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get scopes => $_getList(8);
}

class ProtocolError extends $pb.GeneratedMessage {
  factory ProtocolError({
    $core.String? code,
    $core.String? safeMessage,
    $0.ProtocolVersion? localProtocol,
    $0.ProtocolVersion? remoteProtocol,
    $core.bool? retryable,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (safeMessage != null) result.safeMessage = safeMessage;
    if (localProtocol != null) result.localProtocol = localProtocol;
    if (remoteProtocol != null) result.remoteProtocol = remoteProtocol;
    if (retryable != null) result.retryable = retryable;
    return result;
  }

  ProtocolError._();

  factory ProtocolError.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtocolError.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolError',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'safeMessage')
    ..aOM<$0.ProtocolVersion>(3, _omitFieldNames ? '' : 'localProtocol',
        subBuilder: $0.ProtocolVersion.create)
    ..aOM<$0.ProtocolVersion>(4, _omitFieldNames ? '' : 'remoteProtocol',
        subBuilder: $0.ProtocolVersion.create)
    ..aOB(5, _omitFieldNames ? '' : 'retryable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolError clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolError copyWith(void Function(ProtocolError) updates) =>
      super.copyWith((message) => updates(message as ProtocolError))
          as ProtocolError;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolError create() => ProtocolError._();
  @$core.override
  ProtocolError createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtocolError getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtocolError>(create);
  static ProtocolError? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get safeMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set safeMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSafeMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearSafeMessage() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.ProtocolVersion get localProtocol => $_getN(2);
  @$pb.TagNumber(3)
  set localProtocol($0.ProtocolVersion value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasLocalProtocol() => $_has(2);
  @$pb.TagNumber(3)
  void clearLocalProtocol() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.ProtocolVersion ensureLocalProtocol() => $_ensure(2);

  @$pb.TagNumber(4)
  $0.ProtocolVersion get remoteProtocol => $_getN(3);
  @$pb.TagNumber(4)
  set remoteProtocol($0.ProtocolVersion value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasRemoteProtocol() => $_has(3);
  @$pb.TagNumber(4)
  void clearRemoteProtocol() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.ProtocolVersion ensureRemoteProtocol() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.bool get retryable => $_getBF(4);
  @$pb.TagNumber(5)
  set retryable($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRetryable() => $_has(4);
  @$pb.TagNumber(5)
  void clearRetryable() => $_clearField(5);
}

class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat({
    $1.Timestamp? sentAt,
    $fixnum.Int64? lastReceivedSequence,
  }) {
    final result = create();
    if (sentAt != null) result.sentAt = sentAt;
    if (lastReceivedSequence != null)
      result.lastReceivedSequence = lastReceivedSequence;
    return result;
  }

  Heartbeat._();

  factory Heartbeat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Heartbeat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Heartbeat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOM<$1.Timestamp>(1, _omitFieldNames ? '' : 'sentAt',
        subBuilder: $1.Timestamp.create)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'lastReceivedSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Heartbeat copyWith(void Function(Heartbeat) updates) =>
      super.copyWith((message) => updates(message as Heartbeat)) as Heartbeat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Heartbeat create() => Heartbeat._();
  @$core.override
  Heartbeat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Heartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Heartbeat>(create);
  static Heartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $1.Timestamp get sentAt => $_getN(0);
  @$pb.TagNumber(1)
  set sentAt($1.Timestamp value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSentAt() => $_has(0);
  @$pb.TagNumber(1)
  void clearSentAt() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.Timestamp ensureSentAt() => $_ensure(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get lastReceivedSequence => $_getI64(1);
  @$pb.TagNumber(2)
  set lastReceivedSequence($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastReceivedSequence() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastReceivedSequence() => $_clearField(2);
}

class Ack extends $pb.GeneratedMessage {
  factory Ack({
    $core.String? conversationId,
    $fixnum.Int64? sequence,
    $core.String? eventId,
  }) {
    final result = create();
    if (conversationId != null) result.conversationId = conversationId;
    if (sequence != null) result.sequence = sequence;
    if (eventId != null) result.eventId = eventId;
    return result;
  }

  Ack._();

  factory Ack.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ack.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ack',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'conversationId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'sequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(3, _omitFieldNames ? '' : 'eventId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ack copyWith(void Function(Ack) updates) =>
      super.copyWith((message) => updates(message as Ack)) as Ack;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ack create() => Ack._();
  @$core.override
  Ack createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ack getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ack>(create);
  static Ack? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get conversationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conversationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConversationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConversationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get sequence => $_getI64(1);
  @$pb.TagNumber(2)
  set sequence($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSequence() => $_has(1);
  @$pb.TagNumber(2)
  void clearSequence() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get eventId => $_getSZ(2);
  @$pb.TagNumber(3)
  set eventId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEventId() => $_has(2);
  @$pb.TagNumber(3)
  void clearEventId() => $_clearField(3);
}

class SendRequest extends $pb.GeneratedMessage {
  factory SendRequest({
    $core.String? agentId,
    $core.String? nodeId,
    $core.String? sessionId,
    $core.String? confirmedText,
    $core.String? capabilityRevision,
  }) {
    final result = create();
    if (agentId != null) result.agentId = agentId;
    if (nodeId != null) result.nodeId = nodeId;
    if (sessionId != null) result.sessionId = sessionId;
    if (confirmedText != null) result.confirmedText = confirmedText;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    return result;
  }

  SendRequest._();

  factory SendRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SendRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'agentId')
    ..aOS(2, _omitFieldNames ? '' : 'nodeId')
    ..aOS(3, _omitFieldNames ? '' : 'sessionId')
    ..aOS(4, _omitFieldNames ? '' : 'confirmedText')
    ..aOS(5, _omitFieldNames ? '' : 'capabilityRevision')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendRequest copyWith(void Function(SendRequest) updates) =>
      super.copyWith((message) => updates(message as SendRequest))
          as SendRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SendRequest create() => SendRequest._();
  @$core.override
  SendRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SendRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendRequest>(create);
  static SendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agentId => $_getSZ(0);
  @$pb.TagNumber(1)
  set agentId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgentId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgentId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get nodeId => $_getSZ(1);
  @$pb.TagNumber(2)
  set nodeId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNodeId() => $_has(1);
  @$pb.TagNumber(2)
  void clearNodeId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sessionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get confirmedText => $_getSZ(3);
  @$pb.TagNumber(4)
  set confirmedText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConfirmedText() => $_has(3);
  @$pb.TagNumber(4)
  void clearConfirmedText() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get capabilityRevision => $_getSZ(4);
  @$pb.TagNumber(5)
  set capabilityRevision($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCapabilityRevision() => $_has(4);
  @$pb.TagNumber(5)
  void clearCapabilityRevision() => $_clearField(5);
}

class InterruptRequest extends $pb.GeneratedMessage {
  factory InterruptRequest({
    $core.String? requestId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  InterruptRequest._();

  factory InterruptRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InterruptRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InterruptRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InterruptRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InterruptRequest copyWith(void Function(InterruptRequest) updates) =>
      super.copyWith((message) => updates(message as InterruptRequest))
          as InterruptRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InterruptRequest create() => InterruptRequest._();
  @$core.override
  InterruptRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InterruptRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InterruptRequest>(create);
  static InterruptRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);
}

class ResolveApproval extends $pb.GeneratedMessage {
  factory ResolveApproval({
    $core.String? requestId,
    $core.String? approvalId,
    ApprovalDecision? decision,
    $core.String? operationSummarySha256,
    $0.DeviceSignature? deviceSignature,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (approvalId != null) result.approvalId = approvalId;
    if (decision != null) result.decision = decision;
    if (operationSummarySha256 != null)
      result.operationSummarySha256 = operationSummarySha256;
    if (deviceSignature != null) result.deviceSignature = deviceSignature;
    return result;
  }

  ResolveApproval._();

  factory ResolveApproval.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveApproval.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveApproval',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'approvalId')
    ..aE<ApprovalDecision>(3, _omitFieldNames ? '' : 'decision',
        enumValues: ApprovalDecision.values)
    ..aOS(4, _omitFieldNames ? '' : 'operationSummarySha256')
    ..aOM<$0.DeviceSignature>(5, _omitFieldNames ? '' : 'deviceSignature',
        subBuilder: $0.DeviceSignature.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveApproval clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveApproval copyWith(void Function(ResolveApproval) updates) =>
      super.copyWith((message) => updates(message as ResolveApproval))
          as ResolveApproval;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResolveApproval create() => ResolveApproval._();
  @$core.override
  ResolveApproval createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveApproval getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveApproval>(create);
  static ResolveApproval? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get approvalId => $_getSZ(1);
  @$pb.TagNumber(2)
  set approvalId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasApprovalId() => $_has(1);
  @$pb.TagNumber(2)
  void clearApprovalId() => $_clearField(2);

  @$pb.TagNumber(3)
  ApprovalDecision get decision => $_getN(2);
  @$pb.TagNumber(3)
  set decision(ApprovalDecision value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasDecision() => $_has(2);
  @$pb.TagNumber(3)
  void clearDecision() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get operationSummarySha256 => $_getSZ(3);
  @$pb.TagNumber(4)
  set operationSummarySha256($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOperationSummarySha256() => $_has(3);
  @$pb.TagNumber(4)
  void clearOperationSummarySha256() => $_clearField(4);

  @$pb.TagNumber(5)
  $0.DeviceSignature get deviceSignature => $_getN(4);
  @$pb.TagNumber(5)
  set deviceSignature($0.DeviceSignature value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDeviceSignature() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeviceSignature() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.DeviceSignature ensureDeviceSignature() => $_ensure(4);
}

class ResolveClarification extends $pb.GeneratedMessage {
  factory ResolveClarification({
    $core.String? requestId,
    $core.String? clarificationId,
    $core.String? confirmedText,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (clarificationId != null) result.clarificationId = clarificationId;
    if (confirmedText != null) result.confirmedText = confirmedText;
    return result;
  }

  ResolveClarification._();

  factory ResolveClarification.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveClarification.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveClarification',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'clarificationId')
    ..aOS(3, _omitFieldNames ? '' : 'confirmedText')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveClarification clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveClarification copyWith(void Function(ResolveClarification) updates) =>
      super.copyWith((message) => updates(message as ResolveClarification))
          as ResolveClarification;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResolveClarification create() => ResolveClarification._();
  @$core.override
  ResolveClarification createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveClarification getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveClarification>(create);
  static ResolveClarification? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get clarificationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set clarificationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasClarificationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearClarificationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get confirmedText => $_getSZ(2);
  @$pb.TagNumber(3)
  set confirmedText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConfirmedText() => $_has(2);
  @$pb.TagNumber(3)
  void clearConfirmedText() => $_clearField(3);
}

class AcquireControlLease extends $pb.GeneratedMessage {
  factory AcquireControlLease({
    $core.String? expectedLeaseId,
    $fixnum.Int64? expectedRevision,
    $core.bool? explicitTakeover,
  }) {
    final result = create();
    if (expectedLeaseId != null) result.expectedLeaseId = expectedLeaseId;
    if (expectedRevision != null) result.expectedRevision = expectedRevision;
    if (explicitTakeover != null) result.explicitTakeover = explicitTakeover;
    return result;
  }

  AcquireControlLease._();

  factory AcquireControlLease.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AcquireControlLease.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AcquireControlLease',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'expectedLeaseId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'expectedRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOB(3, _omitFieldNames ? '' : 'explicitTakeover')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcquireControlLease clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AcquireControlLease copyWith(void Function(AcquireControlLease) updates) =>
      super.copyWith((message) => updates(message as AcquireControlLease))
          as AcquireControlLease;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AcquireControlLease create() => AcquireControlLease._();
  @$core.override
  AcquireControlLease createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AcquireControlLease getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AcquireControlLease>(create);
  static AcquireControlLease? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get expectedLeaseId => $_getSZ(0);
  @$pb.TagNumber(1)
  set expectedLeaseId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExpectedLeaseId() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpectedLeaseId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expectedRevision => $_getI64(1);
  @$pb.TagNumber(2)
  set expectedRevision($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpectedRevision() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpectedRevision() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get explicitTakeover => $_getBF(2);
  @$pb.TagNumber(3)
  set explicitTakeover($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExplicitTakeover() => $_has(2);
  @$pb.TagNumber(3)
  void clearExplicitTakeover() => $_clearField(3);
}

class RenewControlLease extends $pb.GeneratedMessage {
  factory RenewControlLease({
    $core.String? leaseId,
    $fixnum.Int64? expectedRevision,
  }) {
    final result = create();
    if (leaseId != null) result.leaseId = leaseId;
    if (expectedRevision != null) result.expectedRevision = expectedRevision;
    return result;
  }

  RenewControlLease._();

  factory RenewControlLease.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RenewControlLease.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenewControlLease',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'leaseId')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'expectedRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenewControlLease clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenewControlLease copyWith(void Function(RenewControlLease) updates) =>
      super.copyWith((message) => updates(message as RenewControlLease))
          as RenewControlLease;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RenewControlLease create() => RenewControlLease._();
  @$core.override
  RenewControlLease createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RenewControlLease getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenewControlLease>(create);
  static RenewControlLease? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get leaseId => $_getSZ(0);
  @$pb.TagNumber(1)
  set leaseId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLeaseId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLeaseId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expectedRevision => $_getI64(1);
  @$pb.TagNumber(2)
  set expectedRevision($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpectedRevision() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpectedRevision() => $_clearField(2);
}

class ReplayEvents extends $pb.GeneratedMessage {
  factory ReplayEvents({
    $fixnum.Int64? afterSequence,
    $core.int? maximumEvents,
  }) {
    final result = create();
    if (afterSequence != null) result.afterSequence = afterSequence;
    if (maximumEvents != null) result.maximumEvents = maximumEvents;
    return result;
  }

  ReplayEvents._();

  factory ReplayEvents.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReplayEvents.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplayEvents',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..a<$fixnum.Int64>(
        1, _omitFieldNames ? '' : 'afterSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(2, _omitFieldNames ? '' : 'maximumEvents',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplayEvents clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplayEvents copyWith(void Function(ReplayEvents) updates) =>
      super.copyWith((message) => updates(message as ReplayEvents))
          as ReplayEvents;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReplayEvents create() => ReplayEvents._();
  @$core.override
  ReplayEvents createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReplayEvents getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplayEvents>(create);
  static ReplayEvents? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get afterSequence => $_getI64(0);
  @$pb.TagNumber(1)
  set afterSequence($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAfterSequence() => $_has(0);
  @$pb.TagNumber(1)
  void clearAfterSequence() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get maximumEvents => $_getIZ(1);
  @$pb.TagNumber(2)
  set maximumEvents($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMaximumEvents() => $_has(1);
  @$pb.TagNumber(2)
  void clearMaximumEvents() => $_clearField(2);
}

class GetRequest extends $pb.GeneratedMessage {
  factory GetRequest({
    $core.String? requestId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    return result;
  }

  GetRequest._();

  factory GetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRequest copyWith(void Function(GetRequest) updates) =>
      super.copyWith((message) => updates(message as GetRequest)) as GetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetRequest create() => GetRequest._();
  @$core.override
  GetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetRequest>(create);
  static GetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);
}

class ListDirectory extends $pb.GeneratedMessage {
  factory ListDirectory() => create();

  ListDirectory._();

  factory ListDirectory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListDirectory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListDirectory',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDirectory clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListDirectory copyWith(void Function(ListDirectory) updates) =>
      super.copyWith((message) => updates(message as ListDirectory))
          as ListDirectory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListDirectory create() => ListDirectory._();
  @$core.override
  ListDirectory createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListDirectory getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListDirectory>(create);
  static ListDirectory? _defaultInstance;
}

class CreateConversation extends $pb.GeneratedMessage {
  factory CreateConversation({
    $core.String? nodeId,
    $core.String? agentId,
    $core.String? capabilityRevision,
    $core.String? sessionId,
    $core.String? title,
  }) {
    final result = create();
    if (nodeId != null) result.nodeId = nodeId;
    if (agentId != null) result.agentId = agentId;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    if (sessionId != null) result.sessionId = sessionId;
    if (title != null) result.title = title;
    return result;
  }

  CreateConversation._();

  factory CreateConversation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateConversation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateConversation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'nodeId')
    ..aOS(2, _omitFieldNames ? '' : 'agentId')
    ..aOS(3, _omitFieldNames ? '' : 'capabilityRevision')
    ..aOS(4, _omitFieldNames ? '' : 'sessionId')
    ..aOS(5, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateConversation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateConversation copyWith(void Function(CreateConversation) updates) =>
      super.copyWith((message) => updates(message as CreateConversation))
          as CreateConversation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateConversation create() => CreateConversation._();
  @$core.override
  CreateConversation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateConversation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateConversation>(create);
  static CreateConversation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get nodeId => $_getSZ(0);
  @$pb.TagNumber(1)
  set nodeId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNodeId() => $_has(0);
  @$pb.TagNumber(1)
  void clearNodeId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get agentId => $_getSZ(1);
  @$pb.TagNumber(2)
  set agentId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgentId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgentId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get capabilityRevision => $_getSZ(2);
  @$pb.TagNumber(3)
  set capabilityRevision($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCapabilityRevision() => $_has(2);
  @$pb.TagNumber(3)
  void clearCapabilityRevision() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get sessionId => $_getSZ(3);
  @$pb.TagNumber(4)
  set sessionId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionId() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get title => $_getSZ(4);
  @$pb.TagNumber(5)
  set title($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTitle() => $_has(4);
  @$pb.TagNumber(5)
  void clearTitle() => $_clearField(5);
}

enum ClientCommand_Command {
  send,
  interrupt,
  resolveApproval,
  resolveClarification,
  acquireLease,
  renewLease,
  replay,
  getRequest,
  listDirectory,
  createConversation,
  notSet
}

class ClientCommand extends $pb.GeneratedMessage {
  factory ClientCommand({
    $core.String? commandId,
    $core.String? idempotencyKey,
    $core.String? conversationId,
    $core.String? leaseId,
    $fixnum.Int64? leaseRevision,
    $core.String? requestId,
    SendRequest? send,
    InterruptRequest? interrupt,
    ResolveApproval? resolveApproval,
    ResolveClarification? resolveClarification,
    AcquireControlLease? acquireLease,
    RenewControlLease? renewLease,
    ReplayEvents? replay,
    GetRequest? getRequest,
    ListDirectory? listDirectory,
    CreateConversation? createConversation,
  }) {
    final result = create();
    if (commandId != null) result.commandId = commandId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (conversationId != null) result.conversationId = conversationId;
    if (leaseId != null) result.leaseId = leaseId;
    if (leaseRevision != null) result.leaseRevision = leaseRevision;
    if (requestId != null) result.requestId = requestId;
    if (send != null) result.send = send;
    if (interrupt != null) result.interrupt = interrupt;
    if (resolveApproval != null) result.resolveApproval = resolveApproval;
    if (resolveClarification != null)
      result.resolveClarification = resolveClarification;
    if (acquireLease != null) result.acquireLease = acquireLease;
    if (renewLease != null) result.renewLease = renewLease;
    if (replay != null) result.replay = replay;
    if (getRequest != null) result.getRequest = getRequest;
    if (listDirectory != null) result.listDirectory = listDirectory;
    if (createConversation != null)
      result.createConversation = createConversation;
    return result;
  }

  ClientCommand._();

  factory ClientCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClientCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, ClientCommand_Command>
      _ClientCommand_CommandByTag = {
    10: ClientCommand_Command.send,
    11: ClientCommand_Command.interrupt,
    12: ClientCommand_Command.resolveApproval,
    13: ClientCommand_Command.resolveClarification,
    14: ClientCommand_Command.acquireLease,
    15: ClientCommand_Command.renewLease,
    16: ClientCommand_Command.replay,
    17: ClientCommand_Command.getRequest,
    18: ClientCommand_Command.listDirectory,
    19: ClientCommand_Command.createConversation,
    0: ClientCommand_Command.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClientCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17, 18, 19])
    ..aOS(1, _omitFieldNames ? '' : 'commandId')
    ..aOS(2, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(3, _omitFieldNames ? '' : 'conversationId')
    ..aOS(4, _omitFieldNames ? '' : 'leaseId')
    ..a<$fixnum.Int64>(
        5, _omitFieldNames ? '' : 'leaseRevision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOS(6, _omitFieldNames ? '' : 'requestId')
    ..aOM<SendRequest>(10, _omitFieldNames ? '' : 'send',
        subBuilder: SendRequest.create)
    ..aOM<InterruptRequest>(11, _omitFieldNames ? '' : 'interrupt',
        subBuilder: InterruptRequest.create)
    ..aOM<ResolveApproval>(12, _omitFieldNames ? '' : 'resolveApproval',
        subBuilder: ResolveApproval.create)
    ..aOM<ResolveClarification>(
        13, _omitFieldNames ? '' : 'resolveClarification',
        subBuilder: ResolveClarification.create)
    ..aOM<AcquireControlLease>(14, _omitFieldNames ? '' : 'acquireLease',
        subBuilder: AcquireControlLease.create)
    ..aOM<RenewControlLease>(15, _omitFieldNames ? '' : 'renewLease',
        subBuilder: RenewControlLease.create)
    ..aOM<ReplayEvents>(16, _omitFieldNames ? '' : 'replay',
        subBuilder: ReplayEvents.create)
    ..aOM<GetRequest>(17, _omitFieldNames ? '' : 'getRequest',
        subBuilder: GetRequest.create)
    ..aOM<ListDirectory>(18, _omitFieldNames ? '' : 'listDirectory',
        subBuilder: ListDirectory.create)
    ..aOM<CreateConversation>(19, _omitFieldNames ? '' : 'createConversation',
        subBuilder: CreateConversation.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClientCommand copyWith(void Function(ClientCommand) updates) =>
      super.copyWith((message) => updates(message as ClientCommand))
          as ClientCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClientCommand create() => ClientCommand._();
  @$core.override
  ClientCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClientCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClientCommand>(create);
  static ClientCommand? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  ClientCommand_Command whichCommand() =>
      _ClientCommand_CommandByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  @$pb.TagNumber(18)
  @$pb.TagNumber(19)
  void clearCommand() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get commandId => $_getSZ(0);
  @$pb.TagNumber(1)
  set commandId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommandId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommandId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get idempotencyKey => $_getSZ(1);
  @$pb.TagNumber(2)
  set idempotencyKey($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIdempotencyKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearIdempotencyKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get conversationId => $_getSZ(2);
  @$pb.TagNumber(3)
  set conversationId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConversationId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConversationId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get leaseId => $_getSZ(3);
  @$pb.TagNumber(4)
  set leaseId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLeaseId() => $_has(3);
  @$pb.TagNumber(4)
  void clearLeaseId() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get leaseRevision => $_getI64(4);
  @$pb.TagNumber(5)
  set leaseRevision($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLeaseRevision() => $_has(4);
  @$pb.TagNumber(5)
  void clearLeaseRevision() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get requestId => $_getSZ(5);
  @$pb.TagNumber(6)
  set requestId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRequestId() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequestId() => $_clearField(6);

  @$pb.TagNumber(10)
  SendRequest get send => $_getN(6);
  @$pb.TagNumber(10)
  set send(SendRequest value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasSend() => $_has(6);
  @$pb.TagNumber(10)
  void clearSend() => $_clearField(10);
  @$pb.TagNumber(10)
  SendRequest ensureSend() => $_ensure(6);

  @$pb.TagNumber(11)
  InterruptRequest get interrupt => $_getN(7);
  @$pb.TagNumber(11)
  set interrupt(InterruptRequest value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasInterrupt() => $_has(7);
  @$pb.TagNumber(11)
  void clearInterrupt() => $_clearField(11);
  @$pb.TagNumber(11)
  InterruptRequest ensureInterrupt() => $_ensure(7);

  @$pb.TagNumber(12)
  ResolveApproval get resolveApproval => $_getN(8);
  @$pb.TagNumber(12)
  set resolveApproval(ResolveApproval value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasResolveApproval() => $_has(8);
  @$pb.TagNumber(12)
  void clearResolveApproval() => $_clearField(12);
  @$pb.TagNumber(12)
  ResolveApproval ensureResolveApproval() => $_ensure(8);

  @$pb.TagNumber(13)
  ResolveClarification get resolveClarification => $_getN(9);
  @$pb.TagNumber(13)
  set resolveClarification(ResolveClarification value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasResolveClarification() => $_has(9);
  @$pb.TagNumber(13)
  void clearResolveClarification() => $_clearField(13);
  @$pb.TagNumber(13)
  ResolveClarification ensureResolveClarification() => $_ensure(9);

  @$pb.TagNumber(14)
  AcquireControlLease get acquireLease => $_getN(10);
  @$pb.TagNumber(14)
  set acquireLease(AcquireControlLease value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasAcquireLease() => $_has(10);
  @$pb.TagNumber(14)
  void clearAcquireLease() => $_clearField(14);
  @$pb.TagNumber(14)
  AcquireControlLease ensureAcquireLease() => $_ensure(10);

  @$pb.TagNumber(15)
  RenewControlLease get renewLease => $_getN(11);
  @$pb.TagNumber(15)
  set renewLease(RenewControlLease value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasRenewLease() => $_has(11);
  @$pb.TagNumber(15)
  void clearRenewLease() => $_clearField(15);
  @$pb.TagNumber(15)
  RenewControlLease ensureRenewLease() => $_ensure(11);

  @$pb.TagNumber(16)
  ReplayEvents get replay => $_getN(12);
  @$pb.TagNumber(16)
  set replay(ReplayEvents value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasReplay() => $_has(12);
  @$pb.TagNumber(16)
  void clearReplay() => $_clearField(16);
  @$pb.TagNumber(16)
  ReplayEvents ensureReplay() => $_ensure(12);

  @$pb.TagNumber(17)
  GetRequest get getRequest => $_getN(13);
  @$pb.TagNumber(17)
  set getRequest(GetRequest value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasGetRequest() => $_has(13);
  @$pb.TagNumber(17)
  void clearGetRequest() => $_clearField(17);
  @$pb.TagNumber(17)
  GetRequest ensureGetRequest() => $_ensure(13);

  @$pb.TagNumber(18)
  ListDirectory get listDirectory => $_getN(14);
  @$pb.TagNumber(18)
  set listDirectory(ListDirectory value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasListDirectory() => $_has(14);
  @$pb.TagNumber(18)
  void clearListDirectory() => $_clearField(18);
  @$pb.TagNumber(18)
  ListDirectory ensureListDirectory() => $_ensure(14);

  @$pb.TagNumber(19)
  CreateConversation get createConversation => $_getN(15);
  @$pb.TagNumber(19)
  set createConversation(CreateConversation value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasCreateConversation() => $_has(15);
  @$pb.TagNumber(19)
  void clearCreateConversation() => $_clearField(19);
  @$pb.TagNumber(19)
  CreateConversation ensureCreateConversation() => $_ensure(15);
}

class RequestStatus extends $pb.GeneratedMessage {
  factory RequestStatus({
    $core.String? requestId,
    $core.String? conversationId,
    $core.String? state,
    $core.String? nodeId,
    $core.String? agentId,
    $core.String? capabilityRevision,
    $fixnum.Int64? acceptedSequence,
    $0.StageFailure? failure,
    $core.String? originDeviceId,
    $core.String? sessionId,
  }) {
    final result = create();
    if (requestId != null) result.requestId = requestId;
    if (conversationId != null) result.conversationId = conversationId;
    if (state != null) result.state = state;
    if (nodeId != null) result.nodeId = nodeId;
    if (agentId != null) result.agentId = agentId;
    if (capabilityRevision != null)
      result.capabilityRevision = capabilityRevision;
    if (acceptedSequence != null) result.acceptedSequence = acceptedSequence;
    if (failure != null) result.failure = failure;
    if (originDeviceId != null) result.originDeviceId = originDeviceId;
    if (sessionId != null) result.sessionId = sessionId;
    return result;
  }

  RequestStatus._();

  factory RequestStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'requestId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOS(3, _omitFieldNames ? '' : 'state')
    ..aOS(4, _omitFieldNames ? '' : 'nodeId')
    ..aOS(5, _omitFieldNames ? '' : 'agentId')
    ..aOS(6, _omitFieldNames ? '' : 'capabilityRevision')
    ..a<$fixnum.Int64>(
        7, _omitFieldNames ? '' : 'acceptedSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<$0.StageFailure>(8, _omitFieldNames ? '' : 'failure',
        subBuilder: $0.StageFailure.create)
    ..aOS(9, _omitFieldNames ? '' : 'originDeviceId')
    ..aOS(10, _omitFieldNames ? '' : 'sessionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestStatus copyWith(void Function(RequestStatus) updates) =>
      super.copyWith((message) => updates(message as RequestStatus))
          as RequestStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestStatus create() => RequestStatus._();
  @$core.override
  RequestStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RequestStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestStatus>(create);
  static RequestStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get requestId => $_getSZ(0);
  @$pb.TagNumber(1)
  set requestId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRequestId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRequestId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get state => $_getSZ(2);
  @$pb.TagNumber(3)
  set state($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get nodeId => $_getSZ(3);
  @$pb.TagNumber(4)
  set nodeId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNodeId() => $_has(3);
  @$pb.TagNumber(4)
  void clearNodeId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get agentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set agentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAgentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearAgentId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get capabilityRevision => $_getSZ(5);
  @$pb.TagNumber(6)
  set capabilityRevision($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCapabilityRevision() => $_has(5);
  @$pb.TagNumber(6)
  void clearCapabilityRevision() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get acceptedSequence => $_getI64(6);
  @$pb.TagNumber(7)
  set acceptedSequence($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAcceptedSequence() => $_has(6);
  @$pb.TagNumber(7)
  void clearAcceptedSequence() => $_clearField(7);

  @$pb.TagNumber(8)
  $0.StageFailure get failure => $_getN(7);
  @$pb.TagNumber(8)
  set failure($0.StageFailure value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasFailure() => $_has(7);
  @$pb.TagNumber(8)
  void clearFailure() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.StageFailure ensureFailure() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get originDeviceId => $_getSZ(8);
  @$pb.TagNumber(9)
  set originDeviceId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOriginDeviceId() => $_has(8);
  @$pb.TagNumber(9)
  void clearOriginDeviceId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get sessionId => $_getSZ(9);
  @$pb.TagNumber(10)
  set sessionId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSessionId() => $_has(9);
  @$pb.TagNumber(10)
  void clearSessionId() => $_clearField(10);
}

class ReplayCompleted extends $pb.GeneratedMessage {
  factory ReplayCompleted({
    $core.String? commandId,
    $core.String? conversationId,
    $fixnum.Int64? afterSequence,
    $fixnum.Int64? throughSequence,
    $core.int? eventCount,
    $core.bool? mayHaveMore,
  }) {
    final result = create();
    if (commandId != null) result.commandId = commandId;
    if (conversationId != null) result.conversationId = conversationId;
    if (afterSequence != null) result.afterSequence = afterSequence;
    if (throughSequence != null) result.throughSequence = throughSequence;
    if (eventCount != null) result.eventCount = eventCount;
    if (mayHaveMore != null) result.mayHaveMore = mayHaveMore;
    return result;
  }

  ReplayCompleted._();

  factory ReplayCompleted.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReplayCompleted.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplayCompleted',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'commandId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..a<$fixnum.Int64>(
        3, _omitFieldNames ? '' : 'afterSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'throughSequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(5, _omitFieldNames ? '' : 'eventCount', fieldType: $pb.PbFieldType.OU3)
    ..aOB(6, _omitFieldNames ? '' : 'mayHaveMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplayCompleted clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplayCompleted copyWith(void Function(ReplayCompleted) updates) =>
      super.copyWith((message) => updates(message as ReplayCompleted))
          as ReplayCompleted;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReplayCompleted create() => ReplayCompleted._();
  @$core.override
  ReplayCompleted createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReplayCompleted getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplayCompleted>(create);
  static ReplayCompleted? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get commandId => $_getSZ(0);
  @$pb.TagNumber(1)
  set commandId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommandId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommandId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get afterSequence => $_getI64(2);
  @$pb.TagNumber(3)
  set afterSequence($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAfterSequence() => $_has(2);
  @$pb.TagNumber(3)
  void clearAfterSequence() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get throughSequence => $_getI64(3);
  @$pb.TagNumber(4)
  set throughSequence($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasThroughSequence() => $_has(3);
  @$pb.TagNumber(4)
  void clearThroughSequence() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get eventCount => $_getIZ(4);
  @$pb.TagNumber(5)
  set eventCount($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEventCount() => $_has(4);
  @$pb.TagNumber(5)
  void clearEventCount() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get mayHaveMore => $_getBF(5);
  @$pb.TagNumber(6)
  set mayHaveMore($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMayHaveMore() => $_has(5);
  @$pb.TagNumber(6)
  void clearMayHaveMore() => $_clearField(6);
}

class ControlLease extends $pb.GeneratedMessage {
  factory ControlLease({
    $core.String? leaseId,
    $core.String? conversationId,
    $core.String? deviceId,
    $fixnum.Int64? revision,
    $1.Timestamp? expiresAt,
  }) {
    final result = create();
    if (leaseId != null) result.leaseId = leaseId;
    if (conversationId != null) result.conversationId = conversationId;
    if (deviceId != null) result.deviceId = deviceId;
    if (revision != null) result.revision = revision;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  ControlLease._();

  factory ControlLease.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ControlLease.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ControlLease',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'leaseId')
    ..aOS(2, _omitFieldNames ? '' : 'conversationId')
    ..aOS(3, _omitFieldNames ? '' : 'deviceId')
    ..a<$fixnum.Int64>(
        4, _omitFieldNames ? '' : 'revision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<$1.Timestamp>(5, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $1.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlLease clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ControlLease copyWith(void Function(ControlLease) updates) =>
      super.copyWith((message) => updates(message as ControlLease))
          as ControlLease;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ControlLease create() => ControlLease._();
  @$core.override
  ControlLease createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ControlLease getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ControlLease>(create);
  static ControlLease? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get leaseId => $_getSZ(0);
  @$pb.TagNumber(1)
  set leaseId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLeaseId() => $_has(0);
  @$pb.TagNumber(1)
  void clearLeaseId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get conversationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set conversationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConversationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConversationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get deviceId => $_getSZ(2);
  @$pb.TagNumber(3)
  set deviceId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDeviceId() => $_has(2);
  @$pb.TagNumber(3)
  void clearDeviceId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get revision => $_getI64(3);
  @$pb.TagNumber(4)
  set revision($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRevision() => $_has(3);
  @$pb.TagNumber(4)
  void clearRevision() => $_clearField(4);

  @$pb.TagNumber(5)
  $1.Timestamp get expiresAt => $_getN(4);
  @$pb.TagNumber(5)
  set expiresAt($1.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasExpiresAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearExpiresAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $1.Timestamp ensureExpiresAt() => $_ensure(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
