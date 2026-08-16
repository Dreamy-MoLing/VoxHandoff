import 'dart:convert';

import 'device_key_vault.dart';
import 'private_ca_certificate_picker.dart';
import 'secure_pairing_stores.dart';

class SecureRemoteSttTrustedRootCertificateStore {
  const SecureRemoteSttTrustedRootCertificateStore(this._store);

  static const _key = 'voxhandoff.v1.remote-stt-trusted-root-certificate';
  final SecureValueStore _store;

  Future<void> save(String certificate) async {
    final normalized = decodePrivateCaCertificate(utf8.encode(certificate));
    await _store.write(_key, normalized);
  }

  Future<List<int>?> load() async {
    final certificate = await _store.read(_key);
    if (certificate == null) return null;
    return utf8.encode(decodePrivateCaCertificate(utf8.encode(certificate)));
  }
}

Future<List<int>?> loadRemoteSttTrustedRootCertificates(
  SecureValueStore store,
) async {
  final remoteSttCertificate = await SecureRemoteSttTrustedRootCertificateStore(
    store,
  ).load();
  if (remoteSttCertificate != null) return remoteSttCertificate;
  final profile = await SecureGatewayConnectionProfileStore(store).load();
  return profile?.trustedRootCertificates;
}
