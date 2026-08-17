import 'dart:convert';

import 'package:agent_talk_client/domain/qr_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 17, 12, 0);

  test('parses the host QR payload and canonicalizes the SPKI pin', () {
    final payload = QrPairingPayload.parse(
      jsonEncode({
        'protocol_version': 1,
        'bridge_endpoint': 'https://bridge.example.test:9443/pairing',
        'server_id': 'server-synthetic-1',
        'pairing_session_id': 'session-synthetic-1',
        'spki_pin': base64Encode(List<int>.filled(32, 7)),
        'pairing_token': 'synthetic-pairing-token',
        'expires_at': '2026-08-17T12:03:00Z',
      }),
      now: now,
    );

    expect(payload.protocolVersion, 1);
    expect(
      payload.bridgeEndpoint.toString(),
      'https://bridge.example.test:9443/pairing',
    );
    expect(payload.spkiPin, 'sha256/${base64Encode(List<int>.filled(32, 7))}');
    expect(payload.isExpired(now), isFalse);
  });

  test(
    'accepts the explicit sha256 pin prefix and numeric protocol version',
    () {
      final payload = QrPairingPayload.fromJson({
        'protocol_version': '1',
        'bridge_endpoint': 'https://bridge.example.test',
        'server_id': 'server-synthetic-1',
        'pairing_session_id': 'session-synthetic-1',
        'spki_pin': 'sha256:${base64Encode(List<int>.filled(32, 9))}',
        'pairing_token': 'synthetic-pairing-token',
        'expires_at': '2026-08-17T12:04:00Z',
      }, now: now);

      expect(payload.protocolVersion, 1);
      expect(
        payload.spkiPin,
        'sha256/${base64Encode(List<int>.filled(32, 9))}',
      );
    },
  );

  test(
    'rejects unsupported versions, expired payloads, and unsafe endpoints',
    () {
      final valid = <String, Object?>{
        'protocol_version': 1,
        'bridge_endpoint': 'https://bridge.example.test',
        'server_id': 'server-synthetic-1',
        'pairing_session_id': 'session-synthetic-1',
        'spki_pin': base64Encode(List<int>.filled(32, 7)),
        'pairing_token': 'synthetic-pairing-token',
        'expires_at': '2026-08-17T12:03:00Z',
      };

      expect(
        () => QrPairingPayload.fromJson({
          ...valid,
          'protocol_version': 2,
        }, now: now),
        throwsA(
          isA<QrPairingPayloadException>().having(
            (error) => error.code,
            'code',
            'unsupported_protocol_version',
          ),
        ),
      );
      expect(
        () => QrPairingPayload.fromJson({
          ...valid,
          'expires_at': '2026-08-17T11:59:59Z',
        }, now: now),
        throwsA(
          isA<QrPairingPayloadException>().having(
            (error) => error.code,
            'code',
            'expired',
          ),
        ),
      );
      expect(
        () => QrPairingPayload.fromJson({
          ...valid,
          'bridge_endpoint': 'https://user@bridge.example.test/pair',
        }, now: now),
        throwsA(
          isA<QrPairingPayloadException>().having(
            (error) => error.code,
            'code',
            'unsafe_bridge_endpoint',
          ),
        ),
      );
    },
  );

  test('rejects pins that are not a SHA-256 digest', () {
    final invalid = <String, Object?>{
      'protocol_version': 1,
      'bridge_endpoint': 'https://bridge.example.test',
      'server_id': 'server-synthetic-1',
      'pairing_session_id': 'session-synthetic-1',
      'spki_pin': 'sha1/not-a-pin',
      'pairing_token': 'synthetic-pairing-token',
      'expires_at': '2026-08-17T12:03:00Z',
    };

    expect(
      () => QrPairingPayload.fromJson(invalid, now: now),
      throwsA(
        isA<QrPairingPayloadException>().having(
          (error) => error.code,
          'code',
          'invalid_spki_pin',
        ),
      ),
    );
  });
}
