class OnboardingCredentialMaterial {
  OnboardingCredentialMaterial({
    required this.credentialId,
    required this.credential,
    required this.bridgeEndpoint,
    required this.serverId,
    required this.deviceKeyReference,
    required this.spkiPin,
    required this.issuedAt,
    this.backupSpkiPin,
  }) {
    _validateOpaque(credentialId, 'credential ID', maximumLength: 256);
    _validateOpaque(credential, 'credential', maximumLength: 4096);
    _validateOpaque(serverId, 'server ID', maximumLength: 128);
    if (bridgeEndpoint.scheme.toLowerCase() != 'https' ||
        !bridgeEndpoint.hasAuthority ||
        bridgeEndpoint.host.isEmpty ||
        bridgeEndpoint.userInfo.isNotEmpty ||
        bridgeEndpoint.hasQuery ||
        bridgeEndpoint.hasFragment) {
      throw const OnboardingCredentialException(
        'invalid_bridge_endpoint',
        'The stored credential endpoint is unsafe.',
      );
    }
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(deviceKeyReference)) {
      throw const OnboardingCredentialException(
        'invalid_key_reference',
        'The stored credential key reference is invalid.',
      );
    }
  }

  final String credentialId;
  final String credential;
  final Uri bridgeEndpoint;
  final String serverId;
  final String deviceKeyReference;
  final String spkiPin;
  final String? backupSpkiPin;
  final DateTime issuedAt;

  @override
  String toString() =>
      'OnboardingCredentialMaterial(credentialId: $credentialId, '
      'bridgeEndpoint: $bridgeEndpoint, redacted: true)';
}

class OnboardingCredentialReference {
  OnboardingCredentialReference({
    required this.credentialId,
    required this.bridgeEndpoint,
    required this.serverId,
    required this.deviceKeyReference,
    required this.spkiPin,
    required this.issuedAt,
    this.backupSpkiPin,
  });

  final String credentialId;
  final Uri bridgeEndpoint;
  final String serverId;
  final String deviceKeyReference;
  final String spkiPin;
  final String? backupSpkiPin;
  final DateTime issuedAt;

  @override
  String toString() =>
      'OnboardingCredentialReference(credentialId: $credentialId, '
      'bridgeEndpoint: $bridgeEndpoint, redacted: true)';
}

abstract interface class OnboardingCredentialVault {
  Future<OnboardingCredentialReference> save(
    OnboardingCredentialMaterial material,
  );

  Future<OnboardingCredentialReference?> loadReference();

  Future<OnboardingCredentialMaterial?> readMaterial(String credentialId);

  Future<void> revoke(String credentialId);
}

abstract interface class OnboardingCredentialRevocationPort {
  Future<void> revoke(OnboardingCredentialMaterial material);
}

class OnboardingCredentialException implements Exception {
  const OnboardingCredentialException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'OnboardingCredentialException($code)';
}

void _validateOpaque(String value, String label, {required int maximumLength}) {
  if (value.isEmpty ||
      value.length > maximumLength ||
      value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw OnboardingCredentialException(
      'invalid_${label.replaceAll(' ', '_')}',
      'The stored $label is invalid.',
    );
  }
}
