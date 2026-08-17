/// Public identity returned after an Android Keystore key is created.
class OnboardingDeviceKeyIdentity {
  OnboardingDeviceKeyIdentity({
    required this.keyReference,
    required List<int> publicKeySpkiDer,
    required this.fingerprint,
    required this.hardwareBacked,
    required this.strongBoxBacked,
  }) : publicKeySpkiDer = List.unmodifiable(publicKeySpkiDer) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(keyReference)) {
      throw const OnboardingDeviceKeyException(
        'invalid_key_reference',
        'The Android Keystore key reference is invalid.',
      );
    }
    if (this.publicKeySpkiDer.isEmpty || this.publicKeySpkiDer.length > 4096) {
      throw const OnboardingDeviceKeyException(
        'invalid_public_key',
        'The device public key is invalid.',
      );
    }
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(fingerprint)) {
      throw const OnboardingDeviceKeyException(
        'invalid_fingerprint',
        'The device public key fingerprint is invalid.',
      );
    }
  }

  final String keyReference;
  final List<int> publicKeySpkiDer;
  final String fingerprint;
  final bool hardwareBacked;
  final bool strongBoxBacked;

  @override
  String toString() =>
      'OnboardingDeviceKeyIdentity(keyReference: $keyReference, '
      'hardwareBacked: $hardwareBacked, strongBoxBacked: $strongBoxBacked, '
      'redacted: true)';
}

abstract interface class OnboardingDeviceKeyPort {
  Future<OnboardingDeviceKeyIdentity> create();

  Future<OnboardingDeviceKeyIdentity> inspect(String keyReference);

  Future<List<int>> sign(String keyReference, List<int> payload);

  Future<void> delete(String keyReference);
}

class OnboardingDeviceKeyException implements Exception {
  const OnboardingDeviceKeyException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'OnboardingDeviceKeyException($code): $message';
}
