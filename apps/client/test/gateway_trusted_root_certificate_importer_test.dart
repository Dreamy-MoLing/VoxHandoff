import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/gateway_trusted_root_certificate_importer.dart';
import 'package:agent_talk_client/infrastructure/security/private_ca_certificate_picker.dart';
import 'package:agent_talk_client/infrastructure/security/secure_pairing_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'imports a new CA while preserving the paired Gateway audience',
    () async {
      final values = _MemorySecureStore();
      final profileStore = SecureGatewayConnectionProfileStore(values);
      await profileStore.save(
        GatewayConnectionProfile(
          gatewayAudience: 'https://gateway.example',
          trustedRootCertificates: const [1, 2, 3],
        ),
      );
      final picker = _FakeCertificatePicker(
        '  -----BEGIN CERTIFICATE-----\nnew-ca\n-----END CERTIFICATE-----  ',
      );

      final imported = await SecureGatewayTrustedRootCertificateImporter(
        profileStore: profileStore,
        certificatePicker: picker,
      ).import();

      final profile = await profileStore.load();
      expect(imported, isTrue);
      expect(picker.calls, 1);
      expect(profile?.gatewayAudience, 'https://gateway.example');
      expect(
        profile?.trustedRootCertificates,
        '-----BEGIN CERTIFICATE-----\nnew-ca\n-----END CERTIFICATE-----'
            .codeUnits,
      );
    },
  );

  test(
    'rejects an invalid certificate without changing the saved profile',
    () async {
      final values = _MemorySecureStore();
      final profileStore = SecureGatewayConnectionProfileStore(values);
      final original = GatewayConnectionProfile(
        gatewayAudience: 'https://gateway.example',
        trustedRootCertificates: const [1, 2, 3],
      );
      await profileStore.save(original);

      await expectLater(
        SecureGatewayTrustedRootCertificateImporter(
          profileStore: profileStore,
          certificatePicker: _FakeCertificatePicker('not a certificate'),
        ).import(),
        throwsA(isA<PrivateCaCertificatePickerException>()),
      );

      final profile = await profileStore.load();
      expect(profile?.gatewayAudience, original.gatewayAudience);
      expect(
        profile?.trustedRootCertificates,
        original.trustedRootCertificates,
      );
    },
  );

  test('requires an existing paired profile before saving a CA', () async {
    await expectLater(
      SecureGatewayTrustedRootCertificateImporter(
        profileStore: SecureGatewayConnectionProfileStore(_MemorySecureStore()),
        certificatePicker: _FakeCertificatePicker(
          '-----BEGIN CERTIFICATE-----\nca\n-----END CERTIFICATE-----',
        ),
      ).import(),
      throwsA(
        isA<GatewayTrustedRootCertificateImportException>().having(
          (error) => error.code,
          'code',
          'gateway_pairing_required',
        ),
      ),
    );
  });
}

class _FakeCertificatePicker implements PrivateCaCertificatePicker {
  _FakeCertificatePicker(this.certificate);

  final String? certificate;
  var calls = 0;

  @override
  Future<String?> pick() async {
    calls += 1;
    return certificate;
  }
}

class _MemorySecureStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
