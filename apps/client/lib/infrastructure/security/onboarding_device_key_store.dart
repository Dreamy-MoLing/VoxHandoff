import 'dart:convert';

import 'device_key_vault.dart';

/// Stores only the Android Keystore alias reference, never private key bytes.
class SecureOnboardingDeviceKeyReferenceStore {
  const SecureOnboardingDeviceKeyReferenceStore(this._store);

  static const _key = 'voxhandoff.m6.onboarding-device-key-reference';
  final SecureValueStore _store;

  Future<void> save(String keyReference) async {
    _validateReference(keyReference);
    await _store.write(
      _key,
      jsonEncode({
        'version': 1,
        'kind': 'onboarding_device_key_reference',
        'key_reference': keyReference,
      }),
    );
  }

  Future<String?> load() async {
    final encoded = await _store.read(_key);
    if (encoded == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const SecureOnboardingDeviceKeyReferenceException(
        'corrupt_reference',
        'The secure device key reference is malformed.',
      );
    }
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['kind'] != 'onboarding_device_key_reference' ||
        decoded['key_reference'] is! String) {
      throw const SecureOnboardingDeviceKeyReferenceException(
        'corrupt_reference',
        'The secure device key reference has an unsupported shape.',
      );
    }
    final reference = decoded['key_reference']! as String;
    try {
      _validateReference(reference);
    } on SecureOnboardingDeviceKeyReferenceException {
      throw const SecureOnboardingDeviceKeyReferenceException(
        'corrupt_reference',
        'The secure device key reference is invalid.',
      );
    }
    return reference;
  }

  Future<void> delete() => _store.delete(_key);

  static void _validateReference(String value) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(value)) {
      throw const SecureOnboardingDeviceKeyReferenceException(
        'invalid_reference',
        'The device key reference is invalid.',
      );
    }
  }
}

class SecureOnboardingDeviceKeyReferenceException implements Exception {
  const SecureOnboardingDeviceKeyReferenceException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() =>
      'SecureOnboardingDeviceKeyReferenceException($code): $message';
}
