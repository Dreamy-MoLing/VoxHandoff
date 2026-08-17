import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/onboarding_credential.dart';
import '../security/spki_pin_validator.dart';

class BridgeCredentialRevoker implements OnboardingCredentialRevocationPort {
  BridgeCredentialRevoker({
    HttpClient? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;

  @override
  Future<void> revoke(OnboardingCredentialMaterial material) async {
    HttpClientRequest? request;
    try {
      request = await _client
          .postUrl(_appendPath(material.bridgeEndpoint, 'v1/devices/revoke'))
          .timeout(timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.add(
        utf8.encode(
          jsonEncode({
            'credential_id': material.credentialId,
            'credential': material.credential,
            'server_id': material.serverId,
            'device_key_reference': material.deviceKeyReference,
          }),
        ),
      );
      final response = await request.close().timeout(timeout);
      try {
        SpkiPinValidator(
          currentPin: material.spkiPin,
          backupPin: material.backupSpkiPin,
        ).validateCertificate(response.certificate);
      } on SpkiPinValidationException catch (error) {
        await _discard(response);
        throw OnboardingCredentialException(
          'server_identity_changed',
          error.safeMessage,
        );
      }
      await response
          .transform(const _ResponseLimitTransformer(64 * 1024))
          .timeout(timeout)
          .drain<void>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const OnboardingCredentialException(
          'revoke_rejected',
          '主机没有确认撤销这台设备。',
        );
      }
    } on OnboardingCredentialException {
      rethrow;
    } on TimeoutException {
      throw const OnboardingCredentialException(
        'revoke_timeout',
        '撤销请求超时，凭据仍保留在本机。',
      );
    } on Object {
      throw const OnboardingCredentialException(
        'revoke_failed',
        '无法安全撤销这台设备的手机凭据。',
      );
    }
  }

  void close() => _client.close(force: true);

  Future<void> _discard(HttpClientResponse response) async {
    try {
      await response
          .transform(const _ResponseLimitTransformer(64 * 1024))
          .timeout(timeout)
          .drain<void>();
    } on Object {
      // Preserve the pin failure as the user-visible security result.
    }
  }
}

Uri _appendPath(Uri base, String path) {
  final basePath = base.path.isEmpty
      ? ''
      : base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$basePath/$path');
}

class _ResponseLimitTransformer
    extends StreamTransformerBase<List<int>, List<int>> {
  const _ResponseLimitTransformer(this.maximumBytes);

  final int maximumBytes;

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    var total = 0;
    await for (final chunk in stream) {
      total += chunk.length;
      if (total > maximumBytes) {
        throw const OnboardingCredentialException(
          'revoke_response_too_large',
          '主机返回的撤销响应过大。',
        );
      }
      yield chunk;
    }
  }
}
