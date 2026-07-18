// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/control.proto.

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

@$core.Deprecated('Use approvalDecisionDescriptor instead')
const ApprovalDecision$json = {
  '1': 'ApprovalDecision',
  '2': [
    {'1': 'APPROVAL_DECISION_UNSPECIFIED', '2': 0},
    {'1': 'APPROVAL_DECISION_APPROVE', '2': 1},
    {'1': 'APPROVAL_DECISION_DENY', '2': 2},
  ],
};

/// Descriptor for `ApprovalDecision`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List approvalDecisionDescriptor = $convert.base64Decode(
    'ChBBcHByb3ZhbERlY2lzaW9uEiEKHUFQUFJPVkFMX0RFQ0lTSU9OX1VOU1BFQ0lGSUVEEAASHQ'
    'oZQVBQUk9WQUxfREVDSVNJT05fQVBQUk9WRRABEhoKFkFQUFJPVkFMX0RFQ0lTSU9OX0RFTlkQ'
    'Ag==');

@$core.Deprecated('Use handshakeOfferDescriptor instead')
const HandshakeOffer$json = {
  '1': 'HandshakeOffer',
  '2': [
    {
      '1': 'current_protocol',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolVersion',
      '10': 'currentProtocol'
    },
    {
      '1': 'accepted_protocols',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolVersionRange',
      '10': 'acceptedProtocols'
    },
    {'1': 'schema_build', '3': 3, '4': 1, '5': 9, '10': 'schemaBuild'},
    {'1': 'schema_sha256', '3': 4, '4': 1, '5': 9, '10': 'schemaSha256'},
    {
      '1': 'component_version',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'componentVersion'
    },
    {
      '1': 'component_role',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.ComponentRole',
      '10': 'componentRole'
    },
    {
      '1': 'capability_revision',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'capabilityRevision'
    },
    {
      '1': 'capabilities',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.AgentCapabilities',
      '10': 'capabilities'
    },
    {'1': 'scopes', '3': 9, '4': 3, '5': 9, '10': 'scopes'},
  ],
};

/// Descriptor for `HandshakeOffer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List handshakeOfferDescriptor = $convert.base64Decode(
    'Cg5IYW5kc2hha2VPZmZlchJJChBjdXJyZW50X3Byb3RvY29sGAEgASgLMh4uYWdlbnRfdGFsay'
    '52MS5Qcm90b2NvbFZlcnNpb25SD2N1cnJlbnRQcm90b2NvbBJSChJhY2NlcHRlZF9wcm90b2Nv'
    'bHMYAiABKAsyIy5hZ2VudF90YWxrLnYxLlByb3RvY29sVmVyc2lvblJhbmdlUhFhY2NlcHRlZF'
    'Byb3RvY29scxIhCgxzY2hlbWFfYnVpbGQYAyABKAlSC3NjaGVtYUJ1aWxkEiMKDXNjaGVtYV9z'
    'aGEyNTYYBCABKAlSDHNjaGVtYVNoYTI1NhIrChFjb21wb25lbnRfdmVyc2lvbhgFIAEoCVIQY2'
    '9tcG9uZW50VmVyc2lvbhJDCg5jb21wb25lbnRfcm9sZRgGIAEoDjIcLmFnZW50X3RhbGsudjEu'
    'Q29tcG9uZW50Um9sZVINY29tcG9uZW50Um9sZRIvChNjYXBhYmlsaXR5X3JldmlzaW9uGAcgAS'
    'gJUhJjYXBhYmlsaXR5UmV2aXNpb24SRAoMY2FwYWJpbGl0aWVzGAggASgLMiAuYWdlbnRfdGFs'
    'ay52MS5BZ2VudENhcGFiaWxpdGllc1IMY2FwYWJpbGl0aWVzEhYKBnNjb3BlcxgJIAMoCVIGc2'
    'NvcGVz');

