import 'dart:convert';

import '../../domain/onboarding_credential.dart';
import 'device_key_vault.dart';
import 'spki_pin_validator.dart';

/// Keeps credential material in the existing OS-backed secure value store.
/// The rest of the app receives only [OnboardingCredentialReference].
class SecureOnboardingCredentialStore implements OnboardingCredentialVault {
  const SecureOnboardingCredentialStore(this._store);

  static const _activeReferenceKey =
      'voxhandoff.m6.onboarding-active-credential-reference';
  static const _recordPrefix = 'voxhandoff.m6.onboarding-credential.';

  final SecureValueStore _store;

  @override
  Future<OnboardingCredentialReference> save(
    OnboardingCredentialMaterial material,
  ) async {
    final currentPin = canonicalizeSpkiPin(material.spkiPin);
    final backupPin = material.backupSpkiPin == null
        ? null
        : canonicalizeSpkiPin(material.backupSpkiPin!);
    SpkiPinSet(currentPin: currentPin, backupPin: backupPin);
    final reference = OnboardingCredentialReference(
      credentialId: material.credentialId,
      bridgeEndpoint: material.bridgeEndpoint,
      serverId: material.serverId,
      deviceKeyReference: material.deviceKeyReference,
      spkiPin: currentPin,
      backupSpkiPin: backupPin,
      issuedAt: material.issuedAt.toUtc(),
    );
    final recordKey = _recordKey(material.credentialId);
    try {
      await _store.write(
        recordKey,
        jsonEncode({
          'version': 1,
          'kind': 'onboarding_credential',
          'credential_id': material.credentialId,
          'credential': material.credential,
          'bridge_endpoint': material.bridgeEndpoint.toString(),
          'server_id': material.serverId,
          'device_key_reference': material.deviceKeyReference,
          'spki_pin': currentPin,
          'backup_spki_pin': backupPin,
          'issued_at': reference.issuedAt.toIso8601String(),
        }),
      );
      await _store.write(_activeReferenceKey, _encodeReference(reference));
    } on Object {
      await _store.delete(recordKey);
      rethrow;
    }
    return reference;
  }

  @override
  Future<OnboardingCredentialReference?> loadReference() async {
    final encoded = await _store.read(_activeReferenceKey);
    if (encoded == null) return null;
    return _decodeReference(encoded);
  }

  @override
  Future<OnboardingCredentialMaterial?> readMaterial(
    String credentialId,
  ) async {
    _validateCredentialId(credentialId);
    final encoded = await _store.read(_recordKey(credentialId));
    if (encoded == null) return null;
    final decoded = _decodeMap(encoded, 'credential');
    if (decoded['version'] != 1 ||
        decoded['kind'] != 'onboarding_credential' ||
        decoded['credential_id'] != credentialId) {
      throw const OnboardingCredentialException(
        'corrupt_credential',
        'The stored credential has an unsupported shape.',
      );
    }
    final endpoint = _requiredUri(decoded['bridge_endpoint']);
    final issuedAt = _requiredDate(decoded['issued_at']);
    final credential = _requiredString(decoded['credential'], 'credential');
    final serverId = _requiredString(decoded['server_id'], 'server ID');
    final keyReference = _requiredString(
      decoded['device_key_reference'],
      'device key reference',
    );
    late final String spkiPin;
    try {
      spkiPin = canonicalizeSpkiPin(
        _requiredString(decoded['spki_pin'], 'SPKI pin'),
      );
    } on SpkiPinConfigurationException catch (error) {
      throw OnboardingCredentialException('corrupt_credential', error.message);
    }
    final backup = decoded['backup_spki_pin'];
    if (backup != null && backup is! String) {
      throw const OnboardingCredentialException(
        'corrupt_credential',
        'The stored backup SPKI pin is invalid.',
      );
    }
    try {
      return OnboardingCredentialMaterial(
        credentialId: credentialId,
        credential: credential,
        bridgeEndpoint: endpoint,
        serverId: serverId,
        deviceKeyReference: keyReference,
        spkiPin: spkiPin,
        backupSpkiPin: backup == null
            ? null
            : canonicalizeSpkiPin(backup as String),
        issuedAt: issuedAt,
      );
    } on OnboardingCredentialException catch (error) {
      throw OnboardingCredentialException('corrupt_credential', error.message);
    } on SpkiPinConfigurationException catch (error) {
      throw OnboardingCredentialException('corrupt_credential', error.message);
    }
  }

