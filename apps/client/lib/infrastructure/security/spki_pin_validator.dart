import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// The pin format used by the onboarding QR and the secure storage record.
String canonicalizeSpkiPin(String value) {
  final trimmed = value.trim();
  final body = trimmed.startsWith('sha256/')
      ? trimmed.substring('sha256/'.length)
      : trimmed.startsWith('sha256:')
      ? trimmed.substring('sha256:'.length)
      : trimmed;
  List<int> digest;
  try {
    digest = base64.decode(body);
  } on FormatException {
    throw const SpkiPinConfigurationException(
      'invalid_pin',
      'The SPKI pin is not valid base64.',
    );
  }
  if (digest.length != 32) {
    throw const SpkiPinConfigurationException(
      'invalid_pin',
      'The SPKI pin must contain a SHA-256 digest.',
    );
  }
  return 'sha256/${base64Encode(digest)}';
}

/// The current pin and the one pre-generated for the next certificate.
class SpkiPinSet {
  factory SpkiPinSet({required String currentPin, String? backupPin}) {
    final current = canonicalizeSpkiPin(currentPin);
    final backup = backupPin == null ? null : canonicalizeSpkiPin(backupPin);
    if (backup == current) {
      throw const SpkiPinConfigurationException(
        'duplicate_pin',
        'The backup SPKI pin must differ from the current pin.',
      );
    }
    return SpkiPinSet._(current, backup);
  }

  const SpkiPinSet._(this.currentPin, this.backupPin);

  final String currentPin;
  final String? backupPin;

  bool accepts(String pin) => pin == currentPin || pin == backupPin;

  /// Installs a new backup only after the current set authenticated a TLS
  /// response. The caller must obtain [nextBackupPin] over that pinned channel.
  SpkiPinSet rotateBackup(String nextBackupPin) =>
      SpkiPinSet(currentPin: currentPin, backupPin: nextBackupPin);
}

class SpkiPinValidator {
  SpkiPinValidator({required String currentPin, String? backupPin})
    : pins = SpkiPinSet(currentPin: currentPin, backupPin: backupPin);

  SpkiPinValidator.fromPinSet(this.pins);

  final SpkiPinSet pins;

  bool matchesCertificate(X509Certificate certificate) {
    try {
      return pins.accepts(spkiPinForCertificateDer(certificate.der));
    } on SpkiPinValidationException {
      return false;
    }
  }

  /// Validates the peer certificate exposed by [HttpClientResponse].
  ///
  /// A missing certificate is treated as a failure, including for a plain
  /// HTTP response. No pinning mode silently falls back to an unpinned path.
  void validateCertificate(X509Certificate? certificate) {
    if (certificate == null) {
      throw const SpkiPinValidationException(
        'certificate_missing',
        '服务器身份发生变化，需要重新配对',
      );
    }
    validateCertificateDer(certificate.der);
  }

  void validateCertificateDer(List<int> certificateDer) {
    final actualPin = spkiPinForCertificateDer(certificateDer);
    if (!pins.accepts(actualPin)) {
      throw const SpkiPinValidationException(
        'pin_mismatch',
        '服务器身份发生变化，需要重新配对',
      );
    }
  }

  /// Returns a new validator after a newly issued backup pin was received over
  /// an already authenticated channel.
  SpkiPinValidator rotateBackup(String nextBackupPin) =>
      SpkiPinValidator.fromPinSet(pins.rotateBackup(nextBackupPin));

  /// Computes the canonical SHA-256 SPKI pin from a complete DER certificate.
  static String spkiPinForCertificateDer(List<int> certificateDer) {
    final spki = extractSubjectPublicKeyInfo(certificateDer);
    final digest = Sha256().toSync().hashSync(spki).bytes;
    return 'sha256/${base64Encode(digest)}';
  }

