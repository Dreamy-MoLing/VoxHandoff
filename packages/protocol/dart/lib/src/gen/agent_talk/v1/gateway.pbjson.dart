// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/gateway.proto.

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

@$core.Deprecated('Use connectClientRequestDescriptor instead')
const ConnectClientRequest$json = {
  '1': 'ConnectClientRequest',
  '2': [
    {
      '1': 'handshake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.HandshakeOffer',
      '9': 0,
      '10': 'handshake'
    },
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'ack',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.Ack',
      '9': 0,
      '10': 'ack'
    },
    {
      '1': 'command',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ClientCommand',
      '9': 0,
      '10': 'command'
    },
    {
      '1': 'protocol_error',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolError',
      '9': 0,
      '10': 'protocolError'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ConnectClientRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectClientRequestDescriptor = $convert.base64Decode(
    'ChRDb25uZWN0Q2xpZW50UmVxdWVzdBI9CgloYW5kc2hha2UYASABKAsyHS5hZ2VudF90YWxrLn'
    'YxLkhhbmRzaGFrZU9mZmVySABSCWhhbmRzaGFrZRI4CgloZWFydGJlYXQYAiABKAsyGC5hZ2Vu'
    'dF90YWxrLnYxLkhlYXJ0YmVhdEgAUgloZWFydGJlYXQSJgoDYWNrGAMgASgLMhIuYWdlbnRfdG'
    'Fsay52MS5BY2tIAFIDYWNrEjgKB2NvbW1hbmQYBCABKAsyHC5hZ2VudF90YWxrLnYxLkNsaWVu'
    'dENvbW1hbmRIAFIHY29tbWFuZBJFCg5wcm90b2NvbF9lcnJvchgFIAEoCzIcLmFnZW50X3RhbG'
    'sudjEuUHJvdG9jb2xFcnJvckgAUg1wcm90b2NvbEVycm9yQgYKBGJvZHk=');

@$core.Deprecated('Use connectClientResponseDescriptor instead')
const ConnectClientResponse$json = {
  '1': 'ConnectClientResponse',
  '2': [
    {
      '1': 'handshake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.HandshakeAccepted',
      '9': 0,
      '10': 'handshake'
    },
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'event',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.EventEnvelope',
      '9': 0,
      '10': 'event'
    },
    {
      '1': 'request_status',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.RequestStatus',
      '9': 0,
      '10': 'requestStatus'
    },
    {
      '1': 'control_lease',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ControlLease',
      '9': 0,
      '10': 'controlLease'
    },
    {
      '1': 'protocol_error',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolError',
      '9': 0,
      '10': 'protocolError'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ConnectClientResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectClientResponseDescriptor = $convert.base64Decode(
    'ChVDb25uZWN0Q2xpZW50UmVzcG9uc2USQAoJaGFuZHNoYWtlGAEgASgLMiAuYWdlbnRfdGFsay'
    '52MS5IYW5kc2hha2VBY2NlcHRlZEgAUgloYW5kc2hha2USOAoJaGVhcnRiZWF0GAIgASgLMhgu'
    'YWdlbnRfdGFsay52MS5IZWFydGJlYXRIAFIJaGVhcnRiZWF0EjQKBWV2ZW50GAMgASgLMhwuYW'
    'dlbnRfdGFsay52MS5FdmVudEVudmVsb3BlSABSBWV2ZW50EkUKDnJlcXVlc3Rfc3RhdHVzGAQg'
    'ASgLMhwuYWdlbnRfdGFsay52MS5SZXF1ZXN0U3RhdHVzSABSDXJlcXVlc3RTdGF0dXMSQgoNY2'
    '9udHJvbF9sZWFzZRgFIAEoCzIbLmFnZW50X3RhbGsudjEuQ29udHJvbExlYXNlSABSDGNvbnRy'
    'b2xMZWFzZRJFCg5wcm90b2NvbF9lcnJvchgGIAEoCzIcLmFnZW50X3RhbGsudjEuUHJvdG9jb2'
    'xFcnJvckgAUg1wcm90b2NvbEVycm9yQgYKBGJvZHk=');

@$core.Deprecated('Use nodeDescriptorDescriptor instead')
const NodeDescriptor$json = {
  '1': 'NodeDescriptor',
  '2': [
    {'1': 'node_id', '3': 1, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'platform', '3': 3, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'version', '3': 4, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `NodeDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeDescriptorDescriptor = $convert.base64Decode(
    'Cg5Ob2RlRGVzY3JpcHRvchIXCgdub2RlX2lkGAEgASgJUgZub2RlSWQSIQoMZGlzcGxheV9uYW'
    '1lGAIgASgJUgtkaXNwbGF5TmFtZRIaCghwbGF0Zm9ybRgDIAEoCVIIcGxhdGZvcm0SGAoHdmVy'
    'c2lvbhgEIAEoCVIHdmVyc2lvbg==');

@$core.Deprecated('Use agentDescriptorDescriptor instead')
const AgentDescriptor$json = {
  '1': 'AgentDescriptor',
  '2': [
    {'1': 'agent_id', '3': 1, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'adapter', '3': 3, '4': 1, '5': 9, '10': 'adapter'},
    {'1': 'version', '3': 4, '4': 1, '5': 9, '10': 'version'},
    {
      '1': 'capability_revision',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'capabilityRevision'
    },
    {
      '1': 'capabilities',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.AgentCapabilities',
      '10': 'capabilities'
    },
  ],
};

/// Descriptor for `AgentDescriptor`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentDescriptorDescriptor = $convert.base64Decode(
    'Cg9BZ2VudERlc2NyaXB0b3ISGQoIYWdlbnRfaWQYASABKAlSB2FnZW50SWQSIQoMZGlzcGxheV'
    '9uYW1lGAIgASgJUgtkaXNwbGF5TmFtZRIYCgdhZGFwdGVyGAMgASgJUgdhZGFwdGVyEhgKB3Zl'
    'cnNpb24YBCABKAlSB3ZlcnNpb24SLwoTY2FwYWJpbGl0eV9yZXZpc2lvbhgFIAEoCVISY2FwYW'
    'JpbGl0eVJldmlzaW9uEkQKDGNhcGFiaWxpdGllcxgGIAEoCzIgLmFnZW50X3RhbGsudjEuQWdl'
    'bnRDYXBhYmlsaXRpZXNSDGNhcGFiaWxpdGllcw==');

@$core.Deprecated('Use nodeRegistrationDescriptor instead')
const NodeRegistration$json = {
  '1': 'NodeRegistration',
  '2': [
    {
      '1': 'node',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.NodeDescriptor',
      '10': 'node'
    },
    {
      '1': 'agents',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.agent_talk.v1.AgentDescriptor',
      '10': 'agents'
    },
  ],
};

/// Descriptor for `NodeRegistration`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List nodeRegistrationDescriptor = $convert.base64Decode(
    'ChBOb2RlUmVnaXN0cmF0aW9uEjEKBG5vZGUYASABKAsyHS5hZ2VudF90YWxrLnYxLk5vZGVEZX'
    'NjcmlwdG9yUgRub2RlEjYKBmFnZW50cxgCIAMoCzIeLmFnZW50X3RhbGsudjEuQWdlbnREZXNj'
    'cmlwdG9yUgZhZ2VudHM=');

@$core.Deprecated('Use dispatchRequestDescriptor instead')
const DispatchRequest$json = {
  '1': 'DispatchRequest',
  '2': [
    {'1': 'dispatch_id', '3': 1, '4': 1, '5': 9, '10': 'dispatchId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'idempotency_key', '3': 3, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {'1': 'conversation_id', '3': 4, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'session_id', '3': 5, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'node_id', '3': 6, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'agent_id', '3': 7, '4': 1, '5': 9, '10': 'agentId'},
    {
      '1': 'capability_revision',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'capabilityRevision'
    },
    {'1': 'confirmed_text', '3': 9, '4': 1, '5': 9, '10': 'confirmedText'},
  ],
};

/// Descriptor for `DispatchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dispatchRequestDescriptor = $convert.base64Decode(
    'Cg9EaXNwYXRjaFJlcXVlc3QSHwoLZGlzcGF0Y2hfaWQYASABKAlSCmRpc3BhdGNoSWQSHQoKcm'
    'VxdWVzdF9pZBgCIAEoCVIJcmVxdWVzdElkEicKD2lkZW1wb3RlbmN5X2tleRgDIAEoCVIOaWRl'
    'bXBvdGVuY3lLZXkSJwoPY29udmVyc2F0aW9uX2lkGAQgASgJUg5jb252ZXJzYXRpb25JZBIdCg'
    'pzZXNzaW9uX2lkGAUgASgJUglzZXNzaW9uSWQSFwoHbm9kZV9pZBgGIAEoCVIGbm9kZUlkEhkK'
    'CGFnZW50X2lkGAcgASgJUgdhZ2VudElkEi8KE2NhcGFiaWxpdHlfcmV2aXNpb24YCCABKAlSEm'
    'NhcGFiaWxpdHlSZXZpc2lvbhIlCg5jb25maXJtZWRfdGV4dBgJIAEoCVINY29uZmlybWVkVGV4'
    'dA==');

@$core.Deprecated('Use dispatchInterruptDescriptor instead')
const DispatchInterrupt$json = {
  '1': 'DispatchInterrupt',
  '2': [
    {'1': 'dispatch_id', '3': 1, '4': 1, '5': 9, '10': 'dispatchId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'idempotency_key', '3': 3, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `DispatchInterrupt`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dispatchInterruptDescriptor = $convert.base64Decode(
    'ChFEaXNwYXRjaEludGVycnVwdBIfCgtkaXNwYXRjaF9pZBgBIAEoCVIKZGlzcGF0Y2hJZBIdCg'
    'pyZXF1ZXN0X2lkGAIgASgJUglyZXF1ZXN0SWQSJwoPaWRlbXBvdGVuY3lfa2V5GAMgASgJUg5p'
    'ZGVtcG90ZW5jeUtleQ==');

@$core.Deprecated('Use dispatchApprovalDescriptor instead')
const DispatchApproval$json = {
  '1': 'DispatchApproval',
  '2': [
    {'1': 'dispatch_id', '3': 1, '4': 1, '5': 9, '10': 'dispatchId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'approval_id', '3': 3, '4': 1, '5': 9, '10': 'approvalId'},
    {'1': 'idempotency_key', '3': 4, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {
      '1': 'decision',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.ApprovalDecision',
      '10': 'decision'
    },
    {
      '1': 'operation_summary_sha256',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'operationSummarySha256'
    },
  ],
};

/// Descriptor for `DispatchApproval`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dispatchApprovalDescriptor = $convert.base64Decode(
    'ChBEaXNwYXRjaEFwcHJvdmFsEh8KC2Rpc3BhdGNoX2lkGAEgASgJUgpkaXNwYXRjaElkEh0KCn'
    'JlcXVlc3RfaWQYAiABKAlSCXJlcXVlc3RJZBIfCgthcHByb3ZhbF9pZBgDIAEoCVIKYXBwcm92'
    'YWxJZBInCg9pZGVtcG90ZW5jeV9rZXkYBCABKAlSDmlkZW1wb3RlbmN5S2V5EjsKCGRlY2lzaW'
    '9uGAUgASgOMh8uYWdlbnRfdGFsay52MS5BcHByb3ZhbERlY2lzaW9uUghkZWNpc2lvbhI4Chhv'
    'cGVyYXRpb25fc3VtbWFyeV9zaGEyNTYYBiABKAlSFm9wZXJhdGlvblN1bW1hcnlTaGEyNTY=');

@$core.Deprecated('Use dispatchClarificationDescriptor instead')
const DispatchClarification$json = {
  '1': 'DispatchClarification',
  '2': [
    {'1': 'dispatch_id', '3': 1, '4': 1, '5': 9, '10': 'dispatchId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'clarification_id', '3': 3, '4': 1, '5': 9, '10': 'clarificationId'},
    {'1': 'idempotency_key', '3': 4, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {'1': 'confirmed_text', '3': 5, '4': 1, '5': 9, '10': 'confirmedText'},
  ],
};

/// Descriptor for `DispatchClarification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dispatchClarificationDescriptor = $convert.base64Decode(
    'ChVEaXNwYXRjaENsYXJpZmljYXRpb24SHwoLZGlzcGF0Y2hfaWQYASABKAlSCmRpc3BhdGNoSW'
    'QSHQoKcmVxdWVzdF9pZBgCIAEoCVIJcmVxdWVzdElkEikKEGNsYXJpZmljYXRpb25faWQYAyAB'
    'KAlSD2NsYXJpZmljYXRpb25JZBInCg9pZGVtcG90ZW5jeV9rZXkYBCABKAlSDmlkZW1wb3Rlbm'
    'N5S2V5EiUKDmNvbmZpcm1lZF90ZXh0GAUgASgJUg1jb25maXJtZWRUZXh0');

@$core.Deprecated('Use dispatchAckDescriptor instead')
const DispatchAck$json = {
  '1': 'DispatchAck',
  '2': [
    {'1': 'dispatch_id', '3': 1, '4': 1, '5': 9, '10': 'dispatchId'},
    {'1': 'request_id', '3': 2, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'accepted', '3': 3, '4': 1, '5': 8, '10': 'accepted'},
    {
      '1': 'failure',
      '3': 4,
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

/// Descriptor for `DispatchAck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dispatchAckDescriptor = $convert.base64Decode(
    'CgtEaXNwYXRjaEFjaxIfCgtkaXNwYXRjaF9pZBgBIAEoCVIKZGlzcGF0Y2hJZBIdCgpyZXF1ZX'
    'N0X2lkGAIgASgJUglyZXF1ZXN0SWQSGgoIYWNjZXB0ZWQYAyABKAhSCGFjY2VwdGVkEjoKB2Zh'
    'aWx1cmUYBCABKAsyGy5hZ2VudF90YWxrLnYxLlN0YWdlRmFpbHVyZUgAUgdmYWlsdXJliAEBQg'
    'oKCF9mYWlsdXJl');

@$core.Deprecated('Use connectNodeRequestDescriptor instead')
const ConnectNodeRequest$json = {
  '1': 'ConnectNodeRequest',
  '2': [
    {
      '1': 'handshake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.HandshakeOffer',
      '9': 0,
      '10': 'handshake'
    },
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'registration',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.NodeRegistration',
      '9': 0,
      '10': 'registration'
    },
    {
      '1': 'dispatch_ack',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DispatchAck',
      '9': 0,
      '10': 'dispatchAck'
    },
    {
      '1': 'event',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.EventEnvelope',
      '9': 0,
      '10': 'event'
    },
    {
      '1': 'protocol_error',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolError',
      '9': 0,
      '10': 'protocolError'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ConnectNodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectNodeRequestDescriptor = $convert.base64Decode(
    'ChJDb25uZWN0Tm9kZVJlcXVlc3QSPQoJaGFuZHNoYWtlGAEgASgLMh0uYWdlbnRfdGFsay52MS'
    '5IYW5kc2hha2VPZmZlckgAUgloYW5kc2hha2USOAoJaGVhcnRiZWF0GAIgASgLMhguYWdlbnRf'
    'dGFsay52MS5IZWFydGJlYXRIAFIJaGVhcnRiZWF0EkUKDHJlZ2lzdHJhdGlvbhgDIAEoCzIfLm'
    'FnZW50X3RhbGsudjEuTm9kZVJlZ2lzdHJhdGlvbkgAUgxyZWdpc3RyYXRpb24SPwoMZGlzcGF0'
    'Y2hfYWNrGAQgASgLMhouYWdlbnRfdGFsay52MS5EaXNwYXRjaEFja0gAUgtkaXNwYXRjaEFjax'
    'I0CgVldmVudBgFIAEoCzIcLmFnZW50X3RhbGsudjEuRXZlbnRFbnZlbG9wZUgAUgVldmVudBJF'
    'Cg5wcm90b2NvbF9lcnJvchgGIAEoCzIcLmFnZW50X3RhbGsudjEuUHJvdG9jb2xFcnJvckgAUg'
    '1wcm90b2NvbEVycm9yQgYKBGJvZHk=');

@$core.Deprecated('Use connectNodeResponseDescriptor instead')
const ConnectNodeResponse$json = {
  '1': 'ConnectNodeResponse',
  '2': [
    {
      '1': 'handshake',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.HandshakeAccepted',
      '9': 0,
      '10': 'handshake'
    },
    {
      '1': 'heartbeat',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.Heartbeat',
      '9': 0,
      '10': 'heartbeat'
    },
    {
      '1': 'dispatch_request',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DispatchRequest',
      '9': 0,
      '10': 'dispatchRequest'
    },
    {
      '1': 'dispatch_interrupt',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DispatchInterrupt',
      '9': 0,
      '10': 'dispatchInterrupt'
    },
    {
      '1': 'dispatch_approval',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DispatchApproval',
      '9': 0,
      '10': 'dispatchApproval'
    },
    {
      '1': 'dispatch_clarification',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DispatchClarification',
      '9': 0,
      '10': 'dispatchClarification'
    },
    {
      '1': 'protocol_error',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolError',
      '9': 0,
      '10': 'protocolError'
    },
  ],
  '8': [
    {'1': 'body'},
  ],
};

/// Descriptor for `ConnectNodeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List connectNodeResponseDescriptor = $convert.base64Decode(
    'ChNDb25uZWN0Tm9kZVJlc3BvbnNlEkAKCWhhbmRzaGFrZRgBIAEoCzIgLmFnZW50X3RhbGsudj'
    'EuSGFuZHNoYWtlQWNjZXB0ZWRIAFIJaGFuZHNoYWtlEjgKCWhlYXJ0YmVhdBgCIAEoCzIYLmFn'
    'ZW50X3RhbGsudjEuSGVhcnRiZWF0SABSCWhlYXJ0YmVhdBJLChBkaXNwYXRjaF9yZXF1ZXN0GA'
    'MgASgLMh4uYWdlbnRfdGFsay52MS5EaXNwYXRjaFJlcXVlc3RIAFIPZGlzcGF0Y2hSZXF1ZXN0'
    'ElEKEmRpc3BhdGNoX2ludGVycnVwdBgEIAEoCzIgLmFnZW50X3RhbGsudjEuRGlzcGF0Y2hJbn'
    'RlcnJ1cHRIAFIRZGlzcGF0Y2hJbnRlcnJ1cHQSTgoRZGlzcGF0Y2hfYXBwcm92YWwYBSABKAsy'
    'Hy5hZ2VudF90YWxrLnYxLkRpc3BhdGNoQXBwcm92YWxIAFIQZGlzcGF0Y2hBcHByb3ZhbBJdCh'
    'ZkaXNwYXRjaF9jbGFyaWZpY2F0aW9uGAYgASgLMiQuYWdlbnRfdGFsay52MS5EaXNwYXRjaENs'
    'YXJpZmljYXRpb25IAFIVZGlzcGF0Y2hDbGFyaWZpY2F0aW9uEkUKDnByb3RvY29sX2Vycm9yGA'
    'cgASgLMhwuYWdlbnRfdGFsay52MS5Qcm90b2NvbEVycm9ySABSDXByb3RvY29sRXJyb3JCBgoE'
    'Ym9keQ==');

@$core.Deprecated('Use beginPairingRequestDescriptor instead')
const BeginPairingRequest$json = {
  '1': 'BeginPairingRequest',
  '2': [
    {
      '1': 'device_display_name',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'deviceDisplayName'
    },
    {
      '1': 'device_public_key',
      '3': 2,
      '4': 1,
      '5': 12,
      '10': 'devicePublicKey'
    },
    {'1': 'requested_scopes', '3': 3, '4': 3, '5': 9, '10': 'requestedScopes'},
    {
      '1': 'expected_gateway_audience',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'expectedGatewayAudience'
    },
  ],
};

/// Descriptor for `BeginPairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginPairingRequestDescriptor = $convert.base64Decode(
    'ChNCZWdpblBhaXJpbmdSZXF1ZXN0Ei4KE2RldmljZV9kaXNwbGF5X25hbWUYASABKAlSEWRldm'
    'ljZURpc3BsYXlOYW1lEioKEWRldmljZV9wdWJsaWNfa2V5GAIgASgMUg9kZXZpY2VQdWJsaWNL'
    'ZXkSKQoQcmVxdWVzdGVkX3Njb3BlcxgDIAMoCVIPcmVxdWVzdGVkU2NvcGVzEjoKGWV4cGVjdG'
    'VkX2dhdGV3YXlfYXVkaWVuY2UYBCABKAlSF2V4cGVjdGVkR2F0ZXdheUF1ZGllbmNl');

@$core.Deprecated('Use beginPairingResponseDescriptor instead')
const BeginPairingResponse$json = {
  '1': 'BeginPairingResponse',
  '2': [
    {'1': 'pairing_id', '3': 1, '4': 1, '5': 9, '10': 'pairingId'},
    {'1': 'user_code', '3': 2, '4': 1, '5': 9, '10': 'userCode'},
    {'1': 'verification_uri', '3': 3, '4': 1, '5': 9, '10': 'verificationUri'},
    {
      '1': 'expires_in_seconds',
      '3': 4,
      '4': 1,
      '5': 13,
      '10': 'expiresInSeconds'
    },
    {
      '1': 'device_proof_payload',
      '3': 5,
      '4': 1,
      '5': 12,
      '10': 'deviceProofPayload'
    },
    {
      '1': 'device_fingerprint',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'deviceFingerprint'
    },
    {
      '1': 'gateway_fingerprint',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'gatewayFingerprint'
    },
    {'1': 'gateway_audience', '3': 8, '4': 1, '5': 9, '10': 'gatewayAudience'},
  ],
};

/// Descriptor for `BeginPairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginPairingResponseDescriptor = $convert.base64Decode(
    'ChRCZWdpblBhaXJpbmdSZXNwb25zZRIdCgpwYWlyaW5nX2lkGAEgASgJUglwYWlyaW5nSWQSGw'
    'oJdXNlcl9jb2RlGAIgASgJUgh1c2VyQ29kZRIpChB2ZXJpZmljYXRpb25fdXJpGAMgASgJUg92'
    'ZXJpZmljYXRpb25VcmkSLAoSZXhwaXJlc19pbl9zZWNvbmRzGAQgASgNUhBleHBpcmVzSW5TZW'
    'NvbmRzEjAKFGRldmljZV9wcm9vZl9wYXlsb2FkGAUgASgMUhJkZXZpY2VQcm9vZlBheWxvYWQS'
    'LQoSZGV2aWNlX2ZpbmdlcnByaW50GAYgASgJUhFkZXZpY2VGaW5nZXJwcmludBIvChNnYXRld2'
    'F5X2ZpbmdlcnByaW50GAcgASgJUhJnYXRld2F5RmluZ2VycHJpbnQSKQoQZ2F0ZXdheV9hdWRp'
    'ZW5jZRgIIAEoCVIPZ2F0ZXdheUF1ZGllbmNl');

@$core.Deprecated('Use completePairingRequestDescriptor instead')
const CompletePairingRequest$json = {
  '1': 'CompletePairingRequest',
  '2': [
    {'1': 'pairing_id', '3': 1, '4': 1, '5': 9, '10': 'pairingId'},
    {'1': 'device_proof', '3': 2, '4': 1, '5': 9, '10': 'deviceProof'},
    {
      '1': 'device_key_proof',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DeviceSignature',
      '10': 'deviceKeyProof'
    },
  ],
};

/// Descriptor for `CompletePairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completePairingRequestDescriptor = $convert.base64Decode(
    'ChZDb21wbGV0ZVBhaXJpbmdSZXF1ZXN0Eh0KCnBhaXJpbmdfaWQYASABKAlSCXBhaXJpbmdJZB'
    'IhCgxkZXZpY2VfcHJvb2YYAiABKAlSC2RldmljZVByb29mEkgKEGRldmljZV9rZXlfcHJvb2YY'
    'AyABKAsyHi5hZ2VudF90YWxrLnYxLkRldmljZVNpZ25hdHVyZVIOZGV2aWNlS2V5UHJvb2Y=');

@$core.Deprecated('Use completePairingResponseDescriptor instead')
const CompletePairingResponse$json = {
  '1': 'CompletePairingResponse',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'access_token', '3': 2, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 3, '4': 1, '5': 9, '10': 'refreshToken'},
    {'1': 'scopes', '3': 4, '4': 3, '5': 9, '10': 'scopes'},
    {'1': 'credential_id', '3': 5, '4': 1, '5': 9, '10': 'credentialId'},
    {
      '1': 'confirmation_payload',
      '3': 6,
      '4': 1,
      '5': 12,
      '10': 'confirmationPayload'
    },
    {'1': 'gateway_audience', '3': 7, '4': 1, '5': 9, '10': 'gatewayAudience'},
    {
      '1': 'confirmation_expires_in_seconds',
      '3': 8,
      '4': 1,
      '5': 13,
      '10': 'confirmationExpiresInSeconds'
    },
  ],
};

/// Descriptor for `CompletePairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completePairingResponseDescriptor = $convert.base64Decode(
    'ChdDb21wbGV0ZVBhaXJpbmdSZXNwb25zZRIbCglkZXZpY2VfaWQYASABKAlSCGRldmljZUlkEi'
    'EKDGFjY2Vzc190b2tlbhgCIAEoCVILYWNjZXNzVG9rZW4SIwoNcmVmcmVzaF90b2tlbhgDIAEo'
    'CVIMcmVmcmVzaFRva2VuEhYKBnNjb3BlcxgEIAMoCVIGc2NvcGVzEiMKDWNyZWRlbnRpYWxfaW'
    'QYBSABKAlSDGNyZWRlbnRpYWxJZBIxChRjb25maXJtYXRpb25fcGF5bG9hZBgGIAEoDFITY29u'
    'ZmlybWF0aW9uUGF5bG9hZBIpChBnYXRld2F5X2F1ZGllbmNlGAcgASgJUg9nYXRld2F5QXVkaW'
    'VuY2USRQofY29uZmlybWF0aW9uX2V4cGlyZXNfaW5fc2Vjb25kcxgIIAEoDVIcY29uZmlybWF0'
    'aW9uRXhwaXJlc0luU2Vjb25kcw==');

@$core.Deprecated('Use inspectPairingRequestDescriptor instead')
const InspectPairingRequest$json = {
  '1': 'InspectPairingRequest',
  '2': [
    {'1': 'user_code', '3': 1, '4': 1, '5': 9, '10': 'userCode'},
  ],
};

/// Descriptor for `InspectPairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inspectPairingRequestDescriptor = $convert.base64Decode(
    'ChVJbnNwZWN0UGFpcmluZ1JlcXVlc3QSGwoJdXNlcl9jb2RlGAEgASgJUgh1c2VyQ29kZQ==');

@$core.Deprecated('Use inspectPairingResponseDescriptor instead')
const InspectPairingResponse$json = {
  '1': 'InspectPairingResponse',
  '2': [
    {'1': 'pairing_id', '3': 1, '4': 1, '5': 9, '10': 'pairingId'},
    {
      '1': 'device_display_name',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'deviceDisplayName'
    },
    {
      '1': 'device_fingerprint',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'deviceFingerprint'
    },
    {
      '1': 'gateway_fingerprint',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'gatewayFingerprint'
    },
    {'1': 'gateway_audience', '3': 5, '4': 1, '5': 9, '10': 'gatewayAudience'},
    {'1': 'requested_scopes', '3': 6, '4': 3, '5': 9, '10': 'requestedScopes'},
    {
      '1': 'expires_in_seconds',
      '3': 7,
      '4': 1,
      '5': 13,
      '10': 'expiresInSeconds'
    },
  ],
};

/// Descriptor for `InspectPairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inspectPairingResponseDescriptor = $convert.base64Decode(
    'ChZJbnNwZWN0UGFpcmluZ1Jlc3BvbnNlEh0KCnBhaXJpbmdfaWQYASABKAlSCXBhaXJpbmdJZB'
    'IuChNkZXZpY2VfZGlzcGxheV9uYW1lGAIgASgJUhFkZXZpY2VEaXNwbGF5TmFtZRItChJkZXZp'
    'Y2VfZmluZ2VycHJpbnQYAyABKAlSEWRldmljZUZpbmdlcnByaW50Ei8KE2dhdGV3YXlfZmluZ2'
    'VycHJpbnQYBCABKAlSEmdhdGV3YXlGaW5nZXJwcmludBIpChBnYXRld2F5X2F1ZGllbmNlGAUg'
    'ASgJUg9nYXRld2F5QXVkaWVuY2USKQoQcmVxdWVzdGVkX3Njb3BlcxgGIAMoCVIPcmVxdWVzdG'
    'VkU2NvcGVzEiwKEmV4cGlyZXNfaW5fc2Vjb25kcxgHIAEoDVIQZXhwaXJlc0luU2Vjb25kcw==');

@$core.Deprecated('Use approvePairingRequestDescriptor instead')
const ApprovePairingRequest$json = {
  '1': 'ApprovePairingRequest',
  '2': [
    {'1': 'pairing_id', '3': 1, '4': 1, '5': 9, '10': 'pairingId'},
    {'1': 'user_code', '3': 2, '4': 1, '5': 9, '10': 'userCode'},
    {'1': 'approved_scopes', '3': 3, '4': 3, '5': 9, '10': 'approvedScopes'},
    {
      '1': 'expected_device_fingerprint',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'expectedDeviceFingerprint'
    },
    {
      '1': 'expected_gateway_fingerprint',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'expectedGatewayFingerprint'
    },
    {
      '1': 'expected_gateway_audience',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'expectedGatewayAudience'
    },
    {
      '1': 'administrator_signature',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DeviceSignature',
      '10': 'administratorSignature'
    },
  ],
};

/// Descriptor for `ApprovePairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvePairingRequestDescriptor = $convert.base64Decode(
    'ChVBcHByb3ZlUGFpcmluZ1JlcXVlc3QSHQoKcGFpcmluZ19pZBgBIAEoCVIJcGFpcmluZ0lkEh'
    'sKCXVzZXJfY29kZRgCIAEoCVIIdXNlckNvZGUSJwoPYXBwcm92ZWRfc2NvcGVzGAMgAygJUg5h'
    'cHByb3ZlZFNjb3BlcxI+ChtleHBlY3RlZF9kZXZpY2VfZmluZ2VycHJpbnQYBCABKAlSGWV4cG'
    'VjdGVkRGV2aWNlRmluZ2VycHJpbnQSQAocZXhwZWN0ZWRfZ2F0ZXdheV9maW5nZXJwcmludBgF'
    'IAEoCVIaZXhwZWN0ZWRHYXRld2F5RmluZ2VycHJpbnQSOgoZZXhwZWN0ZWRfZ2F0ZXdheV9hdW'
    'RpZW5jZRgGIAEoCVIXZXhwZWN0ZWRHYXRld2F5QXVkaWVuY2USVwoXYWRtaW5pc3RyYXRvcl9z'
    'aWduYXR1cmUYByABKAsyHi5hZ2VudF90YWxrLnYxLkRldmljZVNpZ25hdHVyZVIWYWRtaW5pc3'
    'RyYXRvclNpZ25hdHVyZQ==');

@$core.Deprecated('Use approvePairingResponseDescriptor instead')
const ApprovePairingResponse$json = {
  '1': 'ApprovePairingResponse',
  '2': [
    {'1': 'approved', '3': 1, '4': 1, '5': 8, '10': 'approved'},
    {
      '1': 'expires_in_seconds',
      '3': 2,
      '4': 1,
      '5': 13,
      '10': 'expiresInSeconds'
    },
  ],
};

/// Descriptor for `ApprovePairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List approvePairingResponseDescriptor =
    $convert.base64Decode(
        'ChZBcHByb3ZlUGFpcmluZ1Jlc3BvbnNlEhoKCGFwcHJvdmVkGAEgASgIUghhcHByb3ZlZBIsCh'
        'JleHBpcmVzX2luX3NlY29uZHMYAiABKA1SEGV4cGlyZXNJblNlY29uZHM=');

@$core.Deprecated('Use confirmPairingRequestDescriptor instead')
const ConfirmPairingRequest$json = {
  '1': 'ConfirmPairingRequest',
  '2': [
    {'1': 'pairing_id', '3': 1, '4': 1, '5': 9, '10': 'pairingId'},
    {'1': 'credential_id', '3': 2, '4': 1, '5': 9, '10': 'credentialId'},
    {
      '1': 'device_signature',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DeviceSignature',
      '10': 'deviceSignature'
    },
  ],
};

/// Descriptor for `ConfirmPairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmPairingRequestDescriptor = $convert.base64Decode(
    'ChVDb25maXJtUGFpcmluZ1JlcXVlc3QSHQoKcGFpcmluZ19pZBgBIAEoCVIJcGFpcmluZ0lkEi'
    'MKDWNyZWRlbnRpYWxfaWQYAiABKAlSDGNyZWRlbnRpYWxJZBJJChBkZXZpY2Vfc2lnbmF0dXJl'
    'GAMgASgLMh4uYWdlbnRfdGFsay52MS5EZXZpY2VTaWduYXR1cmVSD2RldmljZVNpZ25hdHVyZQ'
    '==');

@$core.Deprecated('Use confirmPairingResponseDescriptor instead')
const ConfirmPairingResponse$json = {
  '1': 'ConfirmPairingResponse',
  '2': [
    {'1': 'paired', '3': 1, '4': 1, '5': 8, '10': 'paired'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'credential_id', '3': 3, '4': 1, '5': 9, '10': 'credentialId'},
    {'1': 'access_token', '3': 4, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 5, '4': 1, '5': 9, '10': 'refreshToken'},
    {'1': 'scopes', '3': 6, '4': 3, '5': 9, '10': 'scopes'},
    {
      '1': 'access_expires_at_unix_ms',
      '3': 7,
      '4': 1,
      '5': 4,
      '10': 'accessExpiresAtUnixMs'
    },
    {
      '1': 'refresh_expires_at_unix_ms',
      '3': 8,
      '4': 1,
      '5': 4,
      '10': 'refreshExpiresAtUnixMs'
    },
    {'1': 'gateway_audience', '3': 9, '4': 1, '5': 9, '10': 'gatewayAudience'},
  ],
};

/// Descriptor for `ConfirmPairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmPairingResponseDescriptor = $convert.base64Decode(
    'ChZDb25maXJtUGFpcmluZ1Jlc3BvbnNlEhYKBnBhaXJlZBgBIAEoCFIGcGFpcmVkEhsKCWRldm'
    'ljZV9pZBgCIAEoCVIIZGV2aWNlSWQSIwoNY3JlZGVudGlhbF9pZBgDIAEoCVIMY3JlZGVudGlh'
    'bElkEiEKDGFjY2Vzc190b2tlbhgEIAEoCVILYWNjZXNzVG9rZW4SIwoNcmVmcmVzaF90b2tlbh'
    'gFIAEoCVIMcmVmcmVzaFRva2VuEhYKBnNjb3BlcxgGIAMoCVIGc2NvcGVzEjgKGWFjY2Vzc19l'
    'eHBpcmVzX2F0X3VuaXhfbXMYByABKARSFWFjY2Vzc0V4cGlyZXNBdFVuaXhNcxI6ChpyZWZyZX'
    'NoX2V4cGlyZXNfYXRfdW5peF9tcxgIIAEoBFIWcmVmcmVzaEV4cGlyZXNBdFVuaXhNcxIpChBn'
    'YXRld2F5X2F1ZGllbmNlGAkgASgJUg9nYXRld2F5QXVkaWVuY2U=');

@$core.Deprecated('Use refreshDeviceCredentialRequestDescriptor instead')
const RefreshDeviceCredentialRequest$json = {
  '1': 'RefreshDeviceCredentialRequest',
  '2': [
    {'1': 'credential_id', '3': 1, '4': 1, '5': 9, '10': 'credentialId'},
    {'1': 'refresh_token', '3': 2, '4': 1, '5': 9, '10': 'refreshToken'},
    {
      '1': 'device_signature',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DeviceSignature',
      '10': 'deviceSignature'
    },
  ],
};

/// Descriptor for `RefreshDeviceCredentialRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshDeviceCredentialRequestDescriptor =
    $convert.base64Decode(
        'Ch5SZWZyZXNoRGV2aWNlQ3JlZGVudGlhbFJlcXVlc3QSIwoNY3JlZGVudGlhbF9pZBgBIAEoCV'
        'IMY3JlZGVudGlhbElkEiMKDXJlZnJlc2hfdG9rZW4YAiABKAlSDHJlZnJlc2hUb2tlbhJJChBk'
        'ZXZpY2Vfc2lnbmF0dXJlGAMgASgLMh4uYWdlbnRfdGFsay52MS5EZXZpY2VTaWduYXR1cmVSD2'
        'RldmljZVNpZ25hdHVyZQ==');

@$core.Deprecated('Use refreshDeviceCredentialResponseDescriptor instead')
const RefreshDeviceCredentialResponse$json = {
  '1': 'RefreshDeviceCredentialResponse',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'credential_id', '3': 2, '4': 1, '5': 9, '10': 'credentialId'},
    {'1': 'access_token', '3': 3, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 4, '4': 1, '5': 9, '10': 'refreshToken'},
    {'1': 'scopes', '3': 5, '4': 3, '5': 9, '10': 'scopes'},
    {
      '1': 'access_expires_at_unix_ms',
      '3': 6,
      '4': 1,
      '5': 4,
      '10': 'accessExpiresAtUnixMs'
    },
    {
      '1': 'refresh_expires_at_unix_ms',
      '3': 7,
      '4': 1,
      '5': 4,
      '10': 'refreshExpiresAtUnixMs'
    },
    {'1': 'gateway_audience', '3': 8, '4': 1, '5': 9, '10': 'gatewayAudience'},
  ],
};

/// Descriptor for `RefreshDeviceCredentialResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshDeviceCredentialResponseDescriptor = $convert.base64Decode(
    'Ch9SZWZyZXNoRGV2aWNlQ3JlZGVudGlhbFJlc3BvbnNlEhsKCWRldmljZV9pZBgBIAEoCVIIZG'
    'V2aWNlSWQSIwoNY3JlZGVudGlhbF9pZBgCIAEoCVIMY3JlZGVudGlhbElkEiEKDGFjY2Vzc190'
    'b2tlbhgDIAEoCVILYWNjZXNzVG9rZW4SIwoNcmVmcmVzaF90b2tlbhgEIAEoCVIMcmVmcmVzaF'
    'Rva2VuEhYKBnNjb3BlcxgFIAMoCVIGc2NvcGVzEjgKGWFjY2Vzc19leHBpcmVzX2F0X3VuaXhf'
    'bXMYBiABKARSFWFjY2Vzc0V4cGlyZXNBdFVuaXhNcxI6ChpyZWZyZXNoX2V4cGlyZXNfYXRfdW'
    '5peF9tcxgHIAEoBFIWcmVmcmVzaEV4cGlyZXNBdFVuaXhNcxIpChBnYXRld2F5X2F1ZGllbmNl'
    'GAggASgJUg9nYXRld2F5QXVkaWVuY2U=');

