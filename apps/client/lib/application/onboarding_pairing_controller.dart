import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/onboarding_device_key.dart';
import '../domain/onboarding_credential.dart';
import '../domain/onboarding_pairing.dart';
import '../domain/qr_pairing.dart';
import '../infrastructure/security/spki_pin_validator.dart';

class OnboardingPairingController extends ChangeNotifier {
  OnboardingPairingController({
    required OnboardingDeviceKeyPort deviceKeyPort,
    required OnboardingDeviceKeyReferenceStore keyReferenceStore,
    required OnboardingPairingExchangePort exchangePort,
    OnboardingCredentialVault? credentialVault,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _deviceKeyPort = deviceKeyPort;
    _keyReferenceStore = keyReferenceStore;
    _exchangePort = exchangePort;
    _credentialVault = credentialVault;
  }

  late final OnboardingDeviceKeyPort _deviceKeyPort;
  late final OnboardingDeviceKeyReferenceStore _keyReferenceStore;
  late final OnboardingPairingExchangePort _exchangePort;
  late final OnboardingCredentialVault? _credentialVault;
  final DateTime Function() _now;
  OnboardingPairingState _state = const OnboardingPairingState();
  bool _disposed = false;

  OnboardingPairingState get state => _state;

  void startScanning() {
    if (_state.phase != OnboardingPairingPhase.pending) {
      throw const OnboardingPairingException(
        'invalid_transition',
        'The pairing workflow is not ready to scan.',
      );
    }
    _publish(
      _state.copyWith(
        phase: OnboardingPairingPhase.scanning,
        errorCode: null,
        safeErrorMessage: null,
      ),
    );
  }

  void abortScanning() {
    if (_state.phase == OnboardingPairingPhase.scanning) {
      _publish(
        _state.copyWith(
          phase: OnboardingPairingPhase.pending,
          errorCode: null,
          safeErrorMessage: null,
        ),
      );
    }
  }

  Future<void> acceptQrCode(String encoded, {String deviceName = '此设备'}) async {
    if (_state.phase != OnboardingPairingPhase.scanning &&
        _state.phase != OnboardingPairingPhase.pending) {
      throw const OnboardingPairingException(
        'invalid_transition',
        'The pairing workflow is not ready to accept a QR code.',
      );
    }
    late final String normalizedDeviceName;
    try {
      normalizedDeviceName = _validateDeviceName(deviceName);
    } on OnboardingPairingException catch (error) {
      _publish(
        _state.copyWith(
          phase: OnboardingPairingPhase.pending,
          errorCode: error.code,
          safeErrorMessage: error.message,
        ),
      );
      return;
    }
    late final QrPairingPayload payload;
    try {
      payload = QrPairingPayload.parse(encoded, now: _now().toUtc());
    } on QrPairingPayloadException catch (error) {
      _publish(
        _state.copyWith(
          phase: OnboardingPairingPhase.pending,
          payload: null,
          deviceKey: null,
          pairingId: null,
          confirmationCode: null,
          backupSpkiPin: null,
          errorCode: error.code,
          safeErrorMessage: error.message,
        ),
      );
      return;
    }

    OnboardingDeviceKeyIdentity? deviceKey;
    var exchangeStarted = false;
    try {
      _publish(
        OnboardingPairingState(
          phase: OnboardingPairingPhase.keygen,
          payload: payload,
          deviceName: normalizedDeviceName,
          expiresAt: payload.expiresAt,
        ),
      );
      deviceKey = await _deviceKeyPort.create();
      _publish(_state.copyWith(deviceKey: deviceKey));
      await _keyReferenceStore.save(deviceKey.keyReference);
      if (_isExpired(payload.expiresAt)) {
        await _discardLocalKey(deviceKey);
        _publish(
          _state.copyWith(
            phase: OnboardingPairingPhase.expired,
            deviceKey: null,
            errorCode: null,
            safeErrorMessage: null,
          ),
        );
        return;
      }

      _publish(_state.copyWith(phase: OnboardingPairingPhase.exchange));
      final proof = await _deviceKeyPort.sign(
        deviceKey.keyReference,
        _proofBytes(payload, normalizedDeviceName, deviceKey),
      );
      exchangeStarted = true;
      final result = await _exchangePort.exchange(
        payload: payload,
        deviceName: normalizedDeviceName,
        deviceKey: deviceKey,
        proofSignature: proof,
      );
      try {
        SpkiPinSet(
          currentPin: payload.spkiPin,
          backupPin: result.backupSpkiPin,
        );
      } on SpkiPinConfigurationException catch (error) {
        throw OnboardingPairingException(
          error.code,
          error.message,
          acceptanceUncertain: true,
        );
      }
      if (_isExpired(result.expiresAt)) {
        await _discardLocalKey(deviceKey);
        _publish(
          _state.copyWith(
            phase: OnboardingPairingPhase.expired,
            deviceKey: null,
            pairingId: result.pairingId,
            confirmationCode: result.confirmationCode,
            backupSpkiPin: result.backupSpkiPin,
            expiresAt: result.expiresAt,
            errorCode: null,
            safeErrorMessage: null,
          ),
        );
        return;
      }
      _publish(
        _state.copyWith(
          phase: OnboardingPairingPhase.waitingHostConfirmation,
          pairingId: result.pairingId,
          confirmationCode: result.confirmationCode,
          backupSpkiPin: result.backupSpkiPin,
          expiresAt: result.expiresAt,
          errorCode: null,
          safeErrorMessage: null,
        ),
      );
    } on OnboardingDeviceKeyException catch (error) {
      if (!exchangeStarted && deviceKey != null) {
        await _discardLocalKey(deviceKey);
      }
      _publish(
        _state.copyWith(
          phase: OnboardingPairingPhase.failed,
          deviceKey: exchangeStarted ? deviceKey : null,
          errorCode: error.code,
          safeErrorMessage: error.message,
        ),
      );
    } on OnboardingPairingException catch (error) {
      if (!exchangeStarted || !error.acceptanceUncertain) {
        if (!exchangeStarted) await _discardLocalKey(deviceKey);
      }
      _publish(
        _state.copyWith(
          phase: exchangeStarted || error.acceptanceUncertain
              ? OnboardingPairingPhase.uncertain
              : OnboardingPairingPhase.failed,
          deviceKey: deviceKey,
          errorCode: error.code,
          safeErrorMessage: error.message,
        ),
      );
    } on Object {
      if (!exchangeStarted && deviceKey != null) {
        await _discardLocalKey(deviceKey);
      }
      _publish(
        _state.copyWith(
          phase: exchangeStarted
              ? OnboardingPairingPhase.uncertain
              : OnboardingPairingPhase.failed,
          deviceKey: exchangeStarted ? deviceKey : null,
          errorCode: exchangeStarted ? 'exchange_uncertain' : 'pairing_failed',
          safeErrorMessage: exchangeStarted
              ? '配对请求的远端结果不确定，请在主机确认状态后再处理。'
              : '配对未完成，请检查设备状态后重试。',
        ),
      );
    }
  }

  Future<void> refreshHostStatus() async {
    final current = _state;
    if (current.phase != OnboardingPairingPhase.waitingHostConfirmation ||
        current.payload == null ||
        current.pairingId == null) {
      throw const OnboardingPairingException(
        'invalid_transition',
        'The pairing workflow is not waiting for host confirmation.',
      );
    }
    if (_isExpired(current.expiresAt)) {
      await _expireLocalKey();
      return;
    }
    _publish(current.copyWith(errorCode: null, safeErrorMessage: null));
    try {
      final result = await _exchangePort.status(
        payload: current.payload!,
        pairingId: current.pairingId!,
        backupSpkiPin: current.backupSpkiPin,
      );
      switch (result.status) {
        case OnboardingPairingRemoteStatus.waitingHostConfirmation:
          return;
        case OnboardingPairingRemoteStatus.confirmed:
          OnboardingCredentialReference? credentialReference;
          final credentialVault = _credentialVault;
          if (credentialVault != null) {
            final credential = result.credential;
            if (credential == null) {
              _publish(
                _state.copyWith(
                  phase: OnboardingPairingPhase.uncertain,
                  errorCode: 'credential_missing',
                  safeErrorMessage: '主机已确认，但没有返回手机凭据。',
                ),
              );
              return;
            }
            try {
              credentialReference = await credentialVault.save(credential);
            } on OnboardingCredentialException catch (error) {
              _publish(
                _state.copyWith(
                  phase: OnboardingPairingPhase.uncertain,
                  errorCode: 'credential_storage_failed',
                  safeErrorMessage: error.message,
                ),
              );
              return;
            } on Object {
              _publish(
                _state.copyWith(
                  phase: OnboardingPairingPhase.uncertain,
                  errorCode: 'credential_storage_failed',
                  safeErrorMessage: '手机凭据未能安全保存，请勿重复提交配对请求。',
                ),
              );
              return;
            }
          }
          _publish(
            _state.copyWith(
              phase: OnboardingPairingPhase.confirmed,
              credentialReference: credentialReference,
              errorCode: null,
              safeErrorMessage: null,
            ),
          );
        case OnboardingPairingRemoteStatus.expired:
          await _expireLocalKey();
        case OnboardingPairingRemoteStatus.cancelled:
          await _discardLocalKey(_state.deviceKey);
          _publish(
            _state.copyWith(
              phase: OnboardingPairingPhase.cancelled,
              deviceKey: null,
              errorCode: null,
              safeErrorMessage: null,
            ),
          );
      }
    } on OnboardingPairingException catch (error) {
      _publish(
        _state.copyWith(errorCode: error.code, safeErrorMessage: error.message),
      );
    } on Object {
      _publish(
        _state.copyWith(
          errorCode: 'status_check_failed',
          safeErrorMessage: '暂时无法确认主机状态，请稍后重试。',
        ),
      );
    }
  }

  Future<void> cancel() async {
    final current = _state;
    if (current.phase == OnboardingPairingPhase.confirmed ||
        current.phase == OnboardingPairingPhase.cancelled) {
      throw const OnboardingPairingException(
        'invalid_transition',
        'The completed pairing cannot be cancelled here.',
      );
    }
    if (current.payload != null && current.pairingId != null) {
      try {
        await _exchangePort.cancel(
          payload: current.payload!,
          pairingId: current.pairingId!,
          backupSpkiPin: current.backupSpkiPin,
        );
      } on OnboardingPairingException catch (error) {
        _publish(
          current.copyWith(
            phase: OnboardingPairingPhase.uncertain,
            errorCode: error.code,
            safeErrorMessage: error.message,
          ),
        );
        return;
      } on Object {
        _publish(
          current.copyWith(
            phase: OnboardingPairingPhase.uncertain,
            errorCode: 'cancel_uncertain',
            safeErrorMessage: '取消请求的远端结果不确定，请在主机确认状态后再处理。',
          ),
        );
        return;
      }
    }
    await _discardLocalKey(current.deviceKey);
    _publish(
      current.copyWith(
        phase: OnboardingPairingPhase.cancelled,
        deviceKey: null,
        errorCode: null,
        safeErrorMessage: null,
      ),
    );
  }

  Future<void> reset() async {
    if (_state.phase == OnboardingPairingPhase.confirmed) {
      throw const OnboardingPairingException(
        'invalid_transition',
        'The confirmed device key must be handled by credential storage.',
      );
    }
    await _discardLocalKey(_state.deviceKey);
    _publish(const OnboardingPairingState());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _validateDeviceName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty ||
        normalized.length > 64 ||
        normalized.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
      throw const OnboardingPairingException('invalid_device_name', '设备名称无效。');
    }
    return normalized;
  }

  List<int> _proofBytes(
    QrPairingPayload payload,
    String deviceName,
    OnboardingDeviceKeyIdentity deviceKey,
  ) => utf8.encode(
    jsonEncode({
      'protocol_version': payload.protocolVersion,
      'server_id': payload.serverId,
      'pairing_session_id': payload.pairingSessionId,
      'pairing_token': payload.pairingToken,
      'device_name': deviceName,
      'device_public_key_spki_der': base64Encode(deviceKey.publicKeySpkiDer),
    }),
  );

  bool _isExpired(DateTime? expiresAt) =>
      expiresAt == null || !expiresAt.isAfter(_now().toUtc());

  Future<void> _expireLocalKey() async {
    await _discardLocalKey(_state.deviceKey);
    _publish(
      _state.copyWith(
        phase: OnboardingPairingPhase.expired,
        deviceKey: null,
        errorCode: null,
        safeErrorMessage: null,
      ),
    );
  }

  Future<void> _discardLocalKey(OnboardingDeviceKeyIdentity? deviceKey) async {
    if (deviceKey == null) return;
    try {
      await _deviceKeyPort.delete(deviceKey.keyReference);
    } finally {
      await _keyReferenceStore.delete();
    }
  }

  void _publish(OnboardingPairingState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