@$core.Deprecated('Use handshakeAcceptedDescriptor instead')
const HandshakeAccepted$json = {
  '1': 'HandshakeAccepted',
  '2': [
    {
      '1': 'selected_protocol',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolVersion',
      '10': 'selectedProtocol'
    },
    {'1': 'connection_id', '3': 2, '4': 1, '5': 9, '10': 'connectionId'},
    {'1': 'schema_build', '3': 3, '4': 1, '5': 9, '10': 'schemaBuild'},
    {'1': 'schema_sha256', '3': 4, '4': 1, '5': 9, '10': 'schemaSha256'},
    {
      '1': 'component_version',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'componentVersion'
    },
    {
      '1': 'component_role',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.ComponentRole',
      '10': 'componentRole'
    },
    {
      '1': 'capability_revision',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'capabilityRevision'
    },
    {
      '1': 'capabilities',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.AgentCapabilities',
      '10': 'capabilities'
    },
    {'1': 'scopes', '3': 9, '4': 3, '5': 9, '10': 'scopes'},
  ],
};

/// Descriptor for `HandshakeAccepted`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List handshakeAcceptedDescriptor = $convert.base64Decode(
    'ChFIYW5kc2hha2VBY2NlcHRlZBJLChFzZWxlY3RlZF9wcm90b2NvbBgBIAEoCzIeLmFnZW50X3'
    'RhbGsudjEuUHJvdG9jb2xWZXJzaW9uUhBzZWxlY3RlZFByb3RvY29sEiMKDWNvbm5lY3Rpb25f'
    'aWQYAiABKAlSDGNvbm5lY3Rpb25JZBIhCgxzY2hlbWFfYnVpbGQYAyABKAlSC3NjaGVtYUJ1aW'
    'xkEiMKDXNjaGVtYV9zaGEyNTYYBCABKAlSDHNjaGVtYVNoYTI1NhIrChFjb21wb25lbnRfdmVy'
    'c2lvbhgFIAEoCVIQY29tcG9uZW50VmVyc2lvbhJDCg5jb21wb25lbnRfcm9sZRgGIAEoDjIcLm'
    'FnZW50X3RhbGsudjEuQ29tcG9uZW50Um9sZVINY29tcG9uZW50Um9sZRIvChNjYXBhYmlsaXR5'
    'X3JldmlzaW9uGAcgASgJUhJjYXBhYmlsaXR5UmV2aXNpb24SRAoMY2FwYWJpbGl0aWVzGAggAS'
    'gLMiAuYWdlbnRfdGFsay52MS5BZ2VudENhcGFiaWxpdGllc1IMY2FwYWJpbGl0aWVzEhYKBnNj'
    'b3BlcxgJIAMoCVIGc2NvcGVz');

@$core.Deprecated('Use protocolErrorDescriptor instead')
const ProtocolError$json = {
  '1': 'ProtocolError',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'safe_message', '3': 2, '4': 1, '5': 9, '10': 'safeMessage'},
    {
      '1': 'local_protocol',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolVersion',
      '10': 'localProtocol'
    },
    {
      '1': 'remote_protocol',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ProtocolVersion',
      '10': 'remoteProtocol'
    },
    {'1': 'retryable', '3': 5, '4': 1, '5': 8, '10': 'retryable'},
  ],
};

/// Descriptor for `ProtocolError`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolErrorDescriptor = $convert.base64Decode(
    'Cg1Qcm90b2NvbEVycm9yEhIKBGNvZGUYASABKAlSBGNvZGUSIQoMc2FmZV9tZXNzYWdlGAIgAS'
    'gJUgtzYWZlTWVzc2FnZRJFCg5sb2NhbF9wcm90b2NvbBgDIAEoCzIeLmFnZW50X3RhbGsudjEu'
    'UHJvdG9jb2xWZXJzaW9uUg1sb2NhbFByb3RvY29sEkcKD3JlbW90ZV9wcm90b2NvbBgEIAEoCz'
    'IeLmFnZW50X3RhbGsudjEuUHJvdG9jb2xWZXJzaW9uUg5yZW1vdGVQcm90b2NvbBIcCglyZXRy'
    'eWFibGUYBSABKAhSCXJldHJ5YWJsZQ==');

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {
      '1': 'sent_at',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'sentAt'
    },
    {
      '1': 'last_received_sequence',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'lastReceivedSequence'
    },
  ],
};

