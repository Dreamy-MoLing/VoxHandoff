import 'dart:convert';

import 'package:agent_talk_client/infrastructure/security/private_ca_certificate_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a PEM certificate and trims transport whitespace', () {
    final certificate = decodePrivateCaCertificate(
      utf8.encode(
        '  -----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----  ',
      ),
    );

    expect(
      certificate,
      '-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----',
    );
  });

  test(
    'rejects non-certificates, private keys, malformed UTF-8, and oversize files',
    () {
      final privateKeyBegin =
          '-----BEGIN RSA '
          'PRIVATE KEY-----';
      final privateKeyEnd =
          '-----END RSA '
          'PRIVATE KEY-----';
      expect(
        () => decodePrivateCaCertificate(utf8.encode('not a certificate')),
        throwsA(isA<PrivateCaCertificatePickerException>()),
      );
      expect(
        () => decodePrivateCaCertificate(
          utf8.encode(
            '-----BEGIN CERTIFICATE-----\nabc\n-----END CERTIFICATE-----\n'
            '$privateKeyBegin\nkey-material\n$privateKeyEnd',
          ),
        ),
        throwsA(isA<PrivateCaCertificatePickerException>()),
      );
      expect(
        () => decodePrivateCaCertificate([0xff, 0xfe]),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => decodePrivateCaCertificate(
          List.filled(privateCaCertificateMaxBytes + 1, 65),
        ),
        throwsA(isA<PrivateCaCertificatePickerException>()),
      );
    },
  );
}
