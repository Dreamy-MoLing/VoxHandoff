import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../domain/onboarding_device_key.dart';
import '../../domain/onboarding_credential.dart';
import '../../domain/onboarding_pairing.dart';
import '../../domain/qr_pairing.dart';
import '../security/spki_pin_validator.dart';

/// HTTP adapter for the phone side of the Companion Bridge pairing contract.
///
/// The adapter sends only the T1 wire fields. The pairing token is carried in
/// the QR exchange body and in the dedicated pairing-auth header for the
/// phone-owned status and cancel calls; it is never placed in a URL.
class BridgePairingHttpExchange implements OnboardingPairingExchangePort {
  BridgePairingHttpExchange({
    HttpClient? client,
    this.timeout = const Duration(seconds: 15),
    DateTime Function()? now,
  })  : _client = client ?? HttpClient(),
        _now = now ?? DateTime.now;

  final HttpClient _client;
  final Duration timeout;
  final DateTime Function() _now;

  @override
  Future<OnboardingPairingExchangeResult> exchange({
    required QrPairingPayload payload,
    required String deviceName,
    required OnboardingDeviceKeyIdentity deviceKey,
  }) async {
    final response = await _request(
      method: 'POST',
      payload: payload,
      path: 'v1/pairing/exchange',
      body: {
        'server_id': payload.serverId,
        'pairing_session_id': payload.pairingSessionId,
        'pairing_token': payload.pairingToken,
        'device_name': deviceName,
        'device_public_key_spki': base64Encode(deviceKey.publicKeySpkiDer),
      },
      headers: const {},
      backupSpkiPin: null,
      acceptanceUncertainOnFailure: true,
    );
    late final OnboardingPairingExchangeResult result;
    try {
      result = OnboardingPairingExchangeResult(
        pairingRequestId: _requiredString(response, 'pairingRequestId'),
        deviceId: _requiredString(response, 'deviceId'),
        deviceName: _requiredString(
          response,
          'deviceName',
          maximumLength: 120,
        ),
        deviceFingerprint: _requiredFingerprint(
          response,
          'deviceFingerprint',
        ),
        challenge: _requiredString(response, 'challenge'),
        status: _status(_requiredString(response, 'status')),
        expiresAt: _requiredExpiry(response['expiresAt']),
      );
    } on OnboardingPairingException catch (error) {
      throw OnboardingPairingException(
        error.code,
        error.message,
        acceptanceUncertain: true,
      );
    }
    if (result.deviceName != deviceName) {
      throw const OnboardingPairingException(
        'device_name_mismatch',
        '主机返回的设备名称与本机请求不一致。',
        acceptanceUncertain: true,
      );
    }
    if (result.deviceFingerprint != deviceKey.fingerprint) {
      throw const OnboardingPairingException(
        'device_fingerprint_mismatch',
        '主机返回的设备密钥指纹与本机不一致。',
        acceptanceUncertain: true,
      );
    }
    return result;
  }

  @override
  Future<OnboardingPairingStatusResult> status({
    required QrPairingPayload payload,
    required String pairingRequestId,
    required String? backupSpkiPin,
  }) async {
    final response = await _request(
      method: 'GET',
      payload: payload,
      path:
          'v1/pairing/requests/${Uri.encodeComponent(pairingRequestId)}/status',
      headers: {
        'X-Bridge-Pairing-Authorization': 'Bearer ${payload.pairingToken}',
      },
      backupSpkiPin: backupSpkiPin,
      acceptanceUncertainOnFailure: false,
    );
    final responsePairingRequestId = _requiredString(
      response,
      'pairingRequestId',
      acceptanceUncertain: false,
    );
    if (responsePairingRequestId != pairingRequestId) {
      throw const OnboardingPairingException(
        'pairing_request_mismatch',
        '主机返回的配对请求与本机不一致。',
      );
    }
    return OnboardingPairingStatusResult(
      pairingRequestId: responsePairingRequestId,
      status: _status(
        _requiredString(response, 'status', acceptanceUncertain: false),
        acceptanceUncertain: false,
      ),
      expiresAt: _requiredExpiry(
        response['expiresAt'],
        acceptanceUncertain: false,
      ),
    );
  }