/// Descriptor for `Heartbeat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List heartbeatDescriptor = $convert.base64Decode(
    'CglIZWFydGJlYXQSMwoHc2VudF9hdBgBIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbX'
    'BSBnNlbnRBdBI0ChZsYXN0X3JlY2VpdmVkX3NlcXVlbmNlGAIgASgEUhRsYXN0UmVjZWl2ZWRT'
    'ZXF1ZW5jZQ==');

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'conversation_id', '3': 1, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'sequence', '3': 2, '4': 1, '5': 4, '10': 'sequence'},
    {'1': 'event_id', '3': 3, '4': 1, '5': 9, '10': 'eventId'},
  ],
};

/// Descriptor for `Ack`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List ackDescriptor = $convert.base64Decode(
    'CgNBY2sSJwoPY29udmVyc2F0aW9uX2lkGAEgASgJUg5jb252ZXJzYXRpb25JZBIaCghzZXF1ZW'
    '5jZRgCIAEoBFIIc2VxdWVuY2USGQoIZXZlbnRfaWQYAyABKAlSB2V2ZW50SWQ=');

@$core.Deprecated('Use sendRequestDescriptor instead')
const SendRequest$json = {
  '1': 'SendRequest',
  '2': [
    {'1': 'agent_id', '3': 1, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'node_id', '3': 2, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'session_id', '3': 3, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'confirmed_text', '3': 4, '4': 1, '5': 9, '10': 'confirmedText'},
    {
      '1': 'capability_revision',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'capabilityRevision'
    },
  ],
};

/// Descriptor for `SendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendRequestDescriptor = $convert.base64Decode(
    'CgtTZW5kUmVxdWVzdBIZCghhZ2VudF9pZBgBIAEoCVIHYWdlbnRJZBIXCgdub2RlX2lkGAIgAS'
    'gJUgZub2RlSWQSHQoKc2Vzc2lvbl9pZBgDIAEoCVIJc2Vzc2lvbklkEiUKDmNvbmZpcm1lZF90'
    'ZXh0GAQgASgJUg1jb25maXJtZWRUZXh0Ei8KE2NhcGFiaWxpdHlfcmV2aXNpb24YBSABKAlSEm'
    'NhcGFiaWxpdHlSZXZpc2lvbg==');

@$core.Deprecated('Use interruptRequestDescriptor instead')
const InterruptRequest$json = {
  '1': 'InterruptRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
  ],
};

/// Descriptor for `InterruptRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List interruptRequestDescriptor = $convert.base64Decode(
    'ChBJbnRlcnJ1cHRSZXF1ZXN0Eh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZA==');

@$core.Deprecated('Use resolveApprovalDescriptor instead')
const ResolveApproval$json = {
  '1': 'ResolveApproval',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'approval_id', '3': 2, '4': 1, '5': 9, '10': 'approvalId'},
    {
      '1': 'decision',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.ApprovalDecision',
      '10': 'decision'
    },
    {
      '1': 'operation_summary_sha256',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'operationSummarySha256'
    },
  ],
};

/// Descriptor for `ResolveApproval`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolveApprovalDescriptor = $convert.base64Decode(
    'Cg9SZXNvbHZlQXBwcm92YWwSHQoKcmVxdWVzdF9pZBgBIAEoCVIJcmVxdWVzdElkEh8KC2FwcH'
    'JvdmFsX2lkGAIgASgJUgphcHByb3ZhbElkEjsKCGRlY2lzaW9uGAMgASgOMh8uYWdlbnRfdGFs'
    'ay52MS5BcHByb3ZhbERlY2lzaW9uUghkZWNpc2lvbhI4ChhvcGVyYXRpb25fc3VtbWFyeV9zaG'
    'EyNTYYBCABKAlSFm9wZXJhdGlvblN1bW1hcnlTaGEyNTY=');

