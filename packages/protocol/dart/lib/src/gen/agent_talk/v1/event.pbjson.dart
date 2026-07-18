// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/event.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use agentEventTypeDescriptor instead')
const AgentEventType$json = {
  '1': 'AgentEventType',
  '2': [
    {'1': 'AGENT_EVENT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'AGENT_EVENT_TYPE_CONNECTION_READY', '2': 1},
    {'1': 'AGENT_EVENT_TYPE_CONNECTION_LOST', '2': 2},
    {'1': 'AGENT_EVENT_TYPE_REQUEST_ACCEPTED', '2': 3},
    {'1': 'AGENT_EVENT_TYPE_AGENT_WORKING', '2': 4},
    {'1': 'AGENT_EVENT_TYPE_REQUEST_INTERRUPTING', '2': 5},
    {'1': 'AGENT_EVENT_TYPE_MESSAGE_DELTA', '2': 6},
    {'1': 'AGENT_EVENT_TYPE_MESSAGE_COMPLETED', '2': 7},
    {'1': 'AGENT_EVENT_TYPE_TOOL_STARTED', '2': 8},
    {'1': 'AGENT_EVENT_TYPE_TOOL_COMPLETED', '2': 9},
    {'1': 'AGENT_EVENT_TYPE_TOOL_FAILED', '2': 10},
    {'1': 'AGENT_EVENT_TYPE_APPROVAL_REQUIRED', '2': 11},
    {'1': 'AGENT_EVENT_TYPE_APPROVAL_RESOLVED', '2': 12},
    {'1': 'AGENT_EVENT_TYPE_APPROVAL_EXPIRED', '2': 13},
    {'1': 'AGENT_EVENT_TYPE_APPROVAL_CANCELLED', '2': 14},
    {'1': 'AGENT_EVENT_TYPE_CLARIFICATION_REQUIRED', '2': 15},
    {'1': 'AGENT_EVENT_TYPE_CLARIFICATION_RESOLVED', '2': 16},
    {'1': 'AGENT_EVENT_TYPE_CLARIFICATION_EXPIRED', '2': 17},
    {'1': 'AGENT_EVENT_TYPE_CLARIFICATION_CANCELLED', '2': 18},
    {'1': 'AGENT_EVENT_TYPE_REQUEST_COMPLETED', '2': 19},
    {'1': 'AGENT_EVENT_TYPE_REQUEST_FAILED', '2': 20},
    {'1': 'AGENT_EVENT_TYPE_REQUEST_CANCELLED', '2': 21},
    {'1': 'AGENT_EVENT_TYPE_REQUEST_INTERRUPTED', '2': 22},
  ],
};

/// Descriptor for `AgentEventType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List agentEventTypeDescriptor = $convert.base64Decode(
    'Cg5BZ2VudEV2ZW50VHlwZRIgChxBR0VOVF9FVkVOVF9UWVBFX1VOU1BFQ0lGSUVEEAASJQohQU'
    'dFTlRfRVZFTlRfVFlQRV9DT05ORUNUSU9OX1JFQURZEAESJAogQUdFTlRfRVZFTlRfVFlQRV9D'
    'T05ORUNUSU9OX0xPU1QQAhIlCiFBR0VOVF9FVkVOVF9UWVBFX1JFUVVFU1RfQUNDRVBURUQQAx'
    'IiCh5BR0VOVF9FVkVOVF9UWVBFX0FHRU5UX1dPUktJTkcQBBIpCiVBR0VOVF9FVkVOVF9UWVBF'
    'X1JFUVVFU1RfSU5URVJSVVBUSU5HEAUSIgoeQUdFTlRfRVZFTlRfVFlQRV9NRVNTQUdFX0RFTF'
    'RBEAYSJgoiQUdFTlRfRVZFTlRfVFlQRV9NRVNTQUdFX0NPTVBMRVRFRBAHEiEKHUFHRU5UX0VW'
    'RU5UX1RZUEVfVE9PTF9TVEFSVEVEEAgSIwofQUdFTlRfRVZFTlRfVFlQRV9UT09MX0NPTVBMRV'
    'RFRBAJEiAKHEFHRU5UX0VWRU5UX1RZUEVfVE9PTF9GQUlMRUQQChImCiJBR0VOVF9FVkVOVF9U'
    'WVBFX0FQUFJPVkFMX1JFUVVJUkVEEAsSJgoiQUdFTlRfRVZFTlRfVFlQRV9BUFBST1ZBTF9SRV'
    'NPTFZFRBAMEiUKIUFHRU5UX0VWRU5UX1RZUEVfQVBQUk9WQUxfRVhQSVJFRBANEicKI0FHRU5U'
    'X0VWRU5UX1RZUEVfQVBQUk9WQUxfQ0FOQ0VMTEVEEA4SKwonQUdFTlRfRVZFTlRfVFlQRV9DTE'
    'FSSUZJQ0FUSU9OX1JFUVVJUkVEEA8SKwonQUdFTlRfRVZFTlRfVFlQRV9DTEFSSUZJQ0FUSU9O'
    'X1JFU09MVkVEEBASKgomQUdFTlRfRVZFTlRfVFlQRV9DTEFSSUZJQ0FUSU9OX0VYUElSRUQQER'
    'IsCihBR0VOVF9FVkVOVF9UWVBFX0NMQVJJRklDQVRJT05fQ0FOQ0VMTEVEEBISJgoiQUdFTlRf'
    'RVZFTlRfVFlQRV9SRVFVRVNUX0NPTVBMRVRFRBATEiMKH0FHRU5UX0VWRU5UX1RZUEVfUkVRVU'
    'VTVF9GQUlMRUQQFBImCiJBR0VOVF9FVkVOVF9UWVBFX1JFUVVFU1RfQ0FOQ0VMTEVEEBUSKAok'
    'QUdFTlRfRVZFTlRfVFlQRV9SRVFVRVNUX0lOVEVSUlVQVEVEEBY=');

