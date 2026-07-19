// This is a generated file - do not edit.
//
// Generated from agent_talk/v1/common.proto.

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

@$core.Deprecated('Use componentRoleDescriptor instead')
const ComponentRole$json = {
  '1': 'ComponentRole',
  '2': [
    {'1': 'COMPONENT_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'COMPONENT_ROLE_CLIENT', '2': 1},
    {'1': 'COMPONENT_ROLE_GATEWAY', '2': 2},
    {'1': 'COMPONENT_ROLE_NODE', '2': 3},
    {'1': 'COMPONENT_ROLE_SIDECAR', '2': 4},
    {'1': 'COMPONENT_ROLE_STT', '2': 5},
  ],
};

/// Descriptor for `ComponentRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List componentRoleDescriptor = $convert.base64Decode(
    'Cg1Db21wb25lbnRSb2xlEh4KGkNPTVBPTkVOVF9ST0xFX1VOU1BFQ0lGSUVEEAASGQoVQ09NUE'
    '9ORU5UX1JPTEVfQ0xJRU5UEAESGgoWQ09NUE9ORU5UX1JPTEVfR0FURVdBWRACEhcKE0NPTVBP'
    'TkVOVF9ST0xFX05PREUQAxIaChZDT01QT05FTlRfUk9MRV9TSURFQ0FSEAQSFgoSQ09NUE9ORU'
    '5UX1JPTEVfU1RUEAU=');

@$core.Deprecated('Use deltaModeDescriptor instead')
const DeltaMode$json = {
  '1': 'DeltaMode',
  '2': [
    {'1': 'DELTA_MODE_UNSPECIFIED', '2': 0},
    {'1': 'DELTA_MODE_NONE', '2': 1},
    {'1': 'DELTA_MODE_APPEND_ONLY', '2': 2},
    {'1': 'DELTA_MODE_REVISABLE', '2': 3},
  ],
};

/// Descriptor for `DeltaMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deltaModeDescriptor = $convert.base64Decode(
    'CglEZWx0YU1vZGUSGgoWREVMVEFfTU9ERV9VTlNQRUNJRklFRBAAEhMKD0RFTFRBX01PREVfTk'
    '9ORRABEhoKFkRFTFRBX01PREVfQVBQRU5EX09OTFkQAhIYChRERUxUQV9NT0RFX1JFVklTQUJM'
    'RRAD');

@$core.Deprecated('Use failureStageDescriptor instead')
const FailureStage$json = {
  '1': 'FailureStage',
  '2': [
    {'1': 'FAILURE_STAGE_UNSPECIFIED', '2': 0},
    {'1': 'FAILURE_STAGE_RECORDING', '2': 1},
    {'1': 'FAILURE_STAGE_STT', '2': 2},
    {'1': 'FAILURE_STAGE_CONNECTION', '2': 3},
    {'1': 'FAILURE_STAGE_AUTHENTICATION', '2': 4},
    {'1': 'FAILURE_STAGE_AUTHORIZATION', '2': 5},
    {'1': 'FAILURE_STAGE_PROTOCOL', '2': 6},
    {'1': 'FAILURE_STAGE_AGENT', '2': 7},
    {'1': 'FAILURE_STAGE_SUMMARY', '2': 8},
    {'1': 'FAILURE_STAGE_TTS', '2': 9},
    {'1': 'FAILURE_STAGE_PLAYBACK', '2': 10},
    {'1': 'FAILURE_STAGE_STORAGE', '2': 11},
    {'1': 'FAILURE_STAGE_SYNC', '2': 12},
    {'1': 'FAILURE_STAGE_CONFIGURATION', '2': 13},
  ],
};

/// Descriptor for `FailureStage`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List failureStageDescriptor = $convert.base64Decode(
    'CgxGYWlsdXJlU3RhZ2USHQoZRkFJTFVSRV9TVEFHRV9VTlNQRUNJRklFRBAAEhsKF0ZBSUxVUk'
    'VfU1RBR0VfUkVDT1JESU5HEAESFQoRRkFJTFVSRV9TVEFHRV9TVFQQAhIcChhGQUlMVVJFX1NU'
    'QUdFX0NPTk5FQ1RJT04QAxIgChxGQUlMVVJFX1NUQUdFX0FVVEhFTlRJQ0FUSU9OEAQSHwobRk'
    'FJTFVSRV9TVEFHRV9BVVRIT1JJWkFUSU9OEAUSGgoWRkFJTFVSRV9TVEFHRV9QUk9UT0NPTBAG'
    'EhcKE0ZBSUxVUkVfU1RBR0VfQUdFTlQQBxIZChVGQUlMVVJFX1NUQUdFX1NVTU1BUlkQCBIVCh'
    'FGQUlMVVJFX1NUQUdFX1RUUxAJEhoKFkZBSUxVUkVfU1RBR0VfUExBWUJBQ0sQChIZChVGQUlM'
    'VVJFX1NUQUdFX1NUT1JBR0UQCxIWChJGQUlMVVJFX1NUQUdFX1NZTkMQDBIfChtGQUlMVVJFX1'
    'NUQUdFX0NPTkZJR1VSQVRJT04QDQ==');

