import 'dart:convert';
import 'dart:io';

import 'package:agent_talk_client/infrastructure/security/spki_pin_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final certificateDer = _readFixtureCertificate();
  final fixturePin = SpkiPinValidator.spkiPinForCertificateDer(certificateDer);

  test('extracts and validates the synthetic certificate SPKI pin', () {
    expect(fixturePin, 'sha256/TVF8OvnsOOKWQBRu45lGpokEw57kafCPyiXDxRqsUJI=');

    final validator = SpkiPinValidator(
      currentPin: fixturePin,
      backupPin: _syntheticPin(0x11),
    );
    validator.validateCertificateDer(certificateDer);
    expect(validator.pins.accepts(fixturePin), isTrue);
    expect(
      () => SpkiPinValidator(
        currentPin: _syntheticPin(0x22),
      ).validateCertificateDer(certificateDer),
      throwsA(
        isA<SpkiPinValidationException>().having(
          (error) => error.code,
          'code',
          'pin_mismatch',
        ),
      ),
    );
  });

  test('rotates only the backup pin while retaining the current pin', () {
    final validator = SpkiPinValidator(
      currentPin: fixturePin,
      backupPin: _syntheticPin(0x11),
    );
    final rotated = validator.rotateBackup(_syntheticPin(0x33));

    expect(rotated.pins.currentPin, fixturePin);
    expect(rotated.pins.backupPin, _syntheticPin(0x33));
    expect(rotated.pins.accepts(fixturePin), isTrue);
    expect(rotated.pins.accepts(_syntheticPin(0x11)), isFalse);
  });

  test('fails closed for malformed DER and a missing certificate', () {
    final validator = SpkiPinValidator(currentPin: fixturePin);
    expect(
      () => validator.validateCertificateDer(certificateDer.sublist(0, 8)),
      throwsA(
        isA<SpkiPinValidationException>().having(
          (error) => error.code,
          'code',
          'malformed_certificate',
        ),
      ),
    );
    expect(
      () => validator.validateCertificate(null),
      throwsA(
        isA<SpkiPinValidationException>()
            .having((error) => error.code, 'code', 'certificate_missing')
            .having(
              (error) => error.safeMessage,
              'safeMessage',
              '服务器身份发生变化，需要重新配对',
            ),
      ),
    );
  });
}

List<int> _readFixtureCertificate() {
  final pem = File('test/fixtures/agent_talk_test_ca.pem').readAsStringSync();
  final body = pem
      .replaceFirst('-----BEGIN CERTIFICATE-----', '')
      .replaceFirst('-----END CERTIFICATE-----', '')
      .replaceAll(RegExp(r'\s'), '');
  return base64.decode(body);
}

String _syntheticPin(int byte) =>
    'sha256/${base64Encode(List<int>.filled(32, byte))}';