@$core.Deprecated('Use connectionEventDescriptor instead')
const ConnectionEvent$json = {
  '1': 'ConnectionEvent',
  '2': [
    {'1': 'safe_message', '3': 1, '4': 1, '5': 9, '10': 'safeMessage'},
  ],
};

/// Descriptor for `ConnectionEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectionEventDescriptor = $convert.base64Decode(
    'Cg9Db25uZWN0aW9uRXZlbnQSIQoMc2FmZV9tZXNzYWdlGAEgASgJUgtzYWZlTWVzc2FnZQ==');

@$core.Deprecated('Use requestProgressEventDescriptor instead')
const RequestProgressEvent$json = {
  '1': 'RequestProgressEvent',
  '2': [
    {'1': 'safe_message', '3': 1, '4': 1, '5': 9, '10': 'safeMessage'},
  ],
};

/// Descriptor for `RequestProgressEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestProgressEventDescriptor = $convert.base64Decode(
    'ChRSZXF1ZXN0UHJvZ3Jlc3NFdmVudBIhCgxzYWZlX21lc3NhZ2UYASABKAlSC3NhZmVNZXNzYW'
    'dl');

@$core.Deprecated('Use messageEventDescriptor instead')
const MessageEvent$json = {
  '1': 'MessageEvent',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'revision', '3': 2, '4': 1, '5': 4, '10': 'revision'},
  ],
};

/// Descriptor for `MessageEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messageEventDescriptor = $convert.base64Decode(
    'CgxNZXNzYWdlRXZlbnQSEgoEdGV4dBgBIAEoCVIEdGV4dBIaCghyZXZpc2lvbhgCIAEoBFIIcm'
    'V2aXNpb24=');

@$core.Deprecated('Use toolEventDescriptor instead')
const ToolEvent$json = {
  '1': 'ToolEvent',
  '2': [
    {'1': 'tool_name', '3': 1, '4': 1, '5': 9, '10': 'toolName'},
    {'1': 'stage', '3': 2, '4': 1, '5': 9, '10': 'stage'},
    {'1': 'safe_summary', '3': 3, '4': 1, '5': 9, '10': 'safeSummary'},
  ],
};

/// Descriptor for `ToolEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List toolEventDescriptor = $convert.base64Decode(
    'CglUb29sRXZlbnQSGwoJdG9vbF9uYW1lGAEgASgJUgh0b29sTmFtZRIUCgVzdGFnZRgCIAEoCV'
    'IFc3RhZ2USIQoMc2FmZV9zdW1tYXJ5GAMgASgJUgtzYWZlU3VtbWFyeQ==');