  /// Extracts the exact DER SubjectPublicKeyInfo sequence from an X.509
  /// certificate. The parser is deliberately bounded to the certificate
  /// structure required for pinning and rejects malformed/indefinite DER.
  static List<int> extractSubjectPublicKeyInfo(List<int> certificateDer) {
    if (certificateDer.isEmpty || certificateDer.length > _maximumDerBytes) {
      throw const SpkiPinValidationException(
        'malformed_certificate',
        '服务器身份发生变化，需要重新配对',
      );
    }
    try {
      final certificate = _readElement(certificateDer, 0);
      if (certificate.tag != _sequence ||
          certificate.end != certificateDer.length) {
        throw const FormatException();
      }
      var offset = certificate.contentStart;

      final tbs = _readElement(certificateDer, offset);
      if (tbs.tag != _sequence) throw const FormatException();
      offset = tbs.end;
      final signatureAlgorithm = _readElement(certificateDer, offset);
      if (signatureAlgorithm.tag != _sequence) throw const FormatException();
      offset = signatureAlgorithm.end;
      final signatureValue = _readElement(certificateDer, offset);
      if (signatureValue.tag != _bitString ||
          signatureValue.end != certificate.end ||
          signatureValue.contentStart == signatureValue.end) {
        throw const FormatException();
      }

      var tbsOffset = tbs.contentStart;
      final first = _readElement(certificateDer, tbsOffset);
      if (first.tag == _explicitVersion) {
        final version = _readElement(certificateDer, first.contentStart);
        if (version.tag != _integer || version.end != first.end) {
          throw const FormatException();
        }
        tbsOffset = first.end;
      }
      tbsOffset = _skipExpected(certificateDer, tbsOffset, _integer);
      tbsOffset = _skipExpected(certificateDer, tbsOffset, _sequence);
      tbsOffset = _skipExpected(certificateDer, tbsOffset, _sequence);
      tbsOffset = _skipExpected(certificateDer, tbsOffset, _sequence);
      tbsOffset = _skipExpected(certificateDer, tbsOffset, _sequence);
      final spki = _readElement(certificateDer, tbsOffset);
      if (spki.tag != _sequence) throw const FormatException();

      var spkiOffset = spki.contentStart;
      spkiOffset = _skipExpected(certificateDer, spkiOffset, _sequence);
      final publicKey = _readElement(certificateDer, spkiOffset);
      if (publicKey.tag != _bitString || publicKey.end != spki.end) {
        throw const FormatException();
      }
      if (publicKey.contentStart == publicKey.end ||
          certificateDer[publicKey.contentStart] != 0) {
        throw const FormatException();
      }
      return List.unmodifiable(certificateDer.sublist(spki.start, spki.end));
    } on SpkiPinValidationException {
      rethrow;
    } on Object {
      throw const SpkiPinValidationException(
        'malformed_certificate',
        '服务器身份发生变化，需要重新配对',
      );
    }
  }
}

class SpkiPinConfigurationException implements Exception {
  const SpkiPinConfigurationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SpkiPinConfigurationException($code)';
}

class SpkiPinValidationException implements Exception {
  const SpkiPinValidationException(this.code, this.safeMessage);

  final String code;
  final String safeMessage;

  @override
  String toString() => 'SpkiPinValidationException($code)';
}

const _sequence = 0x30;
const _integer = 0x02;
const _bitString = 0x03;
const _explicitVersion = 0xa0;
const _maximumDerBytes = 64 * 1024;

int _skipExpected(List<int> bytes, int offset, int expectedTag) {
  final element = _readElement(bytes, offset);
  if (element.tag != expectedTag) throw const FormatException();
  return element.end;
}

_DerElement _readElement(List<int> bytes, int offset) {
  if (offset < 0 || offset >= bytes.length) throw const FormatException();
  final start = offset;
  final tag = bytes[offset++];
  if ((tag & 0x1f) == 0x1f || offset >= bytes.length) {
    throw const FormatException();
  }
  final firstLengthByte = bytes[offset++];
  int length;
  if (firstLengthByte < 0x80) {
    length = firstLengthByte;
  } else {
    final lengthBytes = firstLengthByte & 0x7f;
    if (lengthBytes == 0 ||
        lengthBytes > 4 ||
        offset + lengthBytes > bytes.length) {
      throw const FormatException();
    }
    if (bytes[offset] == 0) throw const FormatException();
    length = 0;
    for (var index = 0; index < lengthBytes; index++) {
      length = (length << 8) | bytes[offset++];
    }
    if (length < 0x80) throw const FormatException();
  }
  final contentStart = offset;
  final end = contentStart + length;
  if (end < contentStart || end > bytes.length) throw const FormatException();
  return _DerElement(tag, start, contentStart, end);
}

class _DerElement {
  const _DerElement(this.tag, this.start, this.contentStart, this.end);

  final int tag;
  final int start;
  final int contentStart;
  final int end;
}