@$core.Deprecated('Use revokeDeviceRequestDescriptor instead')
const RevokeDeviceRequest$json = {
  '1': 'RevokeDeviceRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'reason_code', '3': 2, '4': 1, '5': 9, '10': 'reasonCode'},
    {
      '1': 'administrator_signature',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.DeviceSignature',
      '10': 'administratorSignature'
    },
  ],
};

/// Descriptor for `RevokeDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeDeviceRequestDescriptor = $convert.base64Decode(
    'ChNSZXZva2VEZXZpY2VSZXF1ZXN0EhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQSHwoLcm'
    'Vhc29uX2NvZGUYAiABKAlSCnJlYXNvbkNvZGUSVwoXYWRtaW5pc3RyYXRvcl9zaWduYXR1cmUY'
    'AyABKAsyHi5hZ2VudF90YWxrLnYxLkRldmljZVNpZ25hdHVyZVIWYWRtaW5pc3RyYXRvclNpZ2'
    '5hdHVyZQ==');

@$core.Deprecated('Use revokeDeviceResponseDescriptor instead')
const RevokeDeviceResponse$json = {
  '1': 'RevokeDeviceResponse',
  '2': [
    {'1': 'revoked', '3': 1, '4': 1, '5': 8, '10': 'revoked'},
  ],
};

/// Descriptor for `RevokeDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeDeviceResponseDescriptor =
    $convert.base64Decode(
        'ChRSZXZva2VEZXZpY2VSZXNwb25zZRIYCgdyZXZva2VkGAEgASgIUgdyZXZva2Vk');