@$core.Deprecated('Use approvalEventDescriptor instead')
const ApprovalEvent$json = {
  '1': 'ApprovalEvent',
  '2': [
    {'1': 'approval_id', '3': 1, '4': 1, '5': 9, '10': 'approvalId'},
    {'1': 'safe_summary', '3': 2, '4': 1, '5': 9, '10': 'safeSummary'},
    {
      '1': 'operation_summary_sha256',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'operationSummarySha256'
    },
    {
      '1': 'expires_at',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
  ],
};

/// Descriptor for `ApprovalEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvalEventDescriptor = $convert.base64Decode(
    'Cg1BcHByb3ZhbEV2ZW50Eh8KC2FwcHJvdmFsX2lkGAEgASgJUgphcHByb3ZhbElkEiEKDHNhZm'
    'Vfc3VtbWFyeRgCIAEoCVILc2FmZVN1bW1hcnkSOAoYb3BlcmF0aW9uX3N1bW1hcnlfc2hhMjU2'
    'GAMgASgJUhZvcGVyYXRpb25TdW1tYXJ5U2hhMjU2EjkKCmV4cGlyZXNfYXQYBCABKAsyGi5nb2'
    '9nbGUucHJvdG9idWYuVGltZXN0YW1wUglleHBpcmVzQXQ=');

@$core.Deprecated('Use clarificationEventDescriptor instead')
const ClarificationEvent$json = {
  '1': 'ClarificationEvent',
  '2': [
    {'1': 'clarification_id', '3': 1, '4': 1, '5': 9, '10': 'clarificationId'},
    {'1': 'safe_prompt', '3': 2, '4': 1, '5': 9, '10': 'safePrompt'},
    {
      '1': 'expires_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
  ],
};

/// Descriptor for `ClarificationEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clarificationEventDescriptor = $convert.base64Decode(
    'ChJDbGFyaWZpY2F0aW9uRXZlbnQSKQoQY2xhcmlmaWNhdGlvbl9pZBgBIAEoCVIPY2xhcmlmaW'
    'NhdGlvbklkEh8KC3NhZmVfcHJvbXB0GAIgASgJUgpzYWZlUHJvbXB0EjkKCmV4cGlyZXNfYXQY'
    'AyABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUglleHBpcmVzQXQ=');

@$core.Deprecated('Use requestTerminalEventDescriptor instead')
const RequestTerminalEvent$json = {
  '1': 'RequestTerminalEvent',
  '2': [
    {
      '1': 'failure',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.StageFailure',
      '9': 0,
      '10': 'failure',
      '17': true
    },
  ],
  '8': [
    {'1': '_failure'},
  ],
};

/// Descriptor for `RequestTerminalEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestTerminalEventDescriptor = $convert.base64Decode(
    'ChRSZXF1ZXN0VGVybWluYWxFdmVudBI6CgdmYWlsdXJlGAEgASgLMhsuYWdlbnRfdGFsay52MS'
    '5TdGFnZUZhaWx1cmVIAFIHZmFpbHVyZYgBAUIKCghfZmFpbHVyZQ==');

@$core.Deprecated('Use unsupportedEventDescriptor instead')
const UnsupportedEvent$json = {
  '1': 'UnsupportedEvent',
  '2': [
    {
      '1': 'native_type_number',
      '3': 1,
      '4': 1,
      '5': 13,
      '10': 'nativeTypeNumber'
    },
    {'1': 'safe_message', '3': 2, '4': 1, '5': 9, '10': 'safeMessage'},
  ],
};

/// Descriptor for `UnsupportedEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unsupportedEventDescriptor = $convert.base64Decode(
    'ChBVbnN1cHBvcnRlZEV2ZW50EiwKEm5hdGl2ZV90eXBlX251bWJlchgBIAEoDVIQbmF0aXZlVH'
    'lwZU51bWJlchIhCgxzYWZlX21lc3NhZ2UYAiABKAlSC3NhZmVNZXNzYWdl');

@$core.Deprecated('Use agentEventDescriptor instead')
const AgentEvent$json = {
  '1': 'AgentEvent',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.AgentEventType',
      '10': 'type'
    },
    {
      '1': 'connection',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ConnectionEvent',
      '9': 0,
      '10': 'connection'
    },
    {
      '1': 'request_progress',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.RequestProgressEvent',
      '9': 0,
      '10': 'requestProgress'
    },
    {
      '1': 'message',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.MessageEvent',
      '9': 0,
      '10': 'message'
    },
    {
      '1': 'tool',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ToolEvent',
      '9': 0,
      '10': 'tool'
    },
    {
      '1': 'approval',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ApprovalEvent',
      '9': 0,
      '10': 'approval'
    },
    {
      '1': 'clarification',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ClarificationEvent',
      '9': 0,
      '10': 'clarification'
    },
    {
      '1': 'request_terminal',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.RequestTerminalEvent',
      '9': 0,
      '10': 'requestTerminal'
    },
    {
      '1': 'unsupported',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.UnsupportedEvent',
      '9': 0,
      '10': 'unsupported'
    },
  ],
  '8': [
    {'1': 'payload'},
  ],
};

