import 'package:agent_talk_protocol/agent_talk_protocol.dart';
import 'package:grpc/grpc.dart';

import '../../domain/device_pairing.dart';

abstract interface class PairingUnaryRpc {
  Future<BeginPairingResponse> beginPairing(
    BeginPairingRequest request, {
    CallOptions? options,
  });

  Future<CompletePairingResponse> completePairing(
    CompletePairingRequest request, {
    CallOptions? options,
  });

  Future<ConfirmPairingResponse> confirmPairing(
    ConfirmPairingRequest request, {
    CallOptions? options,
  });
}

class GeneratedPairingUnaryRpc implements PairingUnaryRpc {
  GeneratedPairingUnaryRpc(this._client);

  final PairingServiceClient _client;

  @override
  Future<BeginPairingResponse> beginPairing(
    BeginPairingRequest request, {
    CallOptions? options,
  }) => _client.beginPairing(request, options: options);

  @override
  Future<CompletePairingResponse> completePairing(
    CompletePairingRequest request, {
    CallOptions? options,
  }) => _client.completePairing(request, options: options);

  @override
  Future<ConfirmPairingResponse> confirmPairing(
    ConfirmPairingRequest request, {
    CallOptions? options,
  }) => _client.confirmPairing(request, options: options);
}

class GrpcPairingGateway implements PairingGatewayPort {
  GrpcPairingGateway(this._rpc, {this.timeout = const Duration(seconds: 15)});

  static const _errorCodeTrailer = 'agent-talk-error-code';

  static const Map<String, String> _safeMessages = {
    'invalid_request': 'The Gateway rejected the pairing request.',
    'rate_limited': 'Too many pairing attempts. Wait before trying again.',
    'pairing_not_found': 'The pairing request no longer exists.',
    'pairing_expired': 'The pairing request expired. Begin again.',
    'pairing_not_approved': 'The owner has not approved this device yet.',
    'pairing_conflict':
        'The pairing state changed. Review it before continuing.',
    'fingerprint_mismatch': 'The device or Gateway identity did not match.',
    'scope_not_allowed': 'The requested device permissions are not allowed.',
    'authentication_failed': 'The Gateway could not authenticate this device.',
    'authorization_denied': 'This device is not authorized for that operation.',
    'proof_invalid': 'The Gateway rejected the device proof.',
    'nonce_replayed': 'The device proof nonce was already used.',
    'credential_not_found': 'The device credential no longer exists.',
    'credential_revoked': 'The device credential was revoked.',
    'credential_expired': 'The device credential expired.',
    'refresh_replayed': 'The refresh credential was already used.',
  };

  final PairingUnaryRpc _rpc;
  final Duration timeout;

  CallOptions get _options => CallOptions(timeout: timeout);

  @override
  Future<BegunPairing> begin(BeginPairingCommand command) async {
    final response = await _call(
      PairingOperation.begin,
      () => _rpc.beginPairing(
        BeginPairingRequest(
          deviceDisplayName: command.deviceDisplayName,
          devicePublicKey: command.devicePublicKeySpkiDer,
          requestedScopes: command.requestedScopes,
          expectedGatewayAudience: command.expectedGatewayAudience,
        ),
        options: _options,
      ),
    );
    return BegunPairing(
      pairingId: response.pairingId,
      userCode: response.userCode,
      verificationUri: response.verificationUri,
      expiresInSeconds: response.expiresInSeconds,
      deviceProofPayload: response.deviceProofPayload,
      deviceFingerprint: response.deviceFingerprint,
      gatewayFingerprint: response.gatewayFingerprint,
      gatewayAudience: response.gatewayAudience,
    );
  }

