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

import 'package:protobuf/protobuf.dart' as $pb;

class AgentEventType extends $pb.ProtobufEnum {
  static const AgentEventType AGENT_EVENT_TYPE_UNSPECIFIED =
      AgentEventType._(0, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_UNSPECIFIED');
  static const AgentEventType AGENT_EVENT_TYPE_CONNECTION_READY =
      AgentEventType._(
          1, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_CONNECTION_READY');
  static const AgentEventType AGENT_EVENT_TYPE_CONNECTION_LOST =
      AgentEventType._(
          2, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_CONNECTION_LOST');
  static const AgentEventType AGENT_EVENT_TYPE_REQUEST_ACCEPTED =
      AgentEventType._(
          3, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_REQUEST_ACCEPTED');
  static const AgentEventType AGENT_EVENT_TYPE_AGENT_WORKING = AgentEventType._(
      4, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_AGENT_WORKING');
  static const AgentEventType AGENT_EVENT_TYPE_REQUEST_INTERRUPTING =
      AgentEventType._(
          5, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_REQUEST_INTERRUPTING');
  static const AgentEventType AGENT_EVENT_TYPE_MESSAGE_DELTA = AgentEventType._(
      6, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_MESSAGE_DELTA');
  static const AgentEventType AGENT_EVENT_TYPE_MESSAGE_COMPLETED =
      AgentEventType._(
          7, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_MESSAGE_COMPLETED');
  static const AgentEventType AGENT_EVENT_TYPE_TOOL_STARTED = AgentEventType._(
      8, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_TOOL_STARTED');
  static const AgentEventType AGENT_EVENT_TYPE_TOOL_COMPLETED =
      AgentEventType._(
          9, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_TOOL_COMPLETED');
  static const AgentEventType AGENT_EVENT_TYPE_TOOL_FAILED = AgentEventType._(
      10, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_TOOL_FAILED');
  static const AgentEventType AGENT_EVENT_TYPE_APPROVAL_REQUIRED =
      AgentEventType._(
          11, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_APPROVAL_REQUIRED');
  static const AgentEventType AGENT_EVENT_TYPE_APPROVAL_RESOLVED =
      AgentEventType._(
          12, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_APPROVAL_RESOLVED');
  static const AgentEventType AGENT_EVENT_TYPE_APPROVAL_EXPIRED =
      AgentEventType._(
          13, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_APPROVAL_EXPIRED');
  static const AgentEventType AGENT_EVENT_TYPE_APPROVAL_CANCELLED =
      AgentEventType._(
          14, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_APPROVAL_CANCELLED');
  static const AgentEventType AGENT_EVENT_TYPE_CLARIFICATION_REQUIRED =
      AgentEventType._(
          15, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_CLARIFICATION_REQUIRED');
  static const AgentEventType AGENT_EVENT_TYPE_CLARIFICATION_RESOLVED =
      AgentEventType._(
          16, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_CLARIFICATION_RESOLVED');
  static const AgentEventType AGENT_EVENT_TYPE_CLARIFICATION_EXPIRED =
      AgentEventType._(
          17, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_CLARIFICATION_EXPIRED');
  static const AgentEventType AGENT_EVENT_TYPE_CLARIFICATION_CANCELLED =
      AgentEventType._(
          18, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_CLARIFICATION_CANCELLED');
  static const AgentEventType AGENT_EVENT_TYPE_REQUEST_COMPLETED =
      AgentEventType._(
          19, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_REQUEST_COMPLETED');
  static const AgentEventType AGENT_EVENT_TYPE_REQUEST_FAILED =
      AgentEventType._(
          20, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_REQUEST_FAILED');
  static const AgentEventType AGENT_EVENT_TYPE_REQUEST_CANCELLED =
      AgentEventType._(
          21, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_REQUEST_CANCELLED');
  static const AgentEventType AGENT_EVENT_TYPE_REQUEST_INTERRUPTED =
      AgentEventType._(
          22, _omitEnumNames ? '' : 'AGENT_EVENT_TYPE_REQUEST_INTERRUPTED');

  static const $core.List<AgentEventType> values = <AgentEventType>[
    AGENT_EVENT_TYPE_UNSPECIFIED,
    AGENT_EVENT_TYPE_CONNECTION_READY,
    AGENT_EVENT_TYPE_CONNECTION_LOST,
    AGENT_EVENT_TYPE_REQUEST_ACCEPTED,
    AGENT_EVENT_TYPE_AGENT_WORKING,
    AGENT_EVENT_TYPE_REQUEST_INTERRUPTING,
    AGENT_EVENT_TYPE_MESSAGE_DELTA,
    AGENT_EVENT_TYPE_MESSAGE_COMPLETED,
    AGENT_EVENT_TYPE_TOOL_STARTED,
    AGENT_EVENT_TYPE_TOOL_COMPLETED,
    AGENT_EVENT_TYPE_TOOL_FAILED,
    AGENT_EVENT_TYPE_APPROVAL_REQUIRED,
    AGENT_EVENT_TYPE_APPROVAL_RESOLVED,
    AGENT_EVENT_TYPE_APPROVAL_EXPIRED,
    AGENT_EVENT_TYPE_APPROVAL_CANCELLED,
    AGENT_EVENT_TYPE_CLARIFICATION_REQUIRED,
    AGENT_EVENT_TYPE_CLARIFICATION_RESOLVED,
    AGENT_EVENT_TYPE_CLARIFICATION_EXPIRED,
    AGENT_EVENT_TYPE_CLARIFICATION_CANCELLED,
    AGENT_EVENT_TYPE_REQUEST_COMPLETED,
    AGENT_EVENT_TYPE_REQUEST_FAILED,
    AGENT_EVENT_TYPE_REQUEST_CANCELLED,
    AGENT_EVENT_TYPE_REQUEST_INTERRUPTED,
  ];

  static final $core.List<AgentEventType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 22);
  static AgentEventType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AgentEventType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
