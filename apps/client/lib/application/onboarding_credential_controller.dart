import '../domain/onboarding_credential.dart';

class OnboardingCredentialController {
  OnboardingCredentialController({
    required OnboardingCredentialVault vault,
    required OnboardingCredentialRevocationPort revocationPort,
  }) {
    _vault = vault;
    _revocationPort = revocationPort;
  }

  late final OnboardingCredentialVault _vault;
  late final OnboardingCredentialRevocationPort _revocationPort;

  Future<OnboardingCredentialReference?> activeReference() =>
      _vault.loadReference();

  Future<void> revokeActive() async {
    final reference = await _vault.loadReference();
    if (reference == null) {
      throw const OnboardingCredentialException(
        'credential_not_found',
        '本机没有可撤销的手机配对凭据。',
      );
    }
    final material = await _vault.readMaterial(reference.credentialId);
    if (material == null) {
      throw const OnboardingCredentialException(
        'credential_not_found',
        '本机没有可撤销的手机配对凭据。',
      );
    }
    await _revocationPort.revoke(material);
    await _vault.revoke(reference.credentialId);
  }
}