@$core.Deprecated('Use failureCategoryDescriptor instead')
const FailureCategory$json = {
  '1': 'FailureCategory',
  '2': [
    {'1': 'FAILURE_CATEGORY_UNSPECIFIED', '2': 0},
    {'1': 'FAILURE_CATEGORY_VALIDATION', '2': 1},
    {'1': 'FAILURE_CATEGORY_UNAVAILABLE', '2': 2},
    {'1': 'FAILURE_CATEGORY_AUTHENTICATION', '2': 3},
    {'1': 'FAILURE_CATEGORY_AUTHORIZATION', '2': 4},
    {'1': 'FAILURE_CATEGORY_PROTOCOL', '2': 5},
    {'1': 'FAILURE_CATEGORY_TIMEOUT', '2': 6},
    {'1': 'FAILURE_CATEGORY_RATE_LIMIT', '2': 7},
    {'1': 'FAILURE_CATEGORY_UPSTREAM', '2': 8},
    {'1': 'FAILURE_CATEGORY_STORAGE', '2': 9},
    {'1': 'FAILURE_CATEGORY_PRIVACY', '2': 10},
    {'1': 'FAILURE_CATEGORY_UNKNOWN', '2': 11},
  ],
};

/// Descriptor for `FailureCategory`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List failureCategoryDescriptor = $convert.base64Decode(
    'Cg9GYWlsdXJlQ2F0ZWdvcnkSIAocRkFJTFVSRV9DQVRFR09SWV9VTlNQRUNJRklFRBAAEh8KG0'
    'ZBSUxVUkVfQ0FURUdPUllfVkFMSURBVElPThABEiAKHEZBSUxVUkVfQ0FURUdPUllfVU5BVkFJ'
    'TEFCTEUQAhIjCh9GQUlMVVJFX0NBVEVHT1JZX0FVVEhFTlRJQ0FUSU9OEAMSIgoeRkFJTFVSRV'
    '9DQVRFR09SWV9BVVRIT1JJWkFUSU9OEAQSHQoZRkFJTFVSRV9DQVRFR09SWV9QUk9UT0NPTBAF'
    'EhwKGEZBSUxVUkVfQ0FURUdPUllfVElNRU9VVBAGEh8KG0ZBSUxVUkVfQ0FURUdPUllfUkFURV'
    '9MSU1JVBAHEh0KGUZBSUxVUkVfQ0FURUdPUllfVVBTVFJFQU0QCBIcChhGQUlMVVJFX0NBVEVH'
    'T1JZX1NUT1JBR0UQCRIcChhGQUlMVVJFX0NBVEVHT1JZX1BSSVZBQ1kQChIcChhGQUlMVVJFX0'
    'NBVEVHT1JZX1VOS05PV04QCw==');

@$core.Deprecated('Use deviceSignatureAlgorithmDescriptor instead')
const DeviceSignatureAlgorithm$json = {
  '1': 'DeviceSignatureAlgorithm',
  '2': [
    {'1': 'DEVICE_SIGNATURE_ALGORITHM_UNSPECIFIED', '2': 0},
    {'1': 'DEVICE_SIGNATURE_ALGORITHM_ED25519', '2': 1},
  ],
};

/// Descriptor for `DeviceSignatureAlgorithm`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List deviceSignatureAlgorithmDescriptor = $convert.base64Decode(
    'ChhEZXZpY2VTaWduYXR1cmVBbGdvcml0aG0SKgomREVWSUNFX1NJR05BVFVSRV9BTEdPUklUSE'
    '1fVU5TUEVDSUZJRUQQABImCiJERVZJQ0VfU0lHTkFUVVJFX0FMR09SSVRITV9FRDI1NTE5EAE=');