@$core.Deprecated('Use resolveClarificationDescriptor instead')
const ResolveClarification$json = {
  '1': 'ResolveClarification',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'clarification_id', '3': 2, '4': 1, '5': 9, '10': 'clarificationId'},
    {'1': 'confirmed_text', '3': 3, '4': 1, '5': 9, '10': 'confirmedText'},
  ],
};

/// Descriptor for `ResolveClarification`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolveClarificationDescriptor = $convert.base64Decode(
    'ChRSZXNvbHZlQ2xhcmlmaWNhdGlvbhIdCgpyZXF1ZXN0X2lkGAEgASgJUglyZXF1ZXN0SWQSKQ'
    'oQY2xhcmlmaWNhdGlvbl9pZBgCIAEoCVIPY2xhcmlmaWNhdGlvbklkEiUKDmNvbmZpcm1lZF90'
    'ZXh0GAMgASgJUg1jb25maXJtZWRUZXh0');

@$core.Deprecated('Use acquireControlLeaseDescriptor instead')
const AcquireControlLease$json = {
  '1': 'AcquireControlLease',
  '2': [
    {'1': 'expected_lease_id', '3': 1, '4': 1, '5': 9, '10': 'expectedLeaseId'},
    {
      '1': 'expected_revision',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'expectedRevision'
    },
    {
      '1': 'explicit_takeover',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'explicitTakeover'
    },
  ],
};

/// Descriptor for `AcquireControlLease`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acquireControlLeaseDescriptor = $convert.base64Decode(
    'ChNBY3F1aXJlQ29udHJvbExlYXNlEioKEWV4cGVjdGVkX2xlYXNlX2lkGAEgASgJUg9leHBlY3'
    'RlZExlYXNlSWQSKwoRZXhwZWN0ZWRfcmV2aXNpb24YAiABKARSEGV4cGVjdGVkUmV2aXNpb24S'
    'KwoRZXhwbGljaXRfdGFrZW92ZXIYAyABKAhSEGV4cGxpY2l0VGFrZW92ZXI=');

@$core.Deprecated('Use renewControlLeaseDescriptor instead')
const RenewControlLease$json = {
  '1': 'RenewControlLease',
  '2': [
    {'1': 'lease_id', '3': 1, '4': 1, '5': 9, '10': 'leaseId'},
    {
      '1': 'expected_revision',
      '3': 2,
      '4': 1,
      '5': 4,
      '10': 'expectedRevision'
    },
  ],
};

/// Descriptor for `RenewControlLease`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renewControlLeaseDescriptor = $convert.base64Decode(
    'ChFSZW5ld0NvbnRyb2xMZWFzZRIZCghsZWFzZV9pZBgBIAEoCVIHbGVhc2VJZBIrChFleHBlY3'
    'RlZF9yZXZpc2lvbhgCIAEoBFIQZXhwZWN0ZWRSZXZpc2lvbg==');

@$core.Deprecated('Use replayEventsDescriptor instead')
const ReplayEvents$json = {
  '1': 'ReplayEvents',
  '2': [
    {'1': 'after_sequence', '3': 1, '4': 1, '5': 4, '10': 'afterSequence'},
    {'1': 'maximum_events', '3': 2, '4': 1, '5': 13, '10': 'maximumEvents'},
  ],
};

/// Descriptor for `ReplayEvents`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replayEventsDescriptor = $convert.base64Decode(
    'CgxSZXBsYXlFdmVudHMSJQoOYWZ0ZXJfc2VxdWVuY2UYASABKARSDWFmdGVyU2VxdWVuY2USJQ'
    'oObWF4aW11bV9ldmVudHMYAiABKA1SDW1heGltdW1FdmVudHM=');