  @override
  Future<CompletedPairing> complete(
    String pairingId,
    DeviceSignatureProof proof,
  ) async {
    final response = await _call(
      PairingOperation.complete,
      () => _rpc.completePairing(
        CompletePairingRequest(
          pairingId: pairingId,
          deviceProof: '',
          deviceKeyProof: _signature(proof),
        ),
        options: _options,
      ),
    );
    return CompletedPairing(
      deviceId: response.deviceId,
      legacyAccessToken: response.accessToken,
      legacyRefreshToken: response.refreshToken,
      approvedScopes: response.scopes,
      credentialId: response.credentialId,
      confirmationPayload: response.confirmationPayload,
      gatewayAudience: response.gatewayAudience,
      confirmationExpiresInSeconds: response.confirmationExpiresInSeconds,
    );
  }

  @override
  Future<ConfirmedPairing> confirm(
    String pairingId,
    String credentialId,
    DeviceSignatureProof proof,
  ) async {
    final response = await _call(
      PairingOperation.confirm,
      () => _rpc.confirmPairing(
        ConfirmPairingRequest(
          pairingId: pairingId,
          credentialId: credentialId,
          deviceSignature: _signature(proof),
        ),
        options: _options,
      ),
    );
    return ConfirmedPairing(
      paired: response.paired,
      deviceId: response.deviceId,
      credentialId: response.credentialId,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      approvedScopes: response.scopes,
      accessExpiresAt: DateTime.fromMillisecondsSinceEpoch(
        response.accessExpiresAtUnixMs.toInt(),
        isUtc: true,
      ),
      refreshExpiresAt: DateTime.fromMillisecondsSinceEpoch(
        response.refreshExpiresAtUnixMs.toInt(),
        isUtc: true,
      ),
      gatewayAudience: response.gatewayAudience,
    );
  }

  DeviceSignature _signature(DeviceSignatureProof proof) => DeviceSignature(
    credentialId: proof.credentialId,
    nonce: proof.nonce,
    signature: proof.signature,
    algorithm: DeviceSignatureAlgorithm.DEVICE_SIGNATURE_ALGORITHM_ED25519,
  );

  Future<T> _call<T>(
    PairingOperation operation,
    Future<T> Function() invoke,
  ) async {
    try {
      // Intentionally one attempt: an interrupted unary call may already have
      // reached the Gateway and must be recovered explicitly by the caller.
      return await invoke();
    } on GrpcError catch (error) {
      throw _translateGrpcError(operation, error);
    } catch (_) {
      throw PairingGatewayCallException(
        operation: operation,
        disposition: PairingGatewayDisposition.uncertain,
        code: 'outcome_uncertain',
        safeMessage:
            'The Gateway result is unknown. Review it before choosing recovery.',
      );
    }
  }

  PairingGatewayCallException _translateGrpcError(
    PairingOperation operation,
    GrpcError error,
  ) {
    final remoteCode = error.trailers?[_errorCodeTrailer];
    if (remoteCode != null && _safeMessages.containsKey(remoteCode)) {
      return PairingGatewayCallException(
        operation: operation,
        disposition: PairingGatewayDisposition.rejected,
        code: remoteCode,
        safeMessage: _safeMessages[remoteCode]!,
      );
    }

    if (_isDeterministicRejection(error.code)) {
      return PairingGatewayCallException(
        operation: operation,
        disposition: PairingGatewayDisposition.rejected,
        code: 'gateway_rejected',
        safeMessage: 'The Gateway rejected the pairing operation.',
      );
    }

    return PairingGatewayCallException(
      operation: operation,
      disposition: PairingGatewayDisposition.uncertain,
      code: 'outcome_uncertain',
      safeMessage:
          'The Gateway result is unknown. Review it before choosing recovery.',
    );
  }

  bool _isDeterministicRejection(int statusCode) => switch (statusCode) {
    StatusCode.invalidArgument ||
    StatusCode.notFound ||
    StatusCode.alreadyExists ||
    StatusCode.permissionDenied ||
    StatusCode.resourceExhausted ||
    StatusCode.failedPrecondition ||
    StatusCode.outOfRange ||
    StatusCode.unimplemented ||
    StatusCode.unauthenticated => true,
    _ => false,
  };
}
