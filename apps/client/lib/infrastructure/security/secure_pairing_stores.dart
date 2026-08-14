import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../domain/device_pairing.dart';
import 'device_key_vault.dart';

part 'secure_pairing_store_codecs.dart';

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
    if (existing != null) {
      if (existing == encoded) return;
      final current = _decodeCredential(existing);
      final sameIdentity =
          current.keyReference == credential.keyReference &&
          current.deviceId == credential.deviceId &&
          current.gatewayAudience == credential.gatewayAudience &&
          _sameStrings(current.scopes, credential.scopes);
      if (!sameIdentity || credential.generation <= current.generation) {
        throw const SecurePairingStoreException(
          'credential_conflict',
          'A different secure credential already uses this identity.',
        );
      }
      await _store.write(key, encoded);
      return;
    }
    await _store.write(key, encoded);
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
