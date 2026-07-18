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

import 'package:protobuf/protobuf.dart' as $pb;

class ApprovalDecision extends $pb.ProtobufEnum {
  static const ApprovalDecision APPROVAL_DECISION_UNSPECIFIED =
      ApprovalDecision._(
          0, _omitEnumNames ? '' : 'APPROVAL_DECISION_UNSPECIFIED');
  static const ApprovalDecision APPROVAL_DECISION_APPROVE =
      ApprovalDecision._(1, _omitEnumNames ? '' : 'APPROVAL_DECISION_APPROVE');
  static const ApprovalDecision APPROVAL_DECISION_DENY =
      ApprovalDecision._(2, _omitEnumNames ? '' : 'APPROVAL_DECISION_DENY');

  static const $core.List<ApprovalDecision> values = <ApprovalDecision>[
    APPROVAL_DECISION_UNSPECIFIED,
    APPROVAL_DECISION_APPROVE,
    APPROVAL_DECISION_DENY,
  ];

  static final $core.List<ApprovalDecision?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static ApprovalDecision? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ApprovalDecision._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