@$core.Deprecated('Use protocolVersionDescriptor instead')
const ProtocolVersion$json = {
  '1': 'ProtocolVersion',
  '2': [
    {'1': 'major', '3': 1, '4': 1, '5': 13, '10': 'major'},
    {'1': 'minor', '3': 2, '4': 1, '5': 13, '10': 'minor'},
  ],
};

/// Descriptor for `ProtocolVersion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolVersionDescriptor = $convert.base64Decode(
    'Cg9Qcm90b2NvbFZlcnNpb24SFAoFbWFqb3IYASABKA1SBW1ham9yEhQKBW1pbm9yGAIgASgNUg'
    'VtaW5vcg==');

@$core.Deprecated('Use protocolVersionRangeDescriptor instead')
const ProtocolVersionRange$json = {
  '1': 'ProtocolVersionRange',
  '2': [
    {'1': 'major', '3': 1, '4': 1, '5': 13, '10': 'major'},
    {'1': 'minimum_minor', '3': 2, '4': 1, '5': 13, '10': 'minimumMinor'},
    {'1': 'maximum_minor', '3': 3, '4': 1, '5': 13, '10': 'maximumMinor'},
  ],
};

/// Descriptor for `ProtocolVersionRange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List protocolVersionRangeDescriptor = $convert.base64Decode(
    'ChRQcm90b2NvbFZlcnNpb25SYW5nZRIUCgVtYWpvchgBIAEoDVIFbWFqb3ISIwoNbWluaW11bV'
    '9taW5vchgCIAEoDVIMbWluaW11bU1pbm9yEiMKDW1heGltdW1fbWlub3IYAyABKA1SDG1heGlt'
    'dW1NaW5vcg==');

@$core.Deprecated('Use agentCapabilitiesDescriptor instead')
const AgentCapabilities$json = {
  '1': 'AgentCapabilities',
  '2': [
    {
      '1': 'delta_mode',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.DeltaMode',
      '10': 'deltaMode'
    },
    {'1': 'event_stream', '3': 2, '4': 1, '5': 8, '10': 'eventStream'},
    {'1': 'session_history', '3': 3, '4': 1, '5': 8, '10': 'sessionHistory'},
    {'1': 'create_session', '3': 4, '4': 1, '5': 8, '10': 'createSession'},
    {'1': 'resume_session', '3': 5, '4': 1, '5': 8, '10': 'resumeSession'},
    {'1': 'interrupt', '3': 6, '4': 1, '5': 8, '10': 'interrupt'},
    {'1': 'steer', '3': 7, '4': 1, '5': 8, '10': 'steer'},
    {'1': 'clarification', '3': 8, '4': 1, '5': 8, '10': 'clarification'},
    {'1': 'approval', '3': 9, '4': 1, '5': 8, '10': 'approval'},
    {'1': 'tool_events', '3': 10, '4': 1, '5': 8, '10': 'toolEvents'},
    {'1': 'attachments', '3': 11, '4': 1, '5': 8, '10': 'attachments'},
    {'1': 'idempotency', '3': 12, '4': 1, '5': 8, '10': 'idempotency'},
    {'1': 'replay', '3': 13, '4': 1, '5': 8, '10': 'replay'},
    {
      '1': 'sequence_recovery',
      '3': 14,
      '4': 1,
      '5': 8,
      '10': 'sequenceRecovery'
    },
    {
      '1': 'max_request_bytes',
      '3': 15,
      '4': 1,
      '5': 4,
      '9': 0,
      '10': 'maxRequestBytes',
      '17': true
    },
    {
      '1': 'request_timeout_ms',
      '3': 16,
      '4': 1,
      '5': 4,
      '9': 1,
      '10': 'requestTimeoutMs',
      '17': true
    },
  ],
  '8': [
    {'1': '_max_request_bytes'},
    {'1': '_request_timeout_ms'},
  ],
};

