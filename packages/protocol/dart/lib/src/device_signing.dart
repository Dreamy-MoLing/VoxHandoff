import 'dart:convert';
import 'dart:typed_data';

const deviceScopes = <String>[
  'observe',
  'send',
  'interrupt',
  'approve',
  'administer',
];

final _payloadMagic = utf8.encode('agent-talk-signed-payload\u0000v1');
final _domainPattern = RegExp(r'^agent-talk\/[a-z0-9.-]+\/v1$');
final _fieldNamePattern = RegExp(r'^[a-z][a-z0-9_.-]*$');
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
const _maximumPayloadBytes = 1024 * 1024;

enum DeviceSigningErrorCode {
  invalidDomain,
  invalidField,
  duplicateField,
  payloadTooLarge,
  invalidScope,
  duplicateScope,
  invalidSha256,
}

class DeviceSigningContractException implements Exception {
  const DeviceSigningContractException(this.code, this.message);

  final DeviceSigningErrorCode code;
  final String message;

  @override
  String toString() => 'DeviceSigningContractException: $message';
}

class SignedPayloadField {
  const SignedPayloadField(this.name, this.value);

  final String name;
  final Object value;
}

Uint8List _uint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.big);
  return bytes.buffer.asUint8List();
}

Uint8List _bytes(Object value) {
  if (value is String) {
    return Uint8List.fromList(utf8.encode(value));
  }
  if (value is List<int>) {
    if (value.any((byte) => byte < 0 || byte > 255)) {
      throw const DeviceSigningContractException(
        DeviceSigningErrorCode.invalidField,
        'A signed payload byte value is out of range.',
      );
    }
    return Uint8List.fromList(value);
  }
  throw const DeviceSigningContractException(
    DeviceSigningErrorCode.invalidField,
    'A signed payload field must contain UTF-8 text or bytes.',
  );
}

void _addFrame(BytesBuilder output, List<int> value) {
  if (value.length > _maximumPayloadBytes) {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.payloadTooLarge,
      'A signed payload field exceeds one MiB.',
    );
  }
  output
    ..add(_uint32(value.length))
    ..add(value);
}

Uint8List canonicalSignedPayload(
  String domain,
  List<SignedPayloadField> fields,
) {
  if (!_domainPattern.hasMatch(domain)) {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.invalidDomain,
      'The device-signature domain is invalid.',
    );
  }
  final names = <String>{};
  final output = BytesBuilder(copy: false)..add(_payloadMagic);
  _addFrame(output, utf8.encode(domain));
  output.add(_uint32(fields.length));
  for (final field in fields) {
    if (!_fieldNamePattern.hasMatch(field.name)) {
      throw const DeviceSigningContractException(
        DeviceSigningErrorCode.invalidField,
        'A device-signature field name is invalid.',
      );
    }
    if (!names.add(field.name)) {
      throw const DeviceSigningContractException(
        DeviceSigningErrorCode.duplicateField,
        'A device-signature field name is duplicated.',
      );
    }
    _addFrame(output, utf8.encode(field.name));
    _addFrame(output, _bytes(field.value));
  }
  final payload = output.takeBytes();
  if (payload.length > _maximumPayloadBytes) {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.payloadTooLarge,
      'The signed payload exceeds one MiB.',
    );
  }
  return payload;
}

List<String> normalizeDeviceScopes(Iterable<String> scopes) {
  final normalized = scopes.toList()..sort();
  if (normalized.isEmpty || normalized.length > deviceScopes.length) {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.invalidScope,
      'At least one valid device scope is required.',
    );
  }
  for (var index = 0; index < normalized.length; index += 1) {
    final scope = normalized[index];
    if (!deviceScopes.contains(scope)) {
      throw const DeviceSigningContractException(
        DeviceSigningErrorCode.invalidScope,
        'The requested device scope is not supported.',
      );
    }
    if (index > 0 && normalized[index - 1] == scope) {
      throw const DeviceSigningContractException(
        DeviceSigningErrorCode.duplicateScope,
        'A device scope is duplicated.',
      );
    }
  }
  return List.unmodifiable(normalized);
}

List<SignedPayloadField> _scopeFields(Iterable<String> scopes) {
  final normalized = normalizeDeviceScopes(scopes);
  return [
    for (var index = 0; index < normalized.length; index += 1)
      SignedPayloadField(
        'scope.${index.toString().padLeft(3, '0')}',
        normalized[index],
      ),
  ];
}

String _requireSha256(String value) {
  if (!_sha256Pattern.hasMatch(value)) {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.invalidSha256,
      'A signed SHA-256 value is invalid.',
    );
  }
  return value;
}

Uint8List pairingProofPayload({
  required String pairingId,
  required List<int> challenge,
  required String gatewayAudience,
  required String deviceFingerprint,
  required Iterable<String> requestedScopes,
}) {
  return canonicalSignedPayload('agent-talk/pairing-proof/v1', [
    SignedPayloadField('pairing_id', pairingId),
    SignedPayloadField('challenge', challenge),
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField('device_fingerprint', deviceFingerprint),
    ..._scopeFields(requestedScopes),
  ]);
}