@$core.Deprecated('Use getRequestDescriptor instead')
const GetRequest$json = {
  '1': 'GetRequest',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
  ],
};

/// Descriptor for `GetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRequestDescriptor = $convert.base64Decode(
    'CgpHZXRSZXF1ZXN0Eh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZA==');

@$core.Deprecated('Use clientCommandDescriptor instead')
const ClientCommand$json = {
  '1': 'ClientCommand',
  '2': [
    {'1': 'command_id', '3': 1, '4': 1, '5': 9, '10': 'commandId'},
    {'1': 'idempotency_key', '3': 2, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {'1': 'conversation_id', '3': 3, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'lease_id', '3': 4, '4': 1, '5': 9, '10': 'leaseId'},
    {'1': 'lease_revision', '3': 5, '4': 1, '5': 4, '10': 'leaseRevision'},
    {
      '1': 'send',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.SendRequest',
      '9': 0,
      '10': 'send'
    },
    {
      '1': 'interrupt',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.InterruptRequest',
      '9': 0,
      '10': 'interrupt'
    },
    {
      '1': 'resolve_approval',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ResolveApproval',
      '9': 0,
      '10': 'resolveApproval'
    },
    {
      '1': 'resolve_clarification',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ResolveClarification',
      '9': 0,
      '10': 'resolveClarification'
    },
    {
      '1': 'acquire_lease',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.AcquireControlLease',
      '9': 0,
      '10': 'acquireLease'
    },
    {
      '1': 'renew_lease',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.RenewControlLease',
      '9': 0,
      '10': 'renewLease'
    },
    {
      '1': 'replay',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.ReplayEvents',
      '9': 0,
      '10': 'replay'
    },
    {
      '1': 'get_request',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.agent_talk.v1.GetRequest',
      '9': 0,
      '10': 'getRequest'
    },
  ],
  '8': [
    {'1': 'command'},
  ],
};

/// Descriptor for `ClientCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientCommandDescriptor = $convert.base64Decode(
    'Cg1DbGllbnRDb21tYW5kEh0KCmNvbW1hbmRfaWQYASABKAlSCWNvbW1hbmRJZBInCg9pZGVtcG'
    '90ZW5jeV9rZXkYAiABKAlSDmlkZW1wb3RlbmN5S2V5EicKD2NvbnZlcnNhdGlvbl9pZBgDIAEo'
    'CVIOY29udmVyc2F0aW9uSWQSGQoIbGVhc2VfaWQYBCABKAlSB2xlYXNlSWQSJQoObGVhc2Vfcm'
    'V2aXNpb24YBSABKARSDWxlYXNlUmV2aXNpb24SMAoEc2VuZBgKIAEoCzIaLmFnZW50X3RhbGsu'
    'djEuU2VuZFJlcXVlc3RIAFIEc2VuZBI/CglpbnRlcnJ1cHQYCyABKAsyHy5hZ2VudF90YWxrLn'
    'YxLkludGVycnVwdFJlcXVlc3RIAFIJaW50ZXJydXB0EksKEHJlc29sdmVfYXBwcm92YWwYDCAB'
    'KAsyHi5hZ2VudF90YWxrLnYxLlJlc29sdmVBcHByb3ZhbEgAUg9yZXNvbHZlQXBwcm92YWwSWg'
    'oVcmVzb2x2ZV9jbGFyaWZpY2F0aW9uGA0gASgLMiMuYWdlbnRfdGFsay52MS5SZXNvbHZlQ2xh'
    'cmlmaWNhdGlvbkgAUhRyZXNvbHZlQ2xhcmlmaWNhdGlvbhJJCg1hY3F1aXJlX2xlYXNlGA4gAS'
    'gLMiIuYWdlbnRfdGFsay52MS5BY3F1aXJlQ29udHJvbExlYXNlSABSDGFjcXVpcmVMZWFzZRJD'
    'CgtyZW5ld19sZWFzZRgPIAEoCzIgLmFnZW50X3RhbGsudjEuUmVuZXdDb250cm9sTGVhc2VIAF'
    'IKcmVuZXdMZWFzZRI1CgZyZXBsYXkYECABKAsyGy5hZ2VudF90YWxrLnYxLlJlcGxheUV2ZW50'
    'c0gAUgZyZXBsYXkSPAoLZ2V0X3JlcXVlc3QYESABKAsyGS5hZ2VudF90YWxrLnYxLkdldFJlcX'
    'Vlc3RIAFIKZ2V0UmVxdWVzdEIJCgdjb21tYW5k');

