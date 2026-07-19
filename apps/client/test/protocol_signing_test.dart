import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

String hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  test('Dart canonical framing matches the TypeScript fixture', () {
    final payload = canonicalSignedPayload('agent-talk/test/v1', const [
      SignedPayloadField('alpha', 'one'),
      SignedPayloadField('beta', [2, 3]),
    ]);

    expect(
      hex(payload),
      '6167656e742d74616c6b2d7369676e65642d7061796c6f6164007631'
      '000000126167656e742d74616c6b2f746573742f76310000000200000005'
      '616c706861000000036f6e650000000462657461000000020203',
    );
  });

  test('pairing framing canonicalizes scopes and binds the audience', () {
    final fingerprint = 'sha256:${List.filled(64, 'a').join()}';
    final proof = pairingProofPayload(
      pairingId: 'pairing-1',
      challenge: List.filled(4, 7),
      gatewayAudience: 'https://gateway.example',
      deviceFingerprint: fingerprint,
      requestedScopes: const ['send', 'observe'],
    );
    final reordered = pairingProofPayload(
      pairingId: 'pairing-1',
      challenge: List.filled(4, 7),
      gatewayAudience: 'https://gateway.example',
      deviceFingerprint: fingerprint,
      requestedScopes: const ['observe', 'send'],
    );
    final otherAudience = pairingProofPayload(
      pairingId: 'pairing-1',
      challenge: List.filled(4, 7),
      gatewayAudience: 'https://other.example',
      deviceFingerprint: fingerprint,
      requestedScopes: const ['observe', 'send'],
    );

    expect(proof, orderedEquals(reordered));
    expect(proof, isNot(orderedEquals(otherAudience)));
    final fixture = pairingProofPayload(
      pairingId: 'p',
      challenge: const [7],
      gatewayAudience: 'https://g',
      deviceFingerprint: 'fp',
      requestedScopes: const ['send', 'observe'],
    );
    expect(
      hex(fixture),
      '6167656e742d74616c6b2d7369676e65642d7061796c6f6164007631'
      '0000001b6167656e742d74616c6b2f70616972696e672d70726f6f662f7631'
      '000000060000000a70616972696e675f69640000000170000000096368616c6c'
      '656e6765000000010700000010676174657761795f61756469656e6365000000'
      '0968747470733a2f2f67000000126465766963655f66696e6765727072696e74'
      '0000000266700000000973636f70652e303030000000076f6273657276650000'
      '000973636f70652e3030310000000473656e64',
    );
  });

  test('invalid and duplicate scopes fail before signing', () {
    expect(
      () => normalizeDeviceScopes(const ['send', 'send']),
      throwsA(
        isA<DeviceSigningContractException>().having(
          (error) => error.code,
          'code',
          DeviceSigningErrorCode.duplicateScope,
        ),
      ),
    );
    expect(
      () => normalizeDeviceScopes(const ['owner']),
      throwsA(
        isA<DeviceSigningContractException>().having(
          (error) => error.code,
          'code',
          DeviceSigningErrorCode.invalidScope,
        ),
      ),
    );
  });
}
