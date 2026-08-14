import 'dart:convert';

import 'package:flutter/services.dart';

const privateCaCertificateMaxBytes = 131072;

abstract interface class PrivateCaCertificatePicker {
  Future<String?> pick();
}

class PrivateCaCertificatePickerException implements Exception {
  const PrivateCaCertificatePickerException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PrivateCaCertificatePickerException($code)';
}

class PlatformPrivateCaCertificatePicker implements PrivateCaCertificatePicker {
  const PlatformPrivateCaCertificatePicker();

  static const _channel = MethodChannel('agent_talk/private_ca_certificate');

  @override
  Future<String?> pick() async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'pickPrivateCaCertificate',
      );
      if (bytes == null) return null;
      return decodePrivateCaCertificate(bytes);
    } on MissingPluginException {
      throw const PrivateCaCertificatePickerException(
        'picker_unavailable',
        'Certificate file import is unavailable on this platform.',
      );
    } on PlatformException {
      throw const PrivateCaCertificatePickerException(
        'picker_failed',
        'Certificate file could not be imported. Choose a PEM CA certificate.',
      );
    }
  }
}

String decodePrivateCaCertificate(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > privateCaCertificateMaxBytes) {
    throw const PrivateCaCertificatePickerException(
      'certificate_size_invalid',
      'The certificate file is empty or too large.',
    );
  }

  final text = utf8.decode(bytes, allowMalformed: false).trim();
  final hasCertificate = RegExp(
    r'-----BEGIN CERTIFICATE-----[\s\S]+-----END CERTIFICATE-----',
  ).hasMatch(text);
  final hasPrivateKey = RegExp(
    r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----',
  ).hasMatch(text);
  if (!hasCertificate || hasPrivateKey) {
    throw const PrivateCaCertificatePickerException(
      'certificate_format_invalid',
      'Choose a PEM CA certificate, not a key or another file.',
    );
  }
  return text;
}
