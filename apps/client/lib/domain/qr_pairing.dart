import 'dart:convert';

const _maximumPairingPayloadBytes = 16 * 1024;
const _maximumPairingLifetime = Duration(minutes: 5);

/// The fields carried out-of-band by a host-generated pairing QR code.
class QrPairingPayload {
  const QrPairingPayload({
    required this.protocolVersion,
    required this.bridgeEndpoint,
    required this.serverId,
    required this.pairingSessionId,
    required this.spkiPin,
    required this.pairingToken,
    required this.expiresAt,
  });

  static const supportedProtocolVersion = 1;

  final int protocolVersion;
  final Uri bridgeEndpoint;
  final String serverId;
  final String pairingSessionId;

  /// Canonical form is `sha256/<base64(SHA-256(SPKI))>`.
  final String spkiPin;

  final String pairingToken;
  final DateTime expiresAt;

  bool isExpired([DateTime? now]) =>
      !expiresAt.isAfter((now ?? DateTime.now()).toUtc());

  /// Parses the JSON object emitted by the Companion Bridge.
  ///
  /// The optional clock is injectable so expiry behavior can be tested without
  /// putting a real token or a real host endpoint in a fixture.
  factory QrPairingPayload.parse(String encoded, {DateTime? now}) {
    if (encoded.length > _maximumPairingPayloadBytes) {
      throw const QrPairingPayloadException(
        'payload_too_large',
        'The pairing QR payload is too large.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const QrPairingPayloadException(
        'invalid_json',
        'The pairing QR payload is not valid JSON.',
      );
    }
    return QrPairingPayload.fromJson(decoded, now: now);
  }

  factory QrPairingPayload.fromJson(Object? value, {DateTime? now}) {
    if (value is! Map) {
      throw const QrPairingPayloadException(
        'invalid_shape',
        'The pairing QR payload must be a JSON object.',
      );
    }

    final protocolVersion = _requiredProtocolVersion(value);
    if (protocolVersion != supportedProtocolVersion) {
      throw const QrPairingPayloadException(
        'unsupported_protocol_version',
        'This pairing QR uses an unsupported protocol version.',
      );
    }

    final endpoint = _requiredBridgeEndpoint(value);
    final serverId = _requiredOpaque(value, 'server_id', maximumBytes: 128);
    final pairingSessionId = _requiredOpaque(
      value,
      'pairing_session_id',
      maximumBytes: 256,
    );
    final spkiPin = _canonicalSpkiPin(_requiredString(value, 'spki_pin'));
    final pairingToken = _requiredOpaque(
      value,
      'pairing_token',
      maximumBytes: 512,
    );
    final expiresAt = _requiredExpiry(value['expires_at']);
    final currentTime = (now ?? DateTime.now()).toUtc();
    if (!expiresAt.isAfter(currentTime)) {
      throw const QrPairingPayloadException(
        'expired',
        'The pairing QR code has expired. Generate a new code on the host.',
      );
    }
    if (expiresAt.isAfter(currentTime.add(_maximumPairingLifetime))) {
      throw const QrPairingPayloadException(
        'expiry_too_far',
        'The pairing QR lifetime exceeds the allowed limit.',
      );
    }

    return QrPairingPayload(
      protocolVersion: protocolVersion,
      bridgeEndpoint: endpoint,
      serverId: serverId,
      pairingSessionId: pairingSessionId,
      spkiPin: spkiPin,
      pairingToken: pairingToken,
      expiresAt: expiresAt,
    );
  }

  @override
  String toString() =>
      'QrPairingPayload(protocolVersion: $protocolVersion, '
      'bridgeEndpoint: $bridgeEndpoint, serverId: $serverId, '
      'pairingSessionId: $pairingSessionId, expiresAt: $expiresAt, '
      'redacted: true)';
}

class QrPairingPayloadException implements Exception {
  const QrPairingPayloadException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'QrPairingPayloadException($code): $message';
}

int _requiredProtocolVersion(Map value) {
  final raw = value['protocol_version'];
  if (raw is int) return raw;
  if (raw is String && RegExp(r'^[0-9]{1,3}$').hasMatch(raw)) {
    return int.parse(raw);
  }
  throw const QrPairingPayloadException(
    'invalid_protocol_version',
    'The pairing QR protocol version is invalid.',
  );
}

String _requiredString(Map value, String key, {int maximumBytes = 512}) {
  final raw = value[key];
  if (raw is! String || raw.isEmpty || utf8.encode(raw).length > maximumBytes) {
    throw QrPairingPayloadException(
      'invalid_$key',
      'The pairing QR field "$key" is invalid.',
    );
  }
  if (raw.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw QrPairingPayloadException(
      'invalid_$key',
      'The pairing QR field "$key" contains control characters.',
    );
  }
  return raw;
}

String _requiredOpaque(Map value, String key, {required int maximumBytes}) =>
    _requiredString(value, key, maximumBytes: maximumBytes);

Uri _requiredBridgeEndpoint(Map value) {
  final encoded = _requiredString(value, 'bridge_endpoint', maximumBytes: 2048);
  final endpoint = Uri.tryParse(encoded);
  if (endpoint == null ||
      endpoint.scheme.toLowerCase() != 'https' ||
      !endpoint.hasAuthority ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasQuery ||
      endpoint.hasFragment ||
      endpoint.path.length > 2048 ||
      endpoint.pathSegments.any((segment) => segment == '..')) {
    throw const QrPairingPayloadException(
      'unsafe_bridge_endpoint',
      'The pairing QR Bridge endpoint is not a safe HTTPS URL.',
    );
  }
  return endpoint;
}

DateTime _requiredExpiry(Object? raw) {
  if (raw is! String || raw.isEmpty || !raw.endsWith('Z')) {
    throw const QrPairingPayloadException(
      'invalid_expires_at',
      'The pairing QR expiry must be a UTC timestamp.',
    );
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw const QrPairingPayloadException(
      'invalid_expires_at',
      'The pairing QR expiry is invalid.',
    );
  }
  return parsed.toUtc();
}

String _canonicalSpkiPin(String encoded) {
  final value = encoded.trim();
  final body = value.startsWith('sha256/')
      ? value.substring('sha256/'.length)
      : value.startsWith('sha256:')
      ? value.substring('sha256:'.length)
      : value;
  List<int> decoded;
  try {
    decoded = base64.decode(body);
  } on FormatException {
    throw const QrPairingPayloadException(
      'invalid_spki_pin',
      'The pairing QR SPKI pin is not valid base64.',
    );
  }
  if (decoded.length != 32) {
    throw const QrPairingPayloadException(
      'invalid_spki_pin',
      'The pairing QR SPKI pin must contain a SHA-256 digest.',
    );
  }
  return 'sha256/${base64Encode(decoded)}';
}