/// Descriptor for `AgentEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentEventDescriptor = $convert.base64Decode(
    'CgpBZ2VudEV2ZW50EjEKBHR5cGUYASABKA4yHS5hZ2VudF90YWxrLnYxLkFnZW50RXZlbnRUeX'
    'BlUgR0eXBlEkAKCmNvbm5lY3Rpb24YCiABKAsyHi5hZ2VudF90YWxrLnYxLkNvbm5lY3Rpb25F'
    'dmVudEgAUgpjb25uZWN0aW9uElAKEHJlcXVlc3RfcHJvZ3Jlc3MYCyABKAsyIy5hZ2VudF90YW'
    'xrLnYxLlJlcXVlc3RQcm9ncmVzc0V2ZW50SABSD3JlcXVlc3RQcm9ncmVzcxI3CgdtZXNzYWdl'
    'GAwgASgLMhsuYWdlbnRfdGFsay52MS5NZXNzYWdlRXZlbnRIAFIHbWVzc2FnZRIuCgR0b29sGA'
    '0gASgLMhguYWdlbnRfdGFsay52MS5Ub29sRXZlbnRIAFIEdG9vbBI6CghhcHByb3ZhbBgOIAEo'
    'CzIcLmFnZW50X3RhbGsudjEuQXBwcm92YWxFdmVudEgAUghhcHByb3ZhbBJJCg1jbGFyaWZpY2'
    'F0aW9uGA8gASgLMiEuYWdlbnRfdGFsay52MS5DbGFyaWZpY2F0aW9uRXZlbnRIAFINY2xhcmlm'
    'aWNhdGlvbhJQChByZXF1ZXN0X3Rlcm1pbmFsGBAgASgLMiMuYWdlbnRfdGFsay52MS5SZXF1ZX'
    'N0VGVybWluYWxFdmVudEgAUg9yZXF1ZXN0VGVybWluYWwSQwoLdW5zdXBwb3J0ZWQYESABKAsy'
    'Hy5hZ2VudF90YWxrLnYxLlVuc3VwcG9ydGVkRXZlbnRIAFILdW5zdXBwb3J0ZWRCCQoHcGF5bG'
    '9hZA==');

@$core.Deprecated('Use eventEnvelopeDescriptor instead')
const EventEnvelope$json = {
  '1': 'EventEnvelope',
  '2': [
    {
      '1': 'protocol',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolVersion',
      '10': 'protocol'
    },
    {'1': 'event_id', '3': 2, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'connection_id', '3': 3, '4': 1, '5': 9, '10': 'connectionId'},
    {'1': 'device_id', '3': 4, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'conversation_id', '3': 5, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'session_id', '3': 6, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'request_id', '3': 7, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'sequence', '3': 8, '4': 1, '5': 4, '10': 'sequence'},
    {
      '1': 'occurred_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
    {
      '1': 'event',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.AgentEvent',
      '10': 'event'
    },
  ],
};

/// Descriptor for `EventEnvelope`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventEnvelopeDescriptor = $convert.base64Decode(
    'Cg1FdmVudEVudmVsb3BlEjoKCHByb3RvY29sGAEgASgLMh4uYWdlbnRfdGFsay52MS5Qcm90b2'
    'NvbFZlcnNpb25SCHByb3RvY29sEhkKCGV2ZW50X2lkGAIgASgJUgdldmVudElkEiMKDWNvbm5l'
    'Y3Rpb25faWQYAyABKAlSDGNvbm5lY3Rpb25JZBIbCglkZXZpY2VfaWQYBCABKAlSCGRldmljZU'
    'lkEicKD2NvbnZlcnNhdGlvbl9pZBgFIAEoCVIOY29udmVyc2F0aW9uSWQSHQoKc2Vzc2lvbl9p'
    'ZBgGIAEoCVIJc2Vzc2lvbklkEh0KCnJlcXVlc3RfaWQYByABKAlSCXJlcXVlc3RJZBIaCghzZX'
    'F1ZW5jZRgIIAEoBFIIc2VxdWVuY2USOwoLb2NjdXJyZWRfYXQYCSABKAsyGi5nb29nbGUucHJv'
    'dG9idWYuVGltZXN0YW1wUgpvY2N1cnJlZEF0Ei8KBWV2ZW50GAogASgLMhkuYWdlbnRfdGFsay'
    '52MS5BZ2VudEV2ZW50UgVldmVudA==');
