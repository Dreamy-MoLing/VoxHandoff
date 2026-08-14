import 'dart:convert';

import 'private_ca_certificate_picker.dart';
import 'secure_pairing_stores.dart';

abstract interface class GatewayTrustedRootCertificateImporter {
  Future<bool> import();
}

class GatewayTrustedRootCertificateImportException implements Exception {
  const GatewayTrustedRootCertificateImportException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'GatewayTrustedRootCertificateImportException($code)';
}

class SecureGatewayTrustedRootCertificateImporter
    implements GatewayTrustedRootCertificateImporter {
  const SecureGatewayTrustedRootCertificateImporter({
    required this.profileStore,
    required this.certificatePicker,
  });

  final SecureGatewayConnectionProfileStore profileStore;
  final PrivateCaCertificatePicker certificatePicker;

  @override
  Future<bool> import() async {
    final certificate = await certificatePicker.pick();
    if (certificate == null) return false;

    final normalizedCertificate = decodePrivateCaCertificate(
      utf8.encode(certificate),
    );
    final profile = await _loadProfile();
    if (profile == null) {
      throw const GatewayTrustedRootCertificateImportException(
        'gateway_pairing_required',
        'Pair the device before importing a Gateway trust certificate.',
      );
    }

    final updatedProfile = GatewayConnectionProfile(
      gatewayAudience: profile.gatewayAudience,
      trustedRootCertificates: utf8.encode(normalizedCertificate),
    );
    try {
      await profileStore.save(updatedProfile);
    } on FormatException {
      throw const GatewayTrustedRootCertificateImportException(
        'gateway_profile_invalid',
        'The imported Gateway trust certificate was rejected.',
      );
    } on Object {
      throw const GatewayTrustedRootCertificateImportException(
        'gateway_profile_save_failed',
        'The Gateway trust certificate could not be saved. The existing profile was kept.',
      );
    }
    return true;
  }

  Future<GatewayConnectionProfile?> _loadProfile() async {
    try {
      return await profileStore.load();
    } on Object {
      throw const GatewayTrustedRootCertificateImportException(
        'gateway_profile_invalid',
        'The saved Gateway profile is invalid. The existing profile was kept.',
      );
    }
  }
}
