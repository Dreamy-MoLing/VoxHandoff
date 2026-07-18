// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/event.proto.

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
    as $0;

import 'common.pb.dart' as $1;
import 'event.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'event.pbenum.dart';

class ConnectionEvent extends $pb.GeneratedMessage {
  factory ConnectionEvent({
    $core.String? safeMessage,
  }) {
    final result = create();
    if (safeMessage != null) result.safeMessage = safeMessage;
    return result;
  }

  ConnectionEvent._();

  factory ConnectionEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConnectionEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConnectionEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'safeMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConnectionEvent copyWith(void Function(ConnectionEvent) updates) =>
      super.copyWith((message) => updates(message as ConnectionEvent))
          as ConnectionEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConnectionEvent create() => ConnectionEvent._();
  @$core.override
  ConnectionEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConnectionEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConnectionEvent>(create);
  static ConnectionEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get safeMessage => $_getSZ(0);
  @$pb.TagNumber(1)
  set safeMessage($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSafeMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearSafeMessage() => $_clearField(1);
}

class RequestProgressEvent extends $pb.GeneratedMessage {
  factory RequestProgressEvent({
    $core.String? safeMessage,
  }) {
    final result = create();
    if (safeMessage != null) result.safeMessage = safeMessage;
    return result;
  }

  RequestProgressEvent._();

  factory RequestProgressEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestProgressEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestProgressEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'safeMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestProgressEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestProgressEvent copyWith(void Function(RequestProgressEvent) updates) =>
      super.copyWith((message) => updates(message as RequestProgressEvent))
          as RequestProgressEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestProgressEvent create() => RequestProgressEvent._();
  @$core.override
  RequestProgressEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RequestProgressEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestProgressEvent>(create);
  static RequestProgressEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get safeMessage => $_getSZ(0);
  @$pb.TagNumber(1)
  set safeMessage($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSafeMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearSafeMessage() => $_clearField(1);
}

class MessageEvent extends $pb.GeneratedMessage {
  factory MessageEvent({
    $core.String? text,
    $fixnum.Int64? revision,
  }) {
    final result = create();
    if (text != null) result.text = text;
    if (revision != null) result.revision = revision;
    return result;
  }

  MessageEvent._();

  factory MessageEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MessageEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MessageEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'revision', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MessageEvent copyWith(void Function(MessageEvent) updates) =>
      super.copyWith((message) => updates(message as MessageEvent))
          as MessageEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MessageEvent create() => MessageEvent._();
  @$core.override
  MessageEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MessageEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MessageEvent>(create);
  static MessageEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get revision => $_getI64(1);
  @$pb.TagNumber(2)
  set revision($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRevision() => $_has(1);
  @$pb.TagNumber(2)
  void clearRevision() => $_clearField(2);
}

class ToolEvent extends $pb.GeneratedMessage {
  factory ToolEvent({
    $core.String? toolName,
    $core.String? stage,
    $core.String? safeSummary,
  }) {
    final result = create();
    if (toolName != null) result.toolName = toolName;
    if (stage != null) result.stage = stage;
    if (safeSummary != null) result.safeSummary = safeSummary;
    return result;
  }

  ToolEvent._();

