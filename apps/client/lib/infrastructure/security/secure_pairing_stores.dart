import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/device_pairing.dart';
import 'device_key_vault.dart';

class SecurePairingStoreException implements Exception {
  const SecurePairingStoreException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SecurePairingStoreException($code): $message';
}

class GatewayConnectionProfile {
  GatewayConnectionProfile({
    required this.gatewayAudience,
    Iterable<int>? trustedRootCertificates,
  }) : trustedRootCertificates = trustedRootCertificates == null
           ? null
           : List.unmodifiable(trustedRootCertificates) {
    final uri = Uri.tryParse(gatewayAudience);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        gatewayAudience.length > 2048 ||
        (this.trustedRootCertificates?.isEmpty ?? false) ||
        (this.trustedRootCertificates?.length ?? 0) > 131072) {
      throw const FormatException('The Gateway connection profile is invalid.');
    }
  }

  final String gatewayAudience;
  final List<int>? trustedRootCertificates;
}

class SecureGatewayConnectionProfileStore {
  const SecureGatewayConnectionProfileStore(this._store);

  static const _key = 'agent-talk.v1.gateway-connection-profile';
  final SecureValueStore _store;

  Future<void> save(GatewayConnectionProfile profile) => _store.write(
    _key,
    jsonEncode({
      'version': 1,
      'kind': 'gateway_connection_profile',
      'gateway_audience': profile.gatewayAudience,
      'trusted_root_certificates': profile.trustedRootCertificates == null
          ? null
          : base64Encode(profile.trustedRootCertificates!),
    }),
  );

  Future<GatewayConnectionProfile?> load() async {
    final encoded = await _store.read(_key);
    if (encoded == null) return null;
    final map = _decodeMap(encoded, 'Gateway connection profile');
    if (map['version'] != 1 || map['kind'] != 'gateway_connection_profile') {
      throw const SecurePairingStoreException(
        'unsupported_gateway_profile',
        'The secure Gateway connection profile version is unsupported.',
      );
    }
    try {
      final certificate = map['trusted_root_certificates'];
      return GatewayConnectionProfile(
        gatewayAudience: _requiredString(
          map,
          'gateway_audience',
          maximumBytes: 2048,
        ),
        trustedRootCertificates: certificate == null
            ? null
            : base64Decode(
                _requiredString(
                  map,
                  'trusted_root_certificates',
                  maximumBytes: 180000,
                ),
              ),
      );
    } on FormatException {
      throw const SecurePairingStoreException(
        'corrupt_gateway_profile',
        'The secure Gateway connection profile is malformed.',
      );
    }
  }
}

class SecurePairingCheckpointStore implements PairingCheckpointStore {
  const SecurePairingCheckpointStore(this._store);

  static const _key = 'agent-talk.v1.pairing-checkpoint';
  final SecureValueStore _store;

  @override
  Future<void> delete() => _store.delete(_key);

  @override
  Future<PairingCheckpoint?> load() async {
    final encoded = await _store.read(_key);
    return encoded == null ? null : _decodeCheckpoint(encoded);
  }

  @override
  Future<void> save(PairingCheckpoint checkpoint) =>
      _store.write(_key, _encodeCheckpoint(checkpoint));
}

class SecureDeviceCredentialStore implements DeviceCredentialStore {
  SecureDeviceCredentialStore(this._store, {Sha256? sha256})
    : _sha256 = sha256 ?? Sha256();

  static const _prefix = 'agent-talk.v1.device-credential.';
  static const _activeCredentialKey = 'agent-talk.v1.active-device-credential';
  final SecureValueStore _store;
  final Sha256 _sha256;

  @override
  Future<DeviceCredentialBundle?> load(String credentialId) async {
    _requireOpaque(credentialId, 'credential ID');
    final encoded = await _store.read(await _key(credentialId));
    if (encoded == null) return null;
    final credential = _decodeCredential(encoded);
    if (credential.credentialId != credentialId) {
      throw const SecurePairingStoreException(
        'credential_mismatch',
        'The secure credential record has the wrong identity.',
      );
    }
    return credential;
  }

