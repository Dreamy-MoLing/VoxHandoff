import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/infrastructure/security/remote_stt_trusted_root_certificate_store.dart';
import 'package:agent_talk_client/infrastructure/security/secure_pairing_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prefers the dedicated remote STT CA over the Gateway fallback',
    () async {
      final values = _MemorySecureStore();
      final gateway = SecureGatewayConnectionProfileStore(values);
      await gateway.save(
        GatewayConnectionProfile(
          gatewayAudience: 'https://gateway.example',
          trustedRootCertificates: 'gateway-ca'.codeUnits,
        ),
      );
      final dedicated = SecureRemoteSttTrustedRootCertificateStore(values);
      await dedicated.save(
        '-----BEGIN CERTIFICATE-----\nremote-ca\n-----END CERTIFICATE-----',
      );

      expect(
        await loadRemoteSttTrustedRootCertificates(values),
        '-----BEGIN CERTIFICATE-----\nremote-ca\n-----END CERTIFICATE-----'
            .codeUnits,
      );
    },
  );

  test('falls back to the paired Gateway CA for existing users', () async {
    final values = _MemorySecureStore();
    await SecureGatewayConnectionProfileStore(values).save(
      GatewayConnectionProfile(
        gatewayAudience: 'https://gateway.example',
        trustedRootCertificates: 'gateway-ca'.codeUnits,
      ),
    );

    expect(
      await loadRemoteSttTrustedRootCertificates(values),
      'gateway-ca'.codeUnits,
    );
  });
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