/// Descriptor for `AgentCapabilities`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentCapabilitiesDescriptor = $convert.base64Decode(
    'ChFBZ2VudENhcGFiaWxpdGllcxI3CgpkZWx0YV9tb2RlGAEgASgOMhguYWdlbnRfdGFsay52MS'
    '5EZWx0YU1vZGVSCWRlbHRhTW9kZRIhCgxldmVudF9zdHJlYW0YAiABKAhSC2V2ZW50U3RyZWFt'
    'EicKD3Nlc3Npb25faGlzdG9yeRgDIAEoCFIOc2Vzc2lvbkhpc3RvcnkSJQoOY3JlYXRlX3Nlc3'
    'Npb24YBCABKAhSDWNyZWF0ZVNlc3Npb24SJQoOcmVzdW1lX3Nlc3Npb24YBSABKAhSDXJlc3Vt'
    'ZVNlc3Npb24SHAoJaW50ZXJydXB0GAYgASgIUglpbnRlcnJ1cHQSFAoFc3RlZXIYByABKAhSBX'
    'N0ZWVyEiQKDWNsYXJpZmljYXRpb24YCCABKAhSDWNsYXJpZmljYXRpb24SGgoIYXBwcm92YWwY'
    'CSABKAhSCGFwcHJvdmFsEh8KC3Rvb2xfZXZlbnRzGAogASgIUgp0b29sRXZlbnRzEiAKC2F0dG'
    'FjaG1lbnRzGAsgASgIUgthdHRhY2htZW50cxIgCgtpZGVtcG90ZW5jeRgMIAEoCFILaWRlbXBv'
    'dGVuY3kSFgoGcmVwbGF5GA0gASgIUgZyZXBsYXkSKwoRc2VxdWVuY2VfcmVjb3ZlcnkYDiABKA'
    'hSEHNlcXVlbmNlUmVjb3ZlcnkSLwoRbWF4X3JlcXVlc3RfYnl0ZXMYDyABKARIAFIPbWF4UmVx'
    'dWVzdEJ5dGVziAEBEjEKEnJlcXVlc3RfdGltZW91dF9tcxgQIAEoBEgBUhByZXF1ZXN0VGltZW'
    '91dE1ziAEBQhQKEl9tYXhfcmVxdWVzdF9ieXRlc0IVChNfcmVxdWVzdF90aW1lb3V0X21z');

@$core.Deprecated('Use stageFailureDescriptor instead')
const StageFailure$json = {
  '1': 'StageFailure',
  '2': [
    {
      '1': 'stage',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.FailureStage',
      '10': 'stage'
    },
    {
      '1': 'category',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.FailureCategory',
      '10': 'category'
    },
    {'1': 'code', '3': 3, '4': 1, '5': 9, '10': 'code'},
    {'1': 'safe_message', '3': 4, '4': 1, '5': 9, '10': 'safeMessage'},
    {'1': 'retryable', '3': 5, '4': 1, '5': 8, '10': 'retryable'},
  ],
};

/// Descriptor for `StageFailure`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stageFailureDescriptor = $convert.base64Decode(
    'CgxTdGFnZUZhaWx1cmUSMQoFc3RhZ2UYASABKA4yGy5hZ2VudF90YWxrLnYxLkZhaWx1cmVTdG'
    'FnZVIFc3RhZ2USOgoIY2F0ZWdvcnkYAiABKA4yHi5hZ2VudF90YWxrLnYxLkZhaWx1cmVDYXRl'
    'Z29yeVIIY2F0ZWdvcnkSEgoEY29kZRgDIAEoCVIEY29kZRIhCgxzYWZlX21lc3NhZ2UYBCABKA'
    'lSC3NhZmVNZXNzYWdlEhwKCXJldHJ5YWJsZRgFIAEoCFIJcmV0cnlhYmxl');

@$core.Deprecated('Use emptyDescriptor instead')
const Empty$json = {
  '1': 'Empty',
};

/// Descriptor for `Empty`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List emptyDescriptor =
    $convert.base64Decode('CgVFbXB0eQ==');

@$core.Deprecated('Use deviceSignatureDescriptor instead')
const DeviceSignature$json = {
  '1': 'DeviceSignature',
  '2': [
    {'1': 'credential_id', '3': 1, '4': 1, '5': 9, '10': 'credentialId'},
    {'1': 'nonce', '3': 2, '4': 1, '5': 12, '10': 'nonce'},
    {'1': 'signature', '3': 3, '4': 1, '5': 12, '10': 'signature'},
    {
      '1': 'algorithm',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.agent_talk.v1.DeviceSignatureAlgorithm',
      '10': 'algorithm'
    },
  ],
};

/// Descriptor for `DeviceSignature`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceSignatureDescriptor = $convert.base64Decode(
    'Cg9EZXZpY2VTaWduYXR1cmUSIwoNY3JlZGVudGlhbF9pZBgBIAEoCVIMY3JlZGVudGlhbElkEh'
    'QKBW5vbmNlGAIgASgMUgVub25jZRIcCglzaWduYXR1cmUYAyABKAxSCXNpZ25hdHVyZRJFCglh'
    'bGdvcml0aG0YBCABKA4yJy5hZ2VudF90YWxrLnYxLkRldmljZVNpZ25hdHVyZUFsZ29yaXRobV'
    'IJYWxnb3JpdGht');