Uint8List pairingConfirmationPayload({
  required String pairingId,
  required String credentialId,
  required String deviceId,
  required List<int> challenge,
  required String gatewayAudience,
  required String deviceFingerprint,
  required Iterable<String> approvedScopes,
}) {
  return canonicalSignedPayload('agent-talk/pairing-confirmation/v1', [
    SignedPayloadField('pairing_id', pairingId),
    SignedPayloadField('credential_id', credentialId),
    SignedPayloadField('device_id', deviceId),
    SignedPayloadField('challenge', challenge),
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField('device_fingerprint', deviceFingerprint),
    ..._scopeFields(approvedScopes),
  ]);
}

Uint8List administratorPairingPayload({
  required String pairingId,
  required String userCode,
  required String deviceFingerprint,
  required String gatewayFingerprint,
  required String gatewayAudience,
  required Iterable<String> approvedScopes,
  required List<int> nonce,
}) {
  return canonicalSignedPayload('agent-talk/pairing-approval/v1', [
    SignedPayloadField('pairing_id', pairingId),
    SignedPayloadField('user_code', userCode),
    SignedPayloadField('device_fingerprint', deviceFingerprint),
    SignedPayloadField('gateway_fingerprint', gatewayFingerprint),
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField('nonce', nonce),
    ..._scopeFields(approvedScopes),
  ]);
}

Uint8List credentialRefreshPayload({
  required String credentialId,
  required String deviceId,
  required String gatewayAudience,
  required String refreshTokenSha256,
  required int generation,
  required List<int> nonce,
}) {
  if (generation <= 0) {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.invalidField,
      'The credential generation must be positive.',
    );
  }
  return canonicalSignedPayload('agent-talk/credential-refresh/v1', [
    SignedPayloadField('credential_id', credentialId),
    SignedPayloadField('device_id', deviceId),
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField(
      'refresh_token_sha256',
      _requireSha256(refreshTokenSha256),
    ),
    SignedPayloadField('generation', generation.toString()),
    SignedPayloadField('nonce', nonce),
  ]);
}

Uint8List deviceRevocationPayload({
  required String administratorDeviceId,
  required String targetDeviceId,
  required String reasonCode,
  required String gatewayAudience,
  required List<int> nonce,
}) {
  return canonicalSignedPayload('agent-talk/device-revocation/v1', [
    SignedPayloadField('administrator_device_id', administratorDeviceId),
    SignedPayloadField('target_device_id', targetDeviceId),
    SignedPayloadField('reason_code', reasonCode),
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField('nonce', nonce),
  ]);
}

Uint8List approvalDecisionPayload({
  required String credentialId,
  required String deviceId,
  required String hostIdentity,
  required String gatewayAudience,
  required String requestId,
  required String approvalId,
  required String decision,
  required String operationSummarySha256,
  required List<int> nonce,
}) {
  if (decision != 'approve' && decision != 'deny') {
    throw const DeviceSigningContractException(
      DeviceSigningErrorCode.invalidField,
      'The approval decision is invalid.',
    );
  }
  return canonicalSignedPayload('agent-talk/approval-decision/v1', [
    SignedPayloadField('credential_id', credentialId),
    SignedPayloadField('device_id', deviceId),
    SignedPayloadField('host_identity', hostIdentity),
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField('request_id', requestId),
    SignedPayloadField('approval_id', approvalId),
    SignedPayloadField('decision', decision),
    SignedPayloadField(
      'operation_summary_sha256',
      _requireSha256(operationSummarySha256),
    ),
    SignedPayloadField('nonce', nonce),
  ]);
}

Uint8List ownerBootstrapPayload({
  required String gatewayAudience,
  required String deviceFingerprint,
  required Iterable<String> scopes,
  required List<int> nonce,
}) {
  return _ownerPayload(
    domain: 'agent-talk/owner-bootstrap/v1',
    gatewayAudience: gatewayAudience,
    deviceFingerprint: deviceFingerprint,
    scopes: scopes,
    nonce: nonce,
  );
}

Uint8List ownerRecoveryPayload({
  required String gatewayAudience,
  required String deviceFingerprint,
  required Iterable<String> scopes,
  required List<int> nonce,
}) {
  return _ownerPayload(
    domain: 'agent-talk/owner-recovery/v1',
    gatewayAudience: gatewayAudience,
    deviceFingerprint: deviceFingerprint,
    scopes: scopes,
    nonce: nonce,
  );
}

Uint8List _ownerPayload({
  required String domain,
  required String gatewayAudience,
  required String deviceFingerprint,
  required Iterable<String> scopes,
  required List<int> nonce,
}) {
  return canonicalSignedPayload(domain, [
    SignedPayloadField('gateway_audience', gatewayAudience),
    SignedPayloadField('device_fingerprint', deviceFingerprint),
    SignedPayloadField('nonce', nonce),
    ..._scopeFields(scopes),
  ]);
}