  @override
  Future<DeviceCredentialBundle?> loadActive() async {
    final credentialId = await _store.read(_activeCredentialKey);
    if (credentialId == null) return null;
    _requireOpaque(credentialId, 'active credential ID');
    final credential = await load(credentialId);
    if (credential == null) {
      throw const SecurePairingStoreException(
        'active_credential_missing',
        'The active credential reference has no credential record.',
      );
    }
    return credential;
  }

  @override
  Future<void> save(DeviceCredentialBundle credential) async {
    final activeCredentialId = await _store.read(_activeCredentialKey);
    if (activeCredentialId != null &&
        activeCredentialId != credential.credentialId) {
      throw const SecurePairingStoreException(
        'active_credential_conflict',
        'A different active device credential is already selected.',
      );
    }
    final key = await _key(credential.credentialId);
    final encoded = _encodeCredential(credential);
    final existing = await _store.read(key);
    if (existing != null && existing != encoded) {
      throw const SecurePairingStoreException(
        'credential_conflict',
        'A different secure credential already uses this identity.',
      );
    }
    if (existing == null) {
      await _store.write(key, encoded);
    }
    if (activeCredentialId == null) {
      await _store.write(_activeCredentialKey, credential.credentialId);
    }
  }

  Future<String> _key(String credentialId) async {
    _requireOpaque(credentialId, 'credential ID');
    final digest = await _sha256.hash(utf8.encode(credentialId));
    return '$_prefix${_hex(digest.bytes)}';
  }
}

String _encodeCheckpoint(PairingCheckpoint value) => jsonEncode({
  'version': 1,
  'kind': 'pairing_checkpoint',
  'phase': value.phase.name,
  'key_reference': value.keyReference,
  'device_display_name': value.deviceDisplayName,
  'expected_gateway_audience': value.expectedGatewayAudience,
  'requested_scopes': value.requestedScopes,
  'pairing_id': value.pairingId,
  'user_code': value.userCode,
  'verification_uri': value.verificationUri?.toString(),
  'expires_at': value.expiresAt?.toUtc().toIso8601String(),
  'device_fingerprint': value.deviceFingerprint,
  'gateway_fingerprint': value.gatewayFingerprint,
  'gateway_audience': value.gatewayAudience,
  'device_proof_payload': _encodeBytes(value.deviceProofPayload),
  'proof_signature': _encodeBytes(value.proofSignature),
  'device_id': value.deviceId,
  'credential_id': value.credentialId,
  'approved_scopes': value.approvedScopes,
  'confirmation_payload': _encodeBytes(value.confirmationPayload),
  'confirmation_signature': _encodeBytes(value.confirmationSignature),
  'confirmation_expires_at': value.confirmationExpiresAt
      ?.toUtc()
      .toIso8601String(),
  'uncertain_operation': value.uncertainOperation?.name,
});

