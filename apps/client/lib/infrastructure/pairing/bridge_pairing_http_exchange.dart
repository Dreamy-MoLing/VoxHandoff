import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/onboarding_device_key.dart';
import '../../domain/onboarding_credential.dart';
import '../../domain/onboarding_pairing.dart';
import '../../domain/qr_pairing.dart';
import '../security/spki_pin_validator.dart';

/// HTTP adapter for the Companion Bridge pairing contract.
///
/// The Bridge is intentionally an external dependency. This client only
/// implements the phone-side exchange and status calls; it never starts a
/// process or embeds Agent/Gateway behavior.
class BridgePairingHttpExchange implements OnboardingPairingExchangePort {
  BridgePairingHttpExchange({
    HttpClient? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;

  @override
  Future<OnboardingPairingExchangeResult> exchange({
    required QrPairingPayload payload,
    required String deviceName,
    required OnboardingDeviceKeyIdentity deviceKey,
    required List<int> proofSignature,
  }) async {
    final response = await _request(
      payload: payload,
      path: 'v1/pairing/exchange',
      body: {
        'protocol_version': payload.protocolVersion,
        'server_id': payload.serverId,
        'pairing_session_id': payload.pairingSessionId,
        'pairing_token': payload.pairingToken,
        'device_name': deviceName,
        'device_public_key_spki_der': base64Encode(deviceKey.publicKeySpkiDer),
        'device_key_fingerprint': deviceKey.fingerprint,
        'device_key_proof': base64Encode(proofSignature),
      },
      backupSpkiPin: null,
      acceptanceUncertainOnFailure: true,
    );
    final pairingId = _requiredString(response, 'pairing_id');
    final confirmationCode = _requiredString(response, 'confirmation_code');
    final expiresAt = _requiredExpiry(response['expires_at']);
    final status = _requiredString(response, 'status');
    if (status != 'waiting_host_confirmation' &&
        status != 'waiting_host_confirm') {
      throw const OnboardingPairingException(
        'unexpected_exchange_status',
        '主机没有进入等待确认状态。',
        acceptanceUncertain: true,
      );
    }
    final backup = response['backup_spki_pin'];
    String? backupPin;
    if (backup != null) {
      if (backup is! String) {
        throw const OnboardingPairingException(
          'invalid_backup_pin',
          '主机返回的备用证书 pin 无效。',
          acceptanceUncertain: true,
        );
      }
      try {
        backupPin = canonicalizeSpkiPin(backup);
      } on SpkiPinConfigurationException {
        throw const OnboardingPairingException(
          'invalid_backup_pin',
          '主机返回的备用证书 pin 无效。',
          acceptanceUncertain: true,
        );
      }
    }
    try {
      return OnboardingPairingExchangeResult(
        pairingId: pairingId,
        confirmationCode: confirmationCode,
        expiresAt: expiresAt,
        backupSpkiPin: backupPin,
      );
    } on OnboardingPairingException catch (error) {
      throw OnboardingPairingException(
        error.code,
        error.message,
        acceptanceUncertain: true,
      );
    }
  }

  @override
  Future<OnboardingPairingStatusResult> status({
    required QrPairingPayload payload,
    required String pairingId,
    required String? backupSpkiPin,
  }) async {
    final response = await _request(
      payload: payload,
      path: 'v1/pairing/status',
      body: {
        'protocol_version': payload.protocolVersion,
        'server_id': payload.serverId,
        'pairing_session_id': payload.pairingSessionId,
        'pairing_token': payload.pairingToken,
        'pairing_id': pairingId,
      },
      backupSpkiPin: backupSpkiPin,
      acceptanceUncertainOnFailure: false,
    );
    final status = _status(_requiredString(response, 'status'));
    final credential = status == OnboardingPairingRemoteStatus.confirmed
        ? _parseCredential(response['credential'])
        : null;
    return OnboardingPairingStatusResult(status, credential: credential);
  }

  @override
  Future<void> cancel({
    required QrPairingPayload payload,
    required String pairingId,
    required String? backupSpkiPin,
  }) async {
    await _request(
      payload: payload,
      path: 'v1/pairing/cancel',
      body: {
        'protocol_version': payload.protocolVersion,
        'server_id': payload.serverId,
        'pairing_session_id': payload.pairingSessionId,
        'pairing_token': payload.pairingToken,
        'pairing_id': pairingId,
      },
      backupSpkiPin: backupSpkiPin,
      acceptanceUncertainOnFailure: true,
    );
  }

  void close() => _client.close(force: true);

  Future<Map<String, Object?>> _request({
    required QrPairingPayload payload,
    required String path,
    required Map<String, Object?> body,
    required String? backupSpkiPin,
    required bool acceptanceUncertainOnFailure,
  }) async {
    HttpClientRequest? request;
    try {
      request = await _client
          .postUrl(_appendPath(payload.bridgeEndpoint, path))
          .timeout(timeout);
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close().timeout(timeout);
      try {
        SpkiPinValidator(
          currentPin: payload.spkiPin,
          backupPin: backupSpkiPin,
        ).validateCertificate(response.certificate);
      } on SpkiPinValidationException catch (error) {
        await _discard(response);
        throw OnboardingPairingException(
          'server_identity_changed',
          error.safeMessage,
          acceptanceUncertain: acceptanceUncertainOnFailure,
        );
      }
      final bytes = await response
          .transform(const _ResponseLimitTransformer(256 * 1024))
          .fold<List<int>>(<int>[], (all, chunk) => [...all, ...chunk])
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OnboardingPairingException(
          'bridge_http_${response.statusCode}',
          '主机拒绝了配对请求。',
        );
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw OnboardingPairingException(
          'invalid_bridge_response',
          '主机返回了无效的配对响应。',
          acceptanceUncertain: acceptanceUncertainOnFailure,
        );
      }
      return <String, Object?>{
        for (final entry in decoded.entries)
          if (entry.key is String) entry.key! as String: entry.value,
      };
    } on OnboardingPairingException {
      rethrow;
    } on TimeoutException {
      throw OnboardingPairingException(
        'bridge_timeout',
        '主机配对请求超时。',
        acceptanceUncertain: acceptanceUncertainOnFailure,
      );
    } on FormatException {
      throw OnboardingPairingException(
        'invalid_bridge_response',
        '主机返回了无效的配对响应。',
        acceptanceUncertain: acceptanceUncertainOnFailure,
      );
    } on Object {
      throw OnboardingPairingException(
        'bridge_connection_failed',
        '无法安全连接到 Companion Bridge。',
        acceptanceUncertain: acceptanceUncertainOnFailure,
      );
    }
  }

  Future<void> _discard(HttpClientResponse response) async {
    try {
      await response
          .transform(const _ResponseLimitTransformer(256 * 1024))
          .timeout(timeout)
          .drain<void>();
    } on Object {
      // The pin failure is the security result; response cleanup is best
      // effort and must not replace it.
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

String _requiredString(
  Map<String, Object?> value,
  String key, {
  int maximumLength = 256,
}) {
  final result = value[key];
  if (result is! String || result.isEmpty || result.length > maximumLength) {
    throw OnboardingPairingException(
      'invalid_bridge_response',
      '主机返回的配对响应缺少有效字段。',
      acceptanceUncertain: true,
    );
  }
  return result;
}

String? _optionalString(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result == null) return null;
  if (result is! String || result.isEmpty || result.length > 256) {
    throw const OnboardingPairingException(
      'invalid_credential',
      '主机返回的手机凭据字段无效。',
      acceptanceUncertain: true,
    );
  }
  return result;
}

OnboardingCredentialMaterial _parseCredential(Object? raw) {
  if (raw is! Map) {
    throw const OnboardingPairingException(
      'credential_missing',
      '主机已确认，但没有返回手机凭据。',
      acceptanceUncertain: true,
    );
  }
  final value = <String, Object?>{
    for (final entry in raw.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
  try {
    return OnboardingCredentialMaterial(
      credentialId: _requiredString(value, 'credential_id'),
      credential: _requiredString(value, 'credential', maximumLength: 4096),
      bridgeEndpoint: _requiredUri(value['bridge_endpoint']),
      serverId: _requiredString(value, 'server_id'),
      deviceKeyReference: _requiredString(value, 'device_key_reference'),
      spkiPin: _requiredString(value, 'spki_pin'),
      backupSpkiPin: _optionalString(value, 'backup_spki_pin'),
      issuedAt: _requiredExpiry(value['issued_at']),
    );
  } on OnboardingPairingException {
    rethrow;
  } on OnboardingCredentialException catch (error) {
    throw OnboardingPairingException(
      'invalid_credential',
      error.message,
      acceptanceUncertain: true,
    );
  }
}

Uri _requiredUri(Object? raw) {
  if (raw is! String) {
    throw const OnboardingPairingException(
      'invalid_credential',
      '主机返回的手机凭据端点无效。',
      acceptanceUncertain: true,
    );
  }
  final endpoint = Uri.tryParse(raw);
  if (endpoint == null) {
    throw const OnboardingPairingException(
      'invalid_credential',
      '主机返回的手机凭据端点无效。',
      acceptanceUncertain: true,
    );
  }
  return endpoint;
}

DateTime _requiredExpiry(Object? raw) {
  if (raw is! String || raw.isEmpty || !raw.endsWith('Z')) {
    throw const OnboardingPairingException(
      'invalid_bridge_expiry',
      '主机返回的配对有效期无效。',
      acceptanceUncertain: true,
    );
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw const OnboardingPairingException(
      'invalid_bridge_expiry',
      '主机返回的配对有效期无效。',
      acceptanceUncertain: true,
    );
  }
  return parsed.toUtc();
}

OnboardingPairingRemoteStatus _status(String value) => switch (value) {
  'waiting_host_confirmation' || 'waiting_host_confirm' =>
    OnboardingPairingRemoteStatus.waitingHostConfirmation,
  'confirmed' => OnboardingPairingRemoteStatus.confirmed,
  'expired' => OnboardingPairingRemoteStatus.expired,
  'cancelled' || 'canceled' => OnboardingPairingRemoteStatus.cancelled,
  _ => throw const OnboardingPairingException(
    'invalid_pairing_status',
    '主机返回了未知的配对状态。',
  ),
};

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
        throw const OnboardingPairingException(
          'bridge_response_too_large',
          '主机返回的配对响应过大。',
        );
      }
      yield chunk;
    }
  }
}
