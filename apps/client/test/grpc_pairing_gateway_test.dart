import 'package:agent_talk_client/domain/device_pairing.dart';
import 'package:agent_talk_client/infrastructure/gateway/grpc_pairing_gateway.dart';
import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

class FakePairingUnaryRpc implements PairingUnaryRpc {
  BeginPairingResponse beginResponse = BeginPairingResponse();
  CompletePairingResponse completeResponse = CompletePairingResponse();
  ConfirmPairingResponse confirmResponse = ConfirmPairingResponse();
  RefreshDeviceCredentialResponse refreshResponse =
      RefreshDeviceCredentialResponse();
  Object? beginError;
  Object? completeError;
  Object? confirmError;
  Object? refreshError;
  BeginPairingRequest? beginRequest;
  CompletePairingRequest? completeRequest;
  ConfirmPairingRequest? confirmRequest;
  RefreshDeviceCredentialRequest? refreshRequest;
  CallOptions? beginOptions;
  CallOptions? completeOptions;
  CallOptions? confirmOptions;
  CallOptions? refreshOptions;
  var beginCalls = 0;
  var completeCalls = 0;
  var confirmCalls = 0;
  var refreshCalls = 0;

  @override
  Future<BeginPairingResponse> beginPairing(
    BeginPairingRequest request, {
    CallOptions? options,
  }) async {
    beginCalls += 1;
    beginRequest = request;
    beginOptions = options;
    if (beginError case final Object error) throw error;
    return beginResponse;
  }

  @override
  Future<CompletePairingResponse> completePairing(
    CompletePairingRequest request, {
    CallOptions? options,
  }) async {
    completeCalls += 1;
    completeRequest = request;
    completeOptions = options;
    if (completeError case final Object error) throw error;
    return completeResponse;
  }

  @override
  Future<ConfirmPairingResponse> confirmPairing(
    ConfirmPairingRequest request, {
    CallOptions? options,
  }) async {
    confirmCalls += 1;
    confirmRequest = request;
    confirmOptions = options;
    if (confirmError case final Object error) throw error;
    return confirmResponse;
  }

  @override
  Future<RefreshDeviceCredentialResponse> refreshDeviceCredential(
    RefreshDeviceCredentialRequest request, {
    CallOptions? options,
  }) async {
    refreshCalls += 1;
    refreshRequest = request;
    refreshOptions = options;
    if (refreshError case final Object error) throw error;
    return refreshResponse;
  }
}