PairingCheckpoint _decodeCheckpoint(String encoded) {
  final map = _decodeMap(encoded, 'pairing checkpoint');
  if (map['version'] != 1 || map['kind'] != 'pairing_checkpoint') {
    throw const SecurePairingStoreException(
      'unsupported_checkpoint',
      'The secure pairing checkpoint version is unsupported.',
    );
  }
  final proofSignature = _optionalExactBytes(map, 'proof_signature', 64);
  final confirmationSignature = _optionalExactBytes(
    map,
    'confirmation_signature',
    64,
  );
  return PairingCheckpoint(
    phase: _enumValue(
      PairingCheckpointPhase.values,
      _requiredString(map, 'phase'),
      'checkpoint phase',
    ),
    keyReference: _requiredKeyReference(map),
    deviceDisplayName: _requiredString(
      map,
      'device_display_name',
      maximumBytes: 128,
    ),
    expectedGatewayAudience: _requiredString(
      map,
      'expected_gateway_audience',
      maximumBytes: 2048,
    ),
    requestedScopes: _scopeList(map, 'requested_scopes'),
    pairingId: _optionalString(map, 'pairing_id'),
    userCode: _optionalString(map, 'user_code', maximumBytes: 32),
    verificationUri: _optionalUri(map, 'verification_uri'),
    expiresAt: _optionalDate(map, 'expires_at'),
    deviceFingerprint: _optionalFingerprint(map, 'device_fingerprint'),
    gatewayFingerprint: _optionalFingerprint(map, 'gateway_fingerprint'),
    gatewayAudience: _optionalString(
      map,
      'gateway_audience',
      maximumBytes: 2048,
    ),
    deviceProofPayload: _optionalBytes(map, 'device_proof_payload'),
    proofSignature: proofSignature,
    deviceId: _optionalString(map, 'device_id'),
    credentialId: _optionalString(map, 'credential_id'),
    approvedScopes: _scopeList(map, 'approved_scopes', allowEmpty: true),
    confirmationPayload: _optionalBytes(map, 'confirmation_payload'),
    confirmationSignature: confirmationSignature,
    confirmationExpiresAt: _optionalDate(map, 'confirmation_expires_at'),
    uncertainOperation: _optionalEnumValue(
      PairingOperation.values,
      _optionalString(map, 'uncertain_operation'),
      'uncertain operation',
    ),
  );
}

String _encodeCredential(DeviceCredentialBundle value) => jsonEncode({
  'version': 1,
  'kind': 'device_credential',
  'key_reference': value.keyReference,
  'device_id': value.deviceId,
  'credential_id': value.credentialId,
  'gateway_audience': value.gatewayAudience,
  'scopes': value.scopes,
  'access_token': value.accessToken,
  'refresh_token': value.refreshToken,
  'access_expires_at': value.accessExpiresAt.toUtc().toIso8601String(),
  'refresh_expires_at': value.refreshExpiresAt.toUtc().toIso8601String(),
});

DeviceCredentialBundle _decodeCredential(String encoded) {
  final map = _decodeMap(encoded, 'device credential');
  if (map['version'] != 1 || map['kind'] != 'device_credential') {
    throw const SecurePairingStoreException(
      'unsupported_credential',
      'The secure device credential version is unsupported.',
    );
  }
  final accessToken = _requiredString(map, 'access_token', maximumBytes: 512);
  final refreshToken = _requiredString(map, 'refresh_token', maximumBytes: 512);
  if (!_secretPattern.hasMatch(accessToken) ||
      !_secretPattern.hasMatch(refreshToken)) {
    throw const SecurePairingStoreException(
      'corrupt_credential',
      'The secure device credential contains an invalid token.',
    );
  }
  final accessExpiresAt = _requiredDate(map, 'access_expires_at');
  final refreshExpiresAt = _requiredDate(map, 'refresh_expires_at');
  if (!refreshExpiresAt.isAfter(accessExpiresAt)) {
    throw const SecurePairingStoreException(
      'corrupt_credential',
      'The secure device credential has invalid expiry ordering.',
    );
  }
  return DeviceCredentialBundle(
    keyReference: _requiredKeyReference(map),
    deviceId: _requiredString(map, 'device_id'),
    credentialId: _requiredString(map, 'credential_id'),
    gatewayAudience: _requiredString(
      map,
      'gateway_audience',
      maximumBytes: 2048,
    ),
    scopes: _scopeList(map, 'scopes'),
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessExpiresAt: accessExpiresAt,
    refreshExpiresAt: refreshExpiresAt,
  );
}

Map<String, Object?> _decodeMap(String encoded, String label) {
  Object? decoded;
  try {
    decoded = jsonDecode(encoded);
  } on FormatException {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure $label record is malformed.',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure $label record has an invalid shape.',
    );
  }
  return decoded;
}

String _requiredString(
  Map<String, Object?> map,
  String key, {
  int maximumBytes = 256,
}) {
  final value = _optionalString(map, key, maximumBytes: maximumBytes);
  if (value == null || value.isEmpty) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" is missing.',
    );
  }
  return value;
}