  factory ToolEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ToolEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ToolEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'toolName')
    ..aOS(2, _omitFieldNames ? '' : 'stage')
    ..aOS(3, _omitFieldNames ? '' : 'safeSummary')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ToolEvent copyWith(void Function(ToolEvent) updates) =>
      super.copyWith((message) => updates(message as ToolEvent)) as ToolEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ToolEvent create() => ToolEvent._();
  @$core.override
  ToolEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ToolEvent getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ToolEvent>(create);
  static ToolEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get toolName => $_getSZ(0);
  @$pb.TagNumber(1)
  set toolName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToolName() => $_has(0);
  @$pb.TagNumber(1)
  void clearToolName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get stage => $_getSZ(1);
  @$pb.TagNumber(2)
  set stage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStage() => $_has(1);
  @$pb.TagNumber(2)
  void clearStage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get safeSummary => $_getSZ(2);
  @$pb.TagNumber(3)
  set safeSummary($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSafeSummary() => $_has(2);
  @$pb.TagNumber(3)
  void clearSafeSummary() => $_clearField(3);
}

class ApprovalEvent extends $pb.GeneratedMessage {
  factory ApprovalEvent({
    $core.String? approvalId,
    $core.String? safeSummary,
    $core.String? operationSummarySha256,
    $0.Timestamp? expiresAt,
  }) {
    final result = create();
    if (approvalId != null) result.approvalId = approvalId;
    if (safeSummary != null) result.safeSummary = safeSummary;
    if (operationSummarySha256 != null)
      result.operationSummarySha256 = operationSummarySha256;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  ApprovalEvent._();

  factory ApprovalEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ApprovalEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ApprovalEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'approvalId')
    ..aOS(2, _omitFieldNames ? '' : 'safeSummary')
    ..aOS(3, _omitFieldNames ? '' : 'operationSummarySha256')
    ..aOM<$0.Timestamp>(4, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ApprovalEvent copyWith(void Function(ApprovalEvent) updates) =>
      super.copyWith((message) => updates(message as ApprovalEvent))
          as ApprovalEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ApprovalEvent create() => ApprovalEvent._();
  @$core.override
  ApprovalEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ApprovalEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ApprovalEvent>(create);
  static ApprovalEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get approvalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set approvalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApprovalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearApprovalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get safeSummary => $_getSZ(1);
  @$pb.TagNumber(2)
  set safeSummary($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSafeSummary() => $_has(1);
  @$pb.TagNumber(2)
  void clearSafeSummary() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get operationSummarySha256 => $_getSZ(2);
  @$pb.TagNumber(3)
  set operationSummarySha256($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOperationSummarySha256() => $_has(2);
  @$pb.TagNumber(3)
  void clearOperationSummarySha256() => $_clearField(3);

  @$pb.TagNumber(4)
  $0.Timestamp get expiresAt => $_getN(3);
  @$pb.TagNumber(4)
  set expiresAt($0.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresAt() => $_clearField(4);
  @$pb.TagNumber(4)
  $0.Timestamp ensureExpiresAt() => $_ensure(3);
}

class ClarificationEvent extends $pb.GeneratedMessage {
  factory ClarificationEvent({
    $core.String? clarificationId,
    $core.String? safePrompt,
    $0.Timestamp? expiresAt,
  }) {
    final result = create();
    if (clarificationId != null) result.clarificationId = clarificationId;
    if (safePrompt != null) result.safePrompt = safePrompt;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  ClarificationEvent._();

  factory ClarificationEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ClarificationEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClarificationEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'clarificationId')
    ..aOS(2, _omitFieldNames ? '' : 'safePrompt')
    ..aOM<$0.Timestamp>(3, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClarificationEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClarificationEvent copyWith(void Function(ClarificationEvent) updates) =>
      super.copyWith((message) => updates(message as ClarificationEvent))
          as ClarificationEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ClarificationEvent create() => ClarificationEvent._();
  @$core.override
  ClarificationEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ClarificationEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClarificationEvent>(create);
  static ClarificationEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get clarificationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set clarificationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasClarificationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearClarificationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get safePrompt => $_getSZ(1);
  @$pb.TagNumber(2)
  set safePrompt($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSafePrompt() => $_has(1);
  @$pb.TagNumber(2)
  void clearSafePrompt() => $_clearField(2);

  @$pb.TagNumber(3)
  $0.Timestamp get expiresAt => $_getN(2);
  @$pb.TagNumber(3)
  set expiresAt($0.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasExpiresAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearExpiresAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $0.Timestamp ensureExpiresAt() => $_ensure(2);
}

class RequestTerminalEvent extends $pb.GeneratedMessage {
  factory RequestTerminalEvent({
    $1.StageFailure? failure,
  }) {
    final result = create();
    if (failure != null) result.failure = failure;
    return result;
  }

  RequestTerminalEvent._();

  factory RequestTerminalEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RequestTerminalEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RequestTerminalEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOM<$1.StageFailure>(1, _omitFieldNames ? '' : 'failure',
        subBuilder: $1.StageFailure.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestTerminalEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RequestTerminalEvent copyWith(void Function(RequestTerminalEvent) updates) =>
      super.copyWith((message) => updates(message as RequestTerminalEvent))
          as RequestTerminalEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RequestTerminalEvent create() => RequestTerminalEvent._();
  @$core.override
  RequestTerminalEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RequestTerminalEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RequestTerminalEvent>(create);
  static RequestTerminalEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $1.StageFailure get failure => $_getN(0);
  @$pb.TagNumber(1)
  set failure($1.StageFailure value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFailure() => $_has(0);
  @$pb.TagNumber(1)
  void clearFailure() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.StageFailure ensureFailure() => $_ensure(0);
}

class UnsupportedEvent extends $pb.GeneratedMessage {
  factory UnsupportedEvent({
    $core.int? nativeTypeNumber,
    $core.String? safeMessage,
  }) {
    final result = create();
    if (nativeTypeNumber != null) result.nativeTypeNumber = nativeTypeNumber;
    if (safeMessage != null) result.safeMessage = safeMessage;
    return result;
  }

  UnsupportedEvent._();

  factory UnsupportedEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UnsupportedEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnsupportedEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'nativeTypeNumber',
        fieldType: $pb.PbFieldType.OU3)
    ..aOS(2, _omitFieldNames ? '' : 'safeMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnsupportedEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnsupportedEvent copyWith(void Function(UnsupportedEvent) updates) =>
      super.copyWith((message) => updates(message as UnsupportedEvent))
          as UnsupportedEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UnsupportedEvent create() => UnsupportedEvent._();
  @$core.override
  UnsupportedEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UnsupportedEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnsupportedEvent>(create);
  static UnsupportedEvent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get nativeTypeNumber => $_getIZ(0);
  @$pb.TagNumber(1)
  set nativeTypeNumber($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasNativeTypeNumber() => $_has(0);
  @$pb.TagNumber(1)
  void clearNativeTypeNumber() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get safeMessage => $_getSZ(1);
  @$pb.TagNumber(2)
  set safeMessage($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSafeMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearSafeMessage() => $_clearField(2);
}

enum AgentEvent_Payload {
  connection,
  requestProgress,
  message,
  tool,
  approval,
  clarification,
  requestTerminal,
  unsupported,
  notSet
}

class AgentEvent extends $pb.GeneratedMessage {
  factory AgentEvent({
    AgentEventType? type,
    ConnectionEvent? connection,
    RequestProgressEvent? requestProgress,
    MessageEvent? message,
    ToolEvent? tool,
    ApprovalEvent? approval,
    ClarificationEvent? clarification,
    RequestTerminalEvent? requestTerminal,
    UnsupportedEvent? unsupported,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (connection != null) result.connection = connection;
    if (requestProgress != null) result.requestProgress = requestProgress;
    if (message != null) result.message = message;
    if (tool != null) result.tool = tool;
    if (approval != null) result.approval = approval;
    if (clarification != null) result.clarification = clarification;
    if (requestTerminal != null) result.requestTerminal = requestTerminal;
    if (unsupported != null) result.unsupported = unsupported;
    return result;
  }

  AgentEvent._();

  factory AgentEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AgentEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, AgentEvent_Payload>
      _AgentEvent_PayloadByTag = {
    10: AgentEvent_Payload.connection,
    11: AgentEvent_Payload.requestProgress,
    12: AgentEvent_Payload.message,
    13: AgentEvent_Payload.tool,
    14: AgentEvent_Payload.approval,
    15: AgentEvent_Payload.clarification,
    16: AgentEvent_Payload.requestTerminal,
    17: AgentEvent_Payload.unsupported,
    0: AgentEvent_Payload.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..oo(0, [10, 11, 12, 13, 14, 15, 16, 17])
    ..aE<AgentEventType>(1, _omitFieldNames ? '' : 'type',
        enumValues: AgentEventType.values)
    ..aOM<ConnectionEvent>(10, _omitFieldNames ? '' : 'connection',
        subBuilder: ConnectionEvent.create)
    ..aOM<RequestProgressEvent>(11, _omitFieldNames ? '' : 'requestProgress',
        subBuilder: RequestProgressEvent.create)
    ..aOM<MessageEvent>(12, _omitFieldNames ? '' : 'message',
        subBuilder: MessageEvent.create)
    ..aOM<ToolEvent>(13, _omitFieldNames ? '' : 'tool',
        subBuilder: ToolEvent.create)
    ..aOM<ApprovalEvent>(14, _omitFieldNames ? '' : 'approval',
        subBuilder: ApprovalEvent.create)
    ..aOM<ClarificationEvent>(15, _omitFieldNames ? '' : 'clarification',
        subBuilder: ClarificationEvent.create)
    ..aOM<RequestTerminalEvent>(16, _omitFieldNames ? '' : 'requestTerminal',
        subBuilder: RequestTerminalEvent.create)
    ..aOM<UnsupportedEvent>(17, _omitFieldNames ? '' : 'unsupported',
        subBuilder: UnsupportedEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentEvent copyWith(void Function(AgentEvent) updates) =>
      super.copyWith((message) => updates(message as AgentEvent)) as AgentEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AgentEvent create() => AgentEvent._();
  @$core.override
  AgentEvent createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AgentEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentEvent>(create);
  static AgentEvent? _defaultInstance;

  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  AgentEvent_Payload whichPayload() =>
      _AgentEvent_PayloadByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  @$pb.TagNumber(15)
  @$pb.TagNumber(16)
  @$pb.TagNumber(17)
  void clearPayload() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  AgentEventType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(AgentEventType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(10)
  ConnectionEvent get connection => $_getN(1);
  @$pb.TagNumber(10)
  set connection(ConnectionEvent value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasConnection() => $_has(1);
  @$pb.TagNumber(10)
  void clearConnection() => $_clearField(10);
  @$pb.TagNumber(10)
  ConnectionEvent ensureConnection() => $_ensure(1);

  @$pb.TagNumber(11)
  RequestProgressEvent get requestProgress => $_getN(2);
  @$pb.TagNumber(11)
  set requestProgress(RequestProgressEvent value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasRequestProgress() => $_has(2);
  @$pb.TagNumber(11)
  void clearRequestProgress() => $_clearField(11);
  @$pb.TagNumber(11)
  RequestProgressEvent ensureRequestProgress() => $_ensure(2);

  @$pb.TagNumber(12)
  MessageEvent get message => $_getN(3);
  @$pb.TagNumber(12)
  set message(MessageEvent value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasMessage() => $_has(3);
  @$pb.TagNumber(12)
  void clearMessage() => $_clearField(12);
  @$pb.TagNumber(12)
  MessageEvent ensureMessage() => $_ensure(3);

  @$pb.TagNumber(13)
  ToolEvent get tool => $_getN(4);
  @$pb.TagNumber(13)
  set tool(ToolEvent value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasTool() => $_has(4);
  @$pb.TagNumber(13)
  void clearTool() => $_clearField(13);
  @$pb.TagNumber(13)
  ToolEvent ensureTool() => $_ensure(4);

  @$pb.TagNumber(14)
  ApprovalEvent get approval => $_getN(5);
  @$pb.TagNumber(14)
  set approval(ApprovalEvent value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasApproval() => $_has(5);
  @$pb.TagNumber(14)
  void clearApproval() => $_clearField(14);
  @$pb.TagNumber(14)
  ApprovalEvent ensureApproval() => $_ensure(5);

  @$pb.TagNumber(15)
  ClarificationEvent get clarification => $_getN(6);
  @$pb.TagNumber(15)
  set clarification(ClarificationEvent value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasClarification() => $_has(6);
  @$pb.TagNumber(15)
  void clearClarification() => $_clearField(15);
  @$pb.TagNumber(15)
  ClarificationEvent ensureClarification() => $_ensure(6);

  @$pb.TagNumber(16)
  RequestTerminalEvent get requestTerminal => $_getN(7);
  @$pb.TagNumber(16)
  set requestTerminal(RequestTerminalEvent value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasRequestTerminal() => $_has(7);
  @$pb.TagNumber(16)
  void clearRequestTerminal() => $_clearField(16);
  @$pb.TagNumber(16)
  RequestTerminalEvent ensureRequestTerminal() => $_ensure(7);

  @$pb.TagNumber(17)
  UnsupportedEvent get unsupported => $_getN(8);
  @$pb.TagNumber(17)
  set unsupported(UnsupportedEvent value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasUnsupported() => $_has(8);
  @$pb.TagNumber(17)
  void clearUnsupported() => $_clearField(17);
  @$pb.TagNumber(17)
  UnsupportedEvent ensureUnsupported() => $_ensure(8);
}

class EventEnvelope extends $pb.GeneratedMessage {
  factory EventEnvelope({
    $1.ProtocolVersion? protocol,
    $core.String? eventId,
    $core.String? connectionId,
    $core.String? deviceId,
    $core.String? conversationId,
    $core.String? sessionId,
    $core.String? requestId,
    $fixnum.Int64? sequence,
    $0.Timestamp? occurredAt,
    AgentEvent? event,
  }) {
    final result = create();
    if (protocol != null) result.protocol = protocol;
    if (eventId != null) result.eventId = eventId;
    if (connectionId != null) result.connectionId = connectionId;
    if (deviceId != null) result.deviceId = deviceId;
    if (conversationId != null) result.conversationId = conversationId;
    if (sessionId != null) result.sessionId = sessionId;
    if (requestId != null) result.requestId = requestId;
    if (sequence != null) result.sequence = sequence;
    if (occurredAt != null) result.occurredAt = occurredAt;
    if (event != null) result.event = event;
    return result;
  }

  EventEnvelope._();

  factory EventEnvelope.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory EventEnvelope.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventEnvelope',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOM<$1.ProtocolVersion>(1, _omitFieldNames ? '' : 'protocol',
        subBuilder: $1.ProtocolVersion.create)
    ..aOS(2, _omitFieldNames ? '' : 'eventId')
    ..aOS(3, _omitFieldNames ? '' : 'connectionId')
    ..aOS(4, _omitFieldNames ? '' : 'deviceId')
    ..aOS(5, _omitFieldNames ? '' : 'conversationId')
    ..aOS(6, _omitFieldNames ? '' : 'sessionId')
    ..aOS(7, _omitFieldNames ? '' : 'requestId')
    ..a<$fixnum.Int64>(
        8, _omitFieldNames ? '' : 'sequence', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aOM<$0.Timestamp>(9, _omitFieldNames ? '' : 'occurredAt',
        subBuilder: $0.Timestamp.create)
    ..aOM<AgentEvent>(10, _omitFieldNames ? '' : 'event',
        subBuilder: AgentEvent.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventEnvelope clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventEnvelope copyWith(void Function(EventEnvelope) updates) =>
      super.copyWith((message) => updates(message as EventEnvelope))
          as EventEnvelope;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static EventEnvelope create() => EventEnvelope._();
  @$core.override
  EventEnvelope createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static EventEnvelope getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EventEnvelope>(create);
  static EventEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  $1.ProtocolVersion get protocol => $_getN(0);
  @$pb.TagNumber(1)
  set protocol($1.ProtocolVersion value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProtocol() => $_has(0);
  @$pb.TagNumber(1)
  void clearProtocol() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.ProtocolVersion ensureProtocol() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get eventId => $_getSZ(1);
  @$pb.TagNumber(2)
  set eventId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEventId() => $_has(1);
  @$pb.TagNumber(2)
  void clearEventId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get connectionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set connectionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasConnectionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearConnectionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceId => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceId() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get conversationId => $_getSZ(4);
  @$pb.TagNumber(5)
  set conversationId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasConversationId() => $_has(4);
  @$pb.TagNumber(5)
  void clearConversationId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get sessionId => $_getSZ(5);
  @$pb.TagNumber(6)
  set sessionId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSessionId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSessionId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get requestId => $_getSZ(6);
  @$pb.TagNumber(7)
  set requestId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRequestId() => $_has(6);
  @$pb.TagNumber(7)
  void clearRequestId() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get sequence => $_getI64(7);
  @$pb.TagNumber(8)
  set sequence($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSequence() => $_has(7);
  @$pb.TagNumber(8)
  void clearSequence() => $_clearField(8);

  @$pb.TagNumber(9)
  $0.Timestamp get occurredAt => $_getN(8);
  @$pb.TagNumber(9)
  set occurredAt($0.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasOccurredAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearOccurredAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $0.Timestamp ensureOccurredAt() => $_ensure(8);

  @$pb.TagNumber(10)
  AgentEvent get event => $_getN(9);
  @$pb.TagNumber(10)
  set event(AgentEvent value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasEvent() => $_has(9);
  @$pb.TagNumber(10)
  void clearEvent() => $_clearField(10);
  @$pb.TagNumber(10)
  AgentEvent ensureEvent() => $_ensure(9);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