void main() {
  group('GrpcPairingGateway', () {
    test(
      'maps all pairing requests and responses without legacy proof use',
      () async {
        final rpc = FakePairingUnaryRpc()
          ..beginResponse = BeginPairingResponse(
            pairingId: 'pairing-1',
            userCode: 'ABCD-EFGH',
            verificationUri: 'https://gateway.example/pair',
            expiresInSeconds: 600,
            deviceProofPayload: [1, 2, 3],
            deviceFingerprint: 'sha256:device',
            gatewayFingerprint: 'sha256:gateway',
            gatewayAudience: 'https://gateway.example',
          )
          ..completeResponse = CompletePairingResponse(
            deviceId: 'device-1',
            scopes: ['observe'],
            credentialId: 'credential-1',
            confirmationPayload: [4, 5, 6],
            gatewayAudience: 'https://gateway.example',
            confirmationExpiresInSeconds: 120,
          )
          ..confirmResponse = ConfirmPairingResponse(
            paired: true,
            deviceId: 'device-1',
            credentialId: 'credential-1',
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            scopes: ['observe'],
            accessExpiresAtUnixMs: Int64(1893456900000),
            refreshExpiresAtUnixMs: Int64(1896048000000),
            gatewayAudience: 'https://gateway.example',
          );
        final gateway = GrpcPairingGateway(
          rpc,
          timeout: const Duration(seconds: 9),
        );

        final begun = await gateway.begin(
          BeginPairingCommand(
            deviceDisplayName: 'Desktop',
            devicePublicKeySpkiDer: [9, 8, 7],
            requestedScopes: ['observe'],
            expectedGatewayAudience: 'https://gateway.example',
          ),
        );
        final completed = await gateway.complete(
          begun.pairingId,
          DeviceSignatureProof(signature: [6, 5, 4]),
        );
        final confirmed = await gateway.confirm(
          begun.pairingId,
          completed.credentialId,
          DeviceSignatureProof(
            credentialId: completed.credentialId,
            nonce: [3, 2, 1],
            signature: [1, 3, 5],
          ),
        );

        expect(rpc.beginRequest!.deviceDisplayName, 'Desktop');
        expect(rpc.beginRequest!.devicePublicKey, [9, 8, 7]);
        expect(rpc.beginRequest!.requestedScopes, ['observe']);
        expect(
          rpc.beginRequest!.expectedGatewayAudience,
          'https://gateway.example',
        );
        expect(rpc.beginOptions!.timeout, const Duration(seconds: 9));
        expect(begun.deviceProofPayload, [1, 2, 3]);

        expect(rpc.completeRequest!.pairingId, 'pairing-1');
        expect(rpc.completeRequest!.deviceProof, isEmpty);
        expect(rpc.completeRequest!.deviceKeyProof.credentialId, isEmpty);
        expect(rpc.completeRequest!.deviceKeyProof.nonce, isEmpty);
        expect(rpc.completeRequest!.deviceKeyProof.signature, [6, 5, 4]);
        expect(
          rpc.completeRequest!.deviceKeyProof.algorithm,
          DeviceSignatureAlgorithm.DEVICE_SIGNATURE_ALGORITHM_ED25519,
        );
        expect(completed.legacyAccessToken, isEmpty);
        expect(completed.legacyRefreshToken, isEmpty);

        expect(rpc.confirmRequest!.pairingId, 'pairing-1');
        expect(rpc.confirmRequest!.credentialId, 'credential-1');
        expect(
          rpc.confirmRequest!.deviceSignature.credentialId,
          'credential-1',
        );
        expect(rpc.confirmRequest!.deviceSignature.nonce, [3, 2, 1]);
        expect(rpc.confirmRequest!.deviceSignature.signature, [1, 3, 5]);
        expect(
          rpc.confirmRequest!.deviceSignature.algorithm,
          DeviceSignatureAlgorithm.DEVICE_SIGNATURE_ALGORITHM_ED25519,
        );
        expect(confirmed.paired, isTrue);
        expect(
          confirmed.accessExpiresAt,
          DateTime.fromMillisecondsSinceEpoch(1893456900000, isUtc: true),
        );
        expect(
          confirmed.refreshExpiresAt,
          DateTime.fromMillisecondsSinceEpoch(1896048000000, isUtc: true),
        );
      },
    );

    test(
      'uses structured Gateway code and never exposes remote message',
      () async {
        final rpc = FakePairingUnaryRpc()
          ..completeError = const GrpcError.custom(
            StatusCode.failedPrecondition,
            'secret-bearing remote diagnostics',
            null,
            null,
            {'agent-talk-error-code': 'pairing_not_approved'},
          );
        final gateway = GrpcPairingGateway(rpc);

        final error = await _capturePairingError(
          gateway.complete('pairing-1', DeviceSignatureProof(signature: [1])),
        );

        expect(error.operation, PairingOperation.complete);
        expect(error.disposition, PairingGatewayDisposition.rejected);
        expect(error.code, 'pairing_not_approved');
        expect(
          error.safeMessage,
          'The owner has not approved this device yet.',
        );
        expect(error.safeMessage, isNot(contains('secret-bearing')));
      },
    );

    test(
      'rotates an expired device credential through the signed refresh RPC',
      () async {
        final rpc = FakePairingUnaryRpc()
          ..refreshResponse = RefreshDeviceCredentialResponse(
            deviceId: 'device-1',
            credentialId: 'credential-1',
            accessToken: 'NEW_ACCESS_TOKEN_0123456789_abcdef',
            refreshToken: 'NEW_REFRESH_TOKEN_0123456789_abcdefghijklmnop',
            scopes: ['observe', 'send'],
            accessExpiresAtUnixMs: Int64(1893456900000),
            refreshExpiresAtUnixMs: Int64(1896048000000),
            gatewayAudience: 'https://gateway.example',
          );
        final gateway = GrpcPairingGateway(rpc);
        final refreshed = await gateway.refresh(
          DeviceCredentialBundle(
            keyReference: '0123456789abcdef0123456789abcdef',
            deviceId: 'device-1',
            credentialId: 'credential-1',
            gatewayAudience: 'https://gateway.example',
            scopes: const ['observe', 'send'],
            accessToken: 'ACCESS_TOKEN_0123456789_abcdef',
            refreshToken: 'REFRESH_TOKEN_0123456789_abcdefghijklmnop',
            accessExpiresAt: DateTime.utc(2030, 1, 1),
            refreshExpiresAt: DateTime.utc(2030, 2, 1),
          ),
          DeviceSignatureProof(
            credentialId: 'credential-1',
            nonce: [1, 2, 3],
            signature: [4, 5, 6],
          ),
        );

        expect(rpc.refreshCalls, 1);
        expect(rpc.refreshRequest!.credentialId, 'credential-1');
        expect(rpc.refreshRequest!.refreshToken, contains('REFRESH_TOKEN'));
        expect(
          rpc.refreshRequest!.deviceSignature.credentialId,
          'credential-1',
        );
        expect(rpc.refreshRequest!.deviceSignature.nonce, [1, 2, 3]);
        expect(refreshed.accessToken, contains('NEW_ACCESS_TOKEN'));
        expect(refreshed.refreshToken, contains('NEW_REFRESH_TOKEN'));
        expect(refreshed.generation, 2);
      },
    );

    test('marks transport failure uncertain and does not retry', () async {
      final rpc = FakePairingUnaryRpc()
        ..beginError = const GrpcError.unavailable(
          'temporary transport details',
        );
      final gateway = GrpcPairingGateway(rpc);

      final error = await _capturePairingError(
        gateway.begin(
          BeginPairingCommand(
            deviceDisplayName: 'Desktop',
            devicePublicKeySpkiDer: [1],
            requestedScopes: ['observe'],
            expectedGatewayAudience: 'https://gateway.example',
          ),
        ),
      );

      expect(rpc.beginCalls, 1);
      expect(error.disposition, PairingGatewayDisposition.uncertain);
      expect(error.code, 'outcome_uncertain');
      expect(error.safeMessage, isNot(contains('transport details')));
    });

    test('ignores unknown trailer codes', () async {
      final rpc = FakePairingUnaryRpc()
        ..confirmError = const GrpcError.custom(
          StatusCode.failedPrecondition,
          'remote message',
          null,
          null,
          {'agent-talk-error-code': 'invented_remote_code'},
        );
      final gateway = GrpcPairingGateway(rpc);

      final error = await _capturePairingError(
        gateway.confirm(
          'pairing-1',
          'credential-1',
          DeviceSignatureProof(signature: [1]),
        ),
      );

      expect(error.disposition, PairingGatewayDisposition.rejected);
      expect(error.code, 'gateway_rejected');
      expect(error.safeMessage, isNot(contains('remote message')));
    });
  });
}

Future<PairingGatewayCallException> _capturePairingError(
  Future<Object?> operation,
) async {
  try {
    await operation;
  } on PairingGatewayCallException catch (error) {
    return error;
  }
  fail('Expected PairingGatewayCallException.');
}