String? _optionalString(
  Map<String, Object?> map,
  String key, {
  int maximumBytes = 256,
}) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String ||
      utf8.encode(value).length > maximumBytes ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" is invalid.',
    );
  }
  return value;
}

List<String> _scopeList(
  Map<String, Object?> map,
  String key, {
  bool allowEmpty = false,
}) {
  final value = map[key];
  if (value is! List<Object?> ||
      (!allowEmpty && value.isEmpty) ||
      value.length > _deviceScopes.length) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" is invalid.',
    );
  }
  final result = <String>[];
  for (final item in value) {
    if (item is! String ||
        !_deviceScopes.contains(item) ||
        result.contains(item)) {
      throw SecurePairingStoreException(
        'corrupt_secure_record',
        'The secure record field "$key" is invalid.',
      );
    }
    result.add(item);
  }
  return List.unmodifiable(result);
}

String _requiredKeyReference(Map<String, Object?> map) {
  final value = _requiredString(map, 'key_reference', maximumBytes: 32);
  if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(value)) {
    throw const SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record key reference is invalid.',
    );
  }
  return value;
}

String? _optionalFingerprint(Map<String, Object?> map, String key) {
  final value = _optionalString(map, key, maximumBytes: 71);
  if (value != null && !_fingerprintPattern.hasMatch(value)) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" has an invalid fingerprint.',
    );
  }
  return value;
}

String? _encodeBytes(List<int>? bytes) =>
    bytes == null ? null : base64UrlEncode(bytes);

List<int>? _optionalBytes(
  Map<String, Object?> map,
  String key, {
  int maximumBytes = 1024 * 1024,
}) {
  final value = _optionalString(map, key, maximumBytes: maximumBytes * 2);
  if (value == null) return null;
  try {
    final decoded = base64Url.decode(value);
    if (decoded.length > maximumBytes) {
      throw const FormatException('decoded bytes are too large');
    }
    return List.unmodifiable(decoded);
  } on FormatException {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" contains invalid bytes.',
    );
  }
}

List<int>? _optionalExactBytes(
  Map<String, Object?> map,
  String key,
  int length,
) {
  final value = _optionalBytes(map, key, maximumBytes: length);
  if (value != null && value.length != length) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" has an invalid byte length.',
    );
  }
  return value;
}

DateTime _requiredDate(Map<String, Object?> map, String key) {
  final value = _optionalDate(map, key);
  if (value == null) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" is missing.',
    );
  }
  return value;
}

DateTime? _optionalDate(Map<String, Object?> map, String key) {
  final value = _optionalString(map, key, maximumBytes: 64);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.endsWith('Z')) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" has an invalid timestamp.',
    );
  }
  return parsed.toUtc();
}

Uri? _optionalUri(Map<String, Object?> map, String key) {
  final value = _optionalString(map, key, maximumBytes: 2048);
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasAuthority) {
    throw SecurePairingStoreException(
      'corrupt_secure_record',
      'The secure record field "$key" has an invalid URI.',
    );
  }
  return uri;
}

T _enumValue<T extends Enum>(List<T> values, String name, String label) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw SecurePairingStoreException(
    'corrupt_secure_record',
    'The secure $label is invalid.',
  );
}

T? _optionalEnumValue<T extends Enum>(
  List<T> values,
  String? name,
  String label,
) => name == null ? null : _enumValue(values, name, label);

void _requireOpaque(String value, String label) {
  if (value.isEmpty ||
      value.length > 256 ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw SecurePairingStoreException(
      'invalid_opaque_id',
      'The $label is invalid.',
    );
  }
}

final _secretPattern = RegExp(r'^[A-Za-z0-9_-]{24,512}$');
final _fingerprintPattern = RegExp(r'^sha256:[0-9a-f]{64}$');
const _deviceScopes = {'observe', 'send', 'interrupt', 'approve', 'administer'};

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