@$core.Deprecated('Use requestStatusDescriptor instead')
const RequestStatus$json = {
  '1': 'RequestStatus',
  '2': [
    {'1': 'request_id', '3': 1, '4': 1, '5': 9, '10': 'requestId'},
    {'1': 'conversation_id', '3': 2, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'state', '3': 3, '4': 1, '5': 9, '10': 'state'},
    {'1': 'node_id', '3': 4, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'agent_id', '3': 5, '4': 1, '5': 9, '10': 'agentId'},
    {
      '1': 'capability_revision',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'capabilityRevision'
    },
    {
      '1': 'accepted_sequence',
      '3': 7,
      '4': 1,
      '5': 4,
      '10': 'acceptedSequence'
    },
    {
      '1': 'failure',
      '3': 8,
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

/// Descriptor for `RequestStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List requestStatusDescriptor = $convert.base64Decode(
    'Cg1SZXF1ZXN0U3RhdHVzEh0KCnJlcXVlc3RfaWQYASABKAlSCXJlcXVlc3RJZBInCg9jb252ZX'
    'JzYXRpb25faWQYAiABKAlSDmNvbnZlcnNhdGlvbklkEhQKBXN0YXRlGAMgASgJUgVzdGF0ZRIX'
    'Cgdub2RlX2lkGAQgASgJUgZub2RlSWQSGQoIYWdlbnRfaWQYBSABKAlSB2FnZW50SWQSLwoTY2'
    'FwYWJpbGl0eV9yZXZpc2lvbhgGIAEoCVISY2FwYWJpbGl0eVJldmlzaW9uEisKEWFjY2VwdGVk'
    'X3NlcXVlbmNlGAcgASgEUhBhY2NlcHRlZFNlcXVlbmNlEjoKB2ZhaWx1cmUYCCABKAsyGy5hZ2'
    'VudF90YWxrLnYxLlN0YWdlRmFpbHVyZUgAUgdmYWlsdXJliAEBQgoKCF9mYWlsdXJl');

@$core.Deprecated('Use controlLeaseDescriptor instead')
const ControlLease$json = {
  '1': 'ControlLease',
  '2': [
    {'1': 'lease_id', '3': 1, '4': 1, '5': 9, '10': 'leaseId'},
    {'1': 'conversation_id', '3': 2, '4': 1, '5': 9, '10': 'conversationId'},
    {'1': 'device_id', '3': 3, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'revision', '3': 4, '4': 1, '5': 4, '10': 'revision'},
    {
      '1': 'expires_at',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
  ],
};

/// Descriptor for `ControlLease`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List controlLeaseDescriptor = $convert.base64Decode(
    'CgxDb250cm9sTGVhc2USGQoIbGVhc2VfaWQYASABKAlSB2xlYXNlSWQSJwoPY29udmVyc2F0aW'
    '9uX2lkGAIgASgJUg5jb252ZXJzYXRpb25JZBIbCglkZXZpY2VfaWQYAyABKAlSCGRldmljZUlk'
    'EhoKCHJldmlzaW9uGAQgASgEUghyZXZpc2lvbhI5CgpleHBpcmVzX2F0GAUgASgLMhouZ29vZ2'
    'xlLnByb3RvYnVmLlRpbWVzdGFtcFIJZXhwaXJlc0F0');