  @override
  Future<OnboardingCredentialMaterial> complete({
    required QrPairingPayload payload,
    required String pairingRequestId,
    required String deviceId,
    required OnboardingDeviceKeyIdentity deviceKey,
    required List<int> deviceSignature,
    required String? backupSpkiPin,
  }) async {
    final response = await _request(
      method: 'POST',
      payload: payload,
      path:
          'v1/pairing/requests/${Uri.encodeComponent(pairingRequestId)}/complete',
      body: {'device_signature': base64Encode(deviceSignature)},
      headers: const {},
      backupSpkiPin: backupSpkiPin,
      acceptanceUncertainOnFailure: true,
    );
    final responsePairingRequestId = _requiredString(
      response,
      'pairingRequestId',
    );
    if (responsePairingRequestId != pairingRequestId) {
      throw const OnboardingPairingException(
        'pairing_request_mismatch',
        '主机返回的配对请求与本机不一致。',
        acceptanceUncertain: true,
      );
    }
    final responseDeviceId = _requiredString(response, 'deviceId');
    if (responseDeviceId != deviceId) {
      throw const OnboardingPairingException(
        'device_id_mismatch',
        '主机返回的设备与本机不一致。',
        acceptanceUncertain: true,
      );
    }
    _requiredString(response, 'credentialId');
    _requiredString(response, 'deviceCredential', maximumLength: 4096);
    _requiredScopes(response['scopes']);
    final expiresAt = _requiredExpiry(response['expiresAt']);
    if (!expiresAt.isAfter(_now().toUtc())) {
      throw const OnboardingPairingException(
        'credential_expired',
        '主机返回的手机凭据已经过期。',
        acceptanceUncertain: true,
      );
    }
    try {
      return OnboardingCredentialMaterial(
        credentialId: _requiredString(response, 'credentialId'),
        credential: _requiredString(
          response,
          'deviceCredential',
          maximumLength: 4096,
        ),
        bridgeEndpoint: payload.bridgeEndpoint,
        serverId: payload.serverId,
        deviceKeyReference: deviceKey.keyReference,
        spkiPin: payload.spkiPin,
        backupSpkiPin: backupSpkiPin,
        issuedAt: _now().toUtc(),
      );
    } on OnboardingCredentialException catch (error) {
      throw OnboardingPairingException(
        'invalid_credential',
        error.message,
        acceptanceUncertain: true,
      );
    }
  }

  @override
  Future<void> cancel({
    required QrPairingPayload payload,
    required String pairingRequestId,
    required String? backupSpkiPin,
  }) async {
    await _request(
      method: 'POST',
      payload: payload,
      path:
          'v1/pairing/sessions/${Uri.encodeComponent(payload.pairingSessionId)}/cancel',
      headers: {
        'X-Bridge-Pairing-Authorization': 'Bearer ${payload.pairingToken}',
      },
      backupSpkiPin: backupSpkiPin,
      acceptanceUncertainOnFailure: true,
    );
  }

  void close() => _client.close(force: true);

  Future<Map<String, Object?>> _request({
    required String method,
    required QrPairingPayload payload,
    required String path,
    Map<String, Object?>? body,
    required Map<String, String> headers,
    required String? backupSpkiPin,
    required bool acceptanceUncertainOnFailure,
  }) async {
    try {
      final request = await _client
          .openUrl(method, _appendPath(payload.bridgeEndpoint, path))
          .timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.add(utf8.encode(jsonEncode(body)));
      }
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
  bool acceptanceUncertain = true,
}) {
  final result = value[key];
  if (result is! String ||
      result.isEmpty ||
      result.length > maximumLength ||
      result.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
    throw OnboardingPairingException(
      'invalid_bridge_response',
      '主机返回的配对响应缺少有效字段。',
      acceptanceUncertain: acceptanceUncertain,
    );
  }
  return result;
}

String _requiredFingerprint(
  Map<String, Object?> value,
  String key, {
  bool acceptanceUncertain = true,
}) {
  final result = _requiredString(
    value,
    key,
    acceptanceUncertain: acceptanceUncertain,
  );
  if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(result)) {
    throw OnboardingPairingException(
      'invalid_bridge_response',
      '主机返回的设备指纹无效。',
      acceptanceUncertain: acceptanceUncertain,
    );
  }
  return result;
}

List<String> _requiredScopes(Object? raw) {
  if (raw is! List || raw.isEmpty || raw.length > 16) {
    throw const OnboardingPairingException(
      'invalid_bridge_response',
      '主机返回的设备权限无效。',
      acceptanceUncertain: true,
    );
  }
  final scopes = <String>[];
  for (final scope in raw) {
    if (scope is! String ||
        scope.isEmpty ||
        scope.length > 64 ||
        scope.contains(RegExp(r'[\u0000-\u001f\u007f]')) ||
        scopes.contains(scope)) {
      throw const OnboardingPairingException(
        'invalid_bridge_response',
        '主机返回的设备权限无效。',
        acceptanceUncertain: true,
      );
    }
    scopes.add(scope);
  }
  return scopes;
}

DateTime _requiredExpiry(Object? raw, {bool acceptanceUncertain = true}) {
  if (raw is! String || raw.isEmpty || !raw.endsWith('Z')) {
    throw OnboardingPairingException(
      'invalid_bridge_expiry',
      '主机返回的配对有效期无效。',
      acceptanceUncertain: acceptanceUncertain,
    );
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw OnboardingPairingException(
      'invalid_bridge_expiry',
      '主机返回的配对有效期无效。',
      acceptanceUncertain: acceptanceUncertain,
    );
  }
  return parsed.toUtc();
}

OnboardingPairingRemoteStatus _status(
  String value, {
  bool acceptanceUncertain = true,
}) => switch (value) {
  'awaiting_confirmation' =>
    OnboardingPairingRemoteStatus.awaitingConfirmation,
  'confirmed' => OnboardingPairingRemoteStatus.confirmed,
  'expired' => OnboardingPairingRemoteStatus.expired,
  'cancelled' => OnboardingPairingRemoteStatus.cancelled,
  _ => throw OnboardingPairingException(
    'invalid_pairing_status',
    '主机返回了未知的配对状态。',
    acceptanceUncertain: acceptanceUncertain,
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
