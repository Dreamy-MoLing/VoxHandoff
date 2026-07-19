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

import 'package:protobuf/protobuf.dart' as $pb;

class ComponentRole extends $pb.ProtobufEnum {
  static const ComponentRole COMPONENT_ROLE_UNSPECIFIED =
      ComponentRole._(0, _omitEnumNames ? '' : 'COMPONENT_ROLE_UNSPECIFIED');
  static const ComponentRole COMPONENT_ROLE_CLIENT =
      ComponentRole._(1, _omitEnumNames ? '' : 'COMPONENT_ROLE_CLIENT');
  static const ComponentRole COMPONENT_ROLE_GATEWAY =
      ComponentRole._(2, _omitEnumNames ? '' : 'COMPONENT_ROLE_GATEWAY');
  static const ComponentRole COMPONENT_ROLE_NODE =
      ComponentRole._(3, _omitEnumNames ? '' : 'COMPONENT_ROLE_NODE');
  static const ComponentRole COMPONENT_ROLE_SIDECAR =
      ComponentRole._(4, _omitEnumNames ? '' : 'COMPONENT_ROLE_SIDECAR');
  static const ComponentRole COMPONENT_ROLE_STT =
      ComponentRole._(5, _omitEnumNames ? '' : 'COMPONENT_ROLE_STT');

  static const $core.List<ComponentRole> values = <ComponentRole>[
    COMPONENT_ROLE_UNSPECIFIED,
    COMPONENT_ROLE_CLIENT,
    COMPONENT_ROLE_GATEWAY,
    COMPONENT_ROLE_NODE,
    COMPONENT_ROLE_SIDECAR,
    COMPONENT_ROLE_STT,
  ];

  static final $core.List<ComponentRole?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static ComponentRole? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ComponentRole._(super.value, super.name);
}

class DeltaMode extends $pb.ProtobufEnum {
  static const DeltaMode DELTA_MODE_UNSPECIFIED =
      DeltaMode._(0, _omitEnumNames ? '' : 'DELTA_MODE_UNSPECIFIED');
  static const DeltaMode DELTA_MODE_NONE =
      DeltaMode._(1, _omitEnumNames ? '' : 'DELTA_MODE_NONE');
  static const DeltaMode DELTA_MODE_APPEND_ONLY =
      DeltaMode._(2, _omitEnumNames ? '' : 'DELTA_MODE_APPEND_ONLY');
  static const DeltaMode DELTA_MODE_REVISABLE =
      DeltaMode._(3, _omitEnumNames ? '' : 'DELTA_MODE_REVISABLE');

  static const $core.List<DeltaMode> values = <DeltaMode>[
    DELTA_MODE_UNSPECIFIED,
    DELTA_MODE_NONE,
    DELTA_MODE_APPEND_ONLY,
    DELTA_MODE_REVISABLE,
  ];

  static final $core.List<DeltaMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static DeltaMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeltaMode._(super.value, super.name);
}

class FailureStage extends $pb.ProtobufEnum {
  static const FailureStage FAILURE_STAGE_UNSPECIFIED =
      FailureStage._(0, _omitEnumNames ? '' : 'FAILURE_STAGE_UNSPECIFIED');
  static const FailureStage FAILURE_STAGE_RECORDING =
      FailureStage._(1, _omitEnumNames ? '' : 'FAILURE_STAGE_RECORDING');
  static const FailureStage FAILURE_STAGE_STT =
      FailureStage._(2, _omitEnumNames ? '' : 'FAILURE_STAGE_STT');
  static const FailureStage FAILURE_STAGE_CONNECTION =
      FailureStage._(3, _omitEnumNames ? '' : 'FAILURE_STAGE_CONNECTION');
  static const FailureStage FAILURE_STAGE_AUTHENTICATION =
      FailureStage._(4, _omitEnumNames ? '' : 'FAILURE_STAGE_AUTHENTICATION');
  static const FailureStage FAILURE_STAGE_AUTHORIZATION =
      FailureStage._(5, _omitEnumNames ? '' : 'FAILURE_STAGE_AUTHORIZATION');
  static const FailureStage FAILURE_STAGE_PROTOCOL =
      FailureStage._(6, _omitEnumNames ? '' : 'FAILURE_STAGE_PROTOCOL');
  static const FailureStage FAILURE_STAGE_AGENT =
      FailureStage._(7, _omitEnumNames ? '' : 'FAILURE_STAGE_AGENT');
  static const FailureStage FAILURE_STAGE_SUMMARY =
      FailureStage._(8, _omitEnumNames ? '' : 'FAILURE_STAGE_SUMMARY');
  static const FailureStage FAILURE_STAGE_TTS =
      FailureStage._(9, _omitEnumNames ? '' : 'FAILURE_STAGE_TTS');
  static const FailureStage FAILURE_STAGE_PLAYBACK =
      FailureStage._(10, _omitEnumNames ? '' : 'FAILURE_STAGE_PLAYBACK');
  static const FailureStage FAILURE_STAGE_STORAGE =
      FailureStage._(11, _omitEnumNames ? '' : 'FAILURE_STAGE_STORAGE');
  static const FailureStage FAILURE_STAGE_SYNC =
      FailureStage._(12, _omitEnumNames ? '' : 'FAILURE_STAGE_SYNC');
  static const FailureStage FAILURE_STAGE_CONFIGURATION =
      FailureStage._(13, _omitEnumNames ? '' : 'FAILURE_STAGE_CONFIGURATION');