  @override
  Future<void> revoke(String credentialId) async {
    _validateCredentialId(credentialId);
    await _store.delete(_recordKey(credentialId));
    final reference = await loadReference();
    if (reference?.credentialId == credentialId) {
      await _store.delete(_activeReferenceKey);
    }
  }

  static String _encodeReference(OnboardingCredentialReference reference) =>
      jsonEncode({
        'version': 1,
        'kind': 'onboarding_credential_reference',
        'credential_id': reference.credentialId,
        'bridge_endpoint': reference.bridgeEndpoint.toString(),
        'server_id': reference.serverId,
        'device_key_reference': reference.deviceKeyReference,
        'spki_pin': reference.spkiPin,
        'backup_spki_pin': reference.backupSpkiPin,
        'issued_at': reference.issuedAt.toIso8601String(),
      });

  static OnboardingCredentialReference _decodeReference(String encoded) {
    final decoded = _decodeMap(encoded, 'credential reference');
    if (decoded['version'] != 1 ||
        decoded['kind'] != 'onboarding_credential_reference') {
      throw const OnboardingCredentialException(
        'corrupt_reference',
        'The stored credential reference has an unsupported shape.',
      );
    }
    final credentialId = _requiredString(
      decoded['credential_id'],
      'credential ID',
    );
    _validateCredentialId(credentialId);
    final backup = decoded['backup_spki_pin'];
    if (backup != null && backup is! String) {
      throw const OnboardingCredentialException(
        'corrupt_reference',
        'The stored backup SPKI pin is invalid.',
      );
    }
    try {
      return OnboardingCredentialReference(
        credentialId: credentialId,
        bridgeEndpoint: _requiredUri(decoded['bridge_endpoint']),
        serverId: _requiredString(decoded['server_id'], 'server ID'),
        deviceKeyReference: _requiredString(
          decoded['device_key_reference'],
          'device key reference',
        ),
        spkiPin: canonicalizeSpkiPin(
          _requiredString(decoded['spki_pin'], 'SPKI pin'),
        ),
        backupSpkiPin: backup == null
            ? null
            : canonicalizeSpkiPin(backup as String),
        issuedAt: _requiredDate(decoded['issued_at']),
      );
    } on OnboardingCredentialException catch (error) {
      throw OnboardingCredentialException('corrupt_reference', error.message);
    } on SpkiPinConfigurationException catch (error) {
      throw OnboardingCredentialException('corrupt_reference', error.message);
    }
  }

  static Map<String, Object?> _decodeMap(String encoded, String label) {
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw OnboardingCredentialException(
        'corrupt_$label',
        'The stored $label is not valid JSON.',
      );
    }
    if (decoded is! Map) {
      throw OnboardingCredentialException(
        'corrupt_$label',
        'The stored $label is not a JSON object.',
      );
    }
    return <String, Object?>{
      for (final entry in decoded.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
  }

  static String _recordKey(String credentialId) {
    _validateCredentialId(credentialId);
    return '$_recordPrefix$credentialId';
  }

  static void _validateCredentialId(String value) {
    if (!RegExp(r'^[A-Za-z0-9._~-]{1,256}$').hasMatch(value)) {
      throw const OnboardingCredentialException(
        'invalid_credential_id',
        'The credential identifier is invalid.',
      );
    }
  }

  static String _requiredString(Object? value, String label) {
    if (value is! String || value.isEmpty || value.length > 4096) {
      throw OnboardingCredentialException(
        'corrupt_credential',
        'The stored $label is invalid.',
      );
    }
    return value;
  }

  static Uri _requiredUri(Object? value) {
    if (value is! String) {
      throw const OnboardingCredentialException(
        'corrupt_credential',
        'The stored endpoint is invalid.',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null) {
      throw const OnboardingCredentialException(
        'corrupt_credential',
        'The stored endpoint is invalid.',
      );
    }
    return uri;
  }

  static DateTime _requiredDate(Object? value) {
    if (value is! String) {
      throw const OnboardingCredentialException(
        'corrupt_credential',
        'The stored credential timestamp is invalid.',
      );
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw const OnboardingCredentialException(
        'corrupt_credential',
        'The stored credential timestamp is invalid.',
      );
    }
    return parsed.toUtc();
  }
}
