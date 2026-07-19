// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/common.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'common.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'common.pbenum.dart';

class ProtocolVersion extends $pb.GeneratedMessage {
  factory ProtocolVersion({
    $core.int? major,
    $core.int? minor,
  }) {
    final result = create();
    if (major != null) result.major = major;
    if (minor != null) result.minor = minor;
    return result;
  }

  ProtocolVersion._();

  factory ProtocolVersion.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtocolVersion.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolVersion',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'major', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'minor', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolVersion clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolVersion copyWith(void Function(ProtocolVersion) updates) =>
      super.copyWith((message) => updates(message as ProtocolVersion))
          as ProtocolVersion;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolVersion create() => ProtocolVersion._();
  @$core.override
  ProtocolVersion createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtocolVersion getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtocolVersion>(create);
  static ProtocolVersion? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get major => $_getIZ(0);
  @$pb.TagNumber(1)
  set major($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMajor() => $_has(0);
  @$pb.TagNumber(1)
  void clearMajor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get minor => $_getIZ(1);
  @$pb.TagNumber(2)
  set minor($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMinor() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinor() => $_clearField(2);
}

class ProtocolVersionRange extends $pb.GeneratedMessage {
  factory ProtocolVersionRange({
    $core.int? major,
    $core.int? minimumMinor,
    $core.int? maximumMinor,
  }) {
    final result = create();
    if (major != null) result.major = major;
    if (minimumMinor != null) result.minimumMinor = minimumMinor;
    if (maximumMinor != null) result.maximumMinor = maximumMinor;
    return result;
  }

  ProtocolVersionRange._();

  factory ProtocolVersionRange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ProtocolVersionRange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ProtocolVersionRange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'major', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'minimumMinor',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'maximumMinor',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolVersionRange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ProtocolVersionRange copyWith(void Function(ProtocolVersionRange) updates) =>
      super.copyWith((message) => updates(message as ProtocolVersionRange))
          as ProtocolVersionRange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ProtocolVersionRange create() => ProtocolVersionRange._();
  @$core.override
  ProtocolVersionRange createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ProtocolVersionRange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ProtocolVersionRange>(create);
  static ProtocolVersionRange? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get major => $_getIZ(0);
  @$pb.TagNumber(1)
  set major($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMajor() => $_has(0);
  @$pb.TagNumber(1)
  void clearMajor() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get minimumMinor => $_getIZ(1);
  @$pb.TagNumber(2)
  set minimumMinor($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMinimumMinor() => $_has(1);
  @$pb.TagNumber(2)
  void clearMinimumMinor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get maximumMinor => $_getIZ(2);
  @$pb.TagNumber(3)
  set maximumMinor($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMaximumMinor() => $_has(2);
  @$pb.TagNumber(3)
  void clearMaximumMinor() => $_clearField(3);
}

class AgentCapabilities extends $pb.GeneratedMessage {
  factory AgentCapabilities({
    DeltaMode? deltaMode,
    $core.bool? eventStream,
    $core.bool? sessionHistory,
    $core.bool? createSession,
    $core.bool? resumeSession,
    $core.bool? interrupt,
    $core.bool? steer,
    $core.bool? clarification,
    $core.bool? approval,
    $core.bool? toolEvents,
    $core.bool? attachments,
    $core.bool? idempotency,
    $core.bool? replay,
    $core.bool? sequenceRecovery,
    $fixnum.Int64? maxRequestBytes,
    $fixnum.Int64? requestTimeoutMs,
  }) {
    final result = create();
    if (deltaMode != null) result.deltaMode = deltaMode;
    if (eventStream != null) result.eventStream = eventStream;
    if (sessionHistory != null) result.sessionHistory = sessionHistory;
    if (createSession != null) result.createSession = createSession;
    if (resumeSession != null) result.resumeSession = resumeSession;
    if (interrupt != null) result.interrupt = interrupt;
    if (steer != null) result.steer = steer;
    if (clarification != null) result.clarification = clarification;
    if (approval != null) result.approval = approval;
    if (toolEvents != null) result.toolEvents = toolEvents;
    if (attachments != null) result.attachments = attachments;
    if (idempotency != null) result.idempotency = idempotency;
    if (replay != null) result.replay = replay;
    if (sequenceRecovery != null) result.sequenceRecovery = sequenceRecovery;
    if (maxRequestBytes != null) result.maxRequestBytes = maxRequestBytes;
    if (requestTimeoutMs != null) result.requestTimeoutMs = requestTimeoutMs;
    return result;
  }

  AgentCapabilities._();

  factory AgentCapabilities.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AgentCapabilities.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentCapabilities',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aE<DeltaMode>(1, _omitFieldNames ? '' : 'deltaMode',
        enumValues: DeltaMode.values)
    ..aOB(2, _omitFieldNames ? '' : 'eventStream')
    ..aOB(3, _omitFieldNames ? '' : 'sessionHistory')
    ..aOB(4, _omitFieldNames ? '' : 'createSession')
    ..aOB(5, _omitFieldNames ? '' : 'resumeSession')
    ..aOB(6, _omitFieldNames ? '' : 'interrupt')
    ..aOB(7, _omitFieldNames ? '' : 'steer')
    ..aOB(8, _omitFieldNames ? '' : 'clarification')
    ..aOB(9, _omitFieldNames ? '' : 'approval')
    ..aOB(10, _omitFieldNames ? '' : 'toolEvents')
    ..aOB(11, _omitFieldNames ? '' : 'attachments')
    ..aOB(12, _omitFieldNames ? '' : 'idempotency')
    ..aOB(13, _omitFieldNames ? '' : 'replay')
    ..aOB(14, _omitFieldNames ? '' : 'sequenceRecovery')
    ..a<$fixnum.Int64>(
        15, _omitFieldNames ? '' : 'maxRequestBytes', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..a<$fixnum.Int64>(
        16, _omitFieldNames ? '' : 'requestTimeoutMs', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCapabilities clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentCapabilities copyWith(void Function(AgentCapabilities) updates) =>
      super.copyWith((message) => updates(message as AgentCapabilities))
          as AgentCapabilities;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AgentCapabilities create() => AgentCapabilities._();
  @$core.override
  AgentCapabilities createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AgentCapabilities getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AgentCapabilities>(create);
  static AgentCapabilities? _defaultInstance;

  @$pb.TagNumber(1)
  DeltaMode get deltaMode => $_getN(0);
  @$pb.TagNumber(1)
  set deltaMode(DeltaMode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasDeltaMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeltaMode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get eventStream => $_getBF(1);
  @$pb.TagNumber(2)
  set eventStream($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEventStream() => $_has(1);
  @$pb.TagNumber(2)
  void clearEventStream() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get sessionHistory => $_getBF(2);
  @$pb.TagNumber(3)
  set sessionHistory($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionHistory() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionHistory() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get createSession => $_getBF(3);
  @$pb.TagNumber(4)
  set createSession($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreateSession() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreateSession() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get resumeSession => $_getBF(4);
  @$pb.TagNumber(5)
  set resumeSession($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasResumeSession() => $_has(4);
  @$pb.TagNumber(5)
  void clearResumeSession() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get interrupt => $_getBF(5);
  @$pb.TagNumber(6)
  set interrupt($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInterrupt() => $_has(5);
  @$pb.TagNumber(6)
  void clearInterrupt() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get steer => $_getBF(6);
  @$pb.TagNumber(7)
  set steer($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSteer() => $_has(6);
  @$pb.TagNumber(7)
  void clearSteer() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get clarification => $_getBF(7);
  @$pb.TagNumber(8)
  set clarification($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasClarification() => $_has(7);
  @$pb.TagNumber(8)
  void clearClarification() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get approval => $_getBF(8);
  @$pb.TagNumber(9)
  set approval($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasApproval() => $_has(8);
  @$pb.TagNumber(9)
  void clearApproval() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get toolEvents => $_getBF(9);
  @$pb.TagNumber(10)
  set toolEvents($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasToolEvents() => $_has(9);
  @$pb.TagNumber(10)
  void clearToolEvents() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get attachments => $_getBF(10);
  @$pb.TagNumber(11)
  set attachments($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAttachments() => $_has(10);
  @$pb.TagNumber(11)
  void clearAttachments() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get idempotency => $_getBF(11);
  @$pb.TagNumber(12)
  set idempotency($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasIdempotency() => $_has(11);
  @$pb.TagNumber(12)
  void clearIdempotency() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get replay => $_getBF(12);
  @$pb.TagNumber(13)
  set replay($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasReplay() => $_has(12);
  @$pb.TagNumber(13)
  void clearReplay() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get sequenceRecovery => $_getBF(13);
  @$pb.TagNumber(14)
  set sequenceRecovery($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSequenceRecovery() => $_has(13);
  @$pb.TagNumber(14)
  void clearSequenceRecovery() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get maxRequestBytes => $_getI64(14);
  @$pb.TagNumber(15)
  set maxRequestBytes($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasMaxRequestBytes() => $_has(14);
  @$pb.TagNumber(15)
  void clearMaxRequestBytes() => $_clearField(15);

  @$pb.TagNumber(16)
  $fixnum.Int64 get requestTimeoutMs => $_getI64(15);
  @$pb.TagNumber(16)
  set requestTimeoutMs($fixnum.Int64 value) => $_setInt64(15, value);
  @$pb.TagNumber(16)
  $core.bool hasRequestTimeoutMs() => $_has(15);
  @$pb.TagNumber(16)
  void clearRequestTimeoutMs() => $_clearField(16);
}

class StageFailure extends $pb.GeneratedMessage {
  factory StageFailure({
    FailureStage? stage,
    FailureCategory? category,
    $core.String? code,
    $core.String? safeMessage,
    $core.bool? retryable,
  }) {
    final result = create();
    if (stage != null) result.stage = stage;
    if (category != null) result.category = category;
    if (code != null) result.code = code;
    if (safeMessage != null) result.safeMessage = safeMessage;
    if (retryable != null) result.retryable = retryable;
    return result;
  }

  StageFailure._();

  factory StageFailure.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StageFailure.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StageFailure',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aE<FailureStage>(1, _omitFieldNames ? '' : 'stage',
        enumValues: FailureStage.values)
    ..aE<FailureCategory>(2, _omitFieldNames ? '' : 'category',
        enumValues: FailureCategory.values)
    ..aOS(3, _omitFieldNames ? '' : 'code')
    ..aOS(4, _omitFieldNames ? '' : 'safeMessage')
    ..aOB(5, _omitFieldNames ? '' : 'retryable')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StageFailure clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StageFailure copyWith(void Function(StageFailure) updates) =>
      super.copyWith((message) => updates(message as StageFailure))
          as StageFailure;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StageFailure create() => StageFailure._();
  @$core.override
  StageFailure createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StageFailure getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StageFailure>(create);
  static StageFailure? _defaultInstance;

  @$pb.TagNumber(1)
  FailureStage get stage => $_getN(0);
  @$pb.TagNumber(1)
  set stage(FailureStage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasStage() => $_has(0);
  @$pb.TagNumber(1)
  void clearStage() => $_clearField(1);

  @$pb.TagNumber(2)
  FailureCategory get category => $_getN(1);
  @$pb.TagNumber(2)
  set category(FailureCategory value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCategory() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategory() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get code => $_getSZ(2);
  @$pb.TagNumber(3)
  set code($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get safeMessage => $_getSZ(3);
  @$pb.TagNumber(4)
  set safeMessage($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSafeMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearSafeMessage() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get retryable => $_getBF(4);
  @$pb.TagNumber(5)
  set retryable($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRetryable() => $_has(4);
  @$pb.TagNumber(5)
  void clearRetryable() => $_clearField(5);
}

class Empty extends $pb.GeneratedMessage {
  factory Empty() => create();

  Empty._();

  factory Empty.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Empty.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Empty',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Empty copyWith(void Function(Empty) updates) =>
      super.copyWith((message) => updates(message as Empty)) as Empty;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Empty create() => Empty._();
  @$core.override
  Empty createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Empty getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Empty>(create);
  static Empty? _defaultInstance;
}

/// The signature is calculated over a domain-separated payload defined by the
/// owning RPC. Nonces are opaque, single-use values and must never be logged.
class DeviceSignature extends $pb.GeneratedMessage {
  factory DeviceSignature({
    $core.String? credentialId,
    $core.List<$core.int>? nonce,
    $core.List<$core.int>? signature,
    DeviceSignatureAlgorithm? algorithm,
  }) {
    final result = create();
    if (credentialId != null) result.credentialId = credentialId;
    if (nonce != null) result.nonce = nonce;
    if (signature != null) result.signature = signature;
    if (algorithm != null) result.algorithm = algorithm;
    return result;
  }

  DeviceSignature._();

  factory DeviceSignature.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceSignature.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceSignature',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'agent_talk.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'credentialId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'nonce', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'signature', $pb.PbFieldType.OY)
    ..aE<DeviceSignatureAlgorithm>(4, _omitFieldNames ? '' : 'algorithm',
        enumValues: DeviceSignatureAlgorithm.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceSignature clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceSignature copyWith(void Function(DeviceSignature) updates) =>
      super.copyWith((message) => updates(message as DeviceSignature))
          as DeviceSignature;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceSignature create() => DeviceSignature._();
  @$core.override
  DeviceSignature createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceSignature getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceSignature>(create);
  static DeviceSignature? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get credentialId => $_getSZ(0);
  @$pb.TagNumber(1)
  set credentialId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCredentialId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCredentialId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get nonce => $_getN(1);
  @$pb.TagNumber(2)
  set nonce($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasNonce() => $_has(1);
  @$pb.TagNumber(2)
  void clearNonce() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get signature => $_getN(2);
  @$pb.TagNumber(3)
  set signature($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSignature() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignature() => $_clearField(3);

  @$pb.TagNumber(4)
  DeviceSignatureAlgorithm get algorithm => $_getN(3);
  @$pb.TagNumber(4)
  set algorithm(DeviceSignatureAlgorithm value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasAlgorithm() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlgorithm() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