  static const $core.List<FailureStage> values = <FailureStage>[
    FAILURE_STAGE_UNSPECIFIED,
    FAILURE_STAGE_RECORDING,
    FAILURE_STAGE_STT,
    FAILURE_STAGE_CONNECTION,
    FAILURE_STAGE_AUTHENTICATION,
    FAILURE_STAGE_AUTHORIZATION,
    FAILURE_STAGE_PROTOCOL,
    FAILURE_STAGE_AGENT,
    FAILURE_STAGE_SUMMARY,
    FAILURE_STAGE_TTS,
    FAILURE_STAGE_PLAYBACK,
    FAILURE_STAGE_STORAGE,
    FAILURE_STAGE_SYNC,
    FAILURE_STAGE_CONFIGURATION,
  ];

  static final $core.List<FailureStage?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 13);
  static FailureStage? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FailureStage._(super.value, super.name);
}

class FailureCategory extends $pb.ProtobufEnum {
  static const FailureCategory FAILURE_CATEGORY_UNSPECIFIED = FailureCategory._(
      0, _omitEnumNames ? '' : 'FAILURE_CATEGORY_UNSPECIFIED');
  static const FailureCategory FAILURE_CATEGORY_VALIDATION =
      FailureCategory._(1, _omitEnumNames ? '' : 'FAILURE_CATEGORY_VALIDATION');
  static const FailureCategory FAILURE_CATEGORY_UNAVAILABLE = FailureCategory._(
      2, _omitEnumNames ? '' : 'FAILURE_CATEGORY_UNAVAILABLE');
  static const FailureCategory FAILURE_CATEGORY_AUTHENTICATION =
      FailureCategory._(
          3, _omitEnumNames ? '' : 'FAILURE_CATEGORY_AUTHENTICATION');
  static const FailureCategory FAILURE_CATEGORY_AUTHORIZATION =
      FailureCategory._(
          4, _omitEnumNames ? '' : 'FAILURE_CATEGORY_AUTHORIZATION');
  static const FailureCategory FAILURE_CATEGORY_PROTOCOL =
      FailureCategory._(5, _omitEnumNames ? '' : 'FAILURE_CATEGORY_PROTOCOL');
  static const FailureCategory FAILURE_CATEGORY_TIMEOUT =
      FailureCategory._(6, _omitEnumNames ? '' : 'FAILURE_CATEGORY_TIMEOUT');
  static const FailureCategory FAILURE_CATEGORY_RATE_LIMIT =
      FailureCategory._(7, _omitEnumNames ? '' : 'FAILURE_CATEGORY_RATE_LIMIT');
  static const FailureCategory FAILURE_CATEGORY_UPSTREAM =
      FailureCategory._(8, _omitEnumNames ? '' : 'FAILURE_CATEGORY_UPSTREAM');
  static const FailureCategory FAILURE_CATEGORY_STORAGE =
      FailureCategory._(9, _omitEnumNames ? '' : 'FAILURE_CATEGORY_STORAGE');
  static const FailureCategory FAILURE_CATEGORY_PRIVACY =
      FailureCategory._(10, _omitEnumNames ? '' : 'FAILURE_CATEGORY_PRIVACY');
  static const FailureCategory FAILURE_CATEGORY_UNKNOWN =
      FailureCategory._(11, _omitEnumNames ? '' : 'FAILURE_CATEGORY_UNKNOWN');

  static const $core.List<FailureCategory> values = <FailureCategory>[
    FAILURE_CATEGORY_UNSPECIFIED,
    FAILURE_CATEGORY_VALIDATION,
    FAILURE_CATEGORY_UNAVAILABLE,
    FAILURE_CATEGORY_AUTHENTICATION,
    FAILURE_CATEGORY_AUTHORIZATION,
    FAILURE_CATEGORY_PROTOCOL,
    FAILURE_CATEGORY_TIMEOUT,
    FAILURE_CATEGORY_RATE_LIMIT,
    FAILURE_CATEGORY_UPSTREAM,
    FAILURE_CATEGORY_STORAGE,
    FAILURE_CATEGORY_PRIVACY,
    FAILURE_CATEGORY_UNKNOWN,
  ];

  static final $core.List<FailureCategory?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 11);
  static FailureCategory? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FailureCategory._(super.value, super.name);
}

class DeviceSignatureAlgorithm extends $pb.ProtobufEnum {
  static const DeviceSignatureAlgorithm DEVICE_SIGNATURE_ALGORITHM_UNSPECIFIED =
      DeviceSignatureAlgorithm._(
          0, _omitEnumNames ? '' : 'DEVICE_SIGNATURE_ALGORITHM_UNSPECIFIED');
  static const DeviceSignatureAlgorithm DEVICE_SIGNATURE_ALGORITHM_ED25519 =
      DeviceSignatureAlgorithm._(
          1, _omitEnumNames ? '' : 'DEVICE_SIGNATURE_ALGORITHM_ED25519');

  static const $core.List<DeviceSignatureAlgorithm> values =
      <DeviceSignatureAlgorithm>[
    DEVICE_SIGNATURE_ALGORITHM_UNSPECIFIED,
    DEVICE_SIGNATURE_ALGORITHM_ED25519,
  ];

  static final $core.List<DeviceSignatureAlgorithm?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static DeviceSignatureAlgorithm? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const DeviceSignatureAlgorithm._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
