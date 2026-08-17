import 'package:flutter/services.dart';

import '../../domain/onboarding_device_key.dart';

/// Flutter bridge for the Android Keystore-backed device identity.
class AndroidKeystoreDeviceKeyPort implements OnboardingDeviceKeyPort {
  AndroidKeystoreDeviceKeyPort({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'agent_talk/android_keystore_device_key';

  final MethodChannel _channel;

  @override
  Future<OnboardingDeviceKeyIdentity> create() => _identity('create');

  @override
  Future<OnboardingDeviceKeyIdentity> inspect(String keyReference) =>
      _identity('inspect', <String, Object?>{'key_reference': keyReference});

  @override
  Future<List<int>> sign(String keyReference, List<int> payload) async {
    _validateReference(keyReference);
    if (payload.isEmpty || payload.length > 64 * 1024) {
      throw const OnboardingDeviceKeyException(
        'invalid_signing_payload',
        'The device signing payload is invalid.',
      );
    }
    try {
      final result = await _channel.invokeMethod<Object?>('sign', {
        'key_reference': keyReference,
        'payload': Uint8List.fromList(payload),
      });
      if (result is Uint8List && result.isNotEmpty && result.length <= 512) {
        return List.unmodifiable(result);
      }
      if (result is List<int> && result.isNotEmpty && result.length <= 512) {
        return List.unmodifiable(result);
      }
    } on PlatformException catch (error) {
      throw OnboardingDeviceKeyException(
        error.code,
        error.message ?? 'The Android Keystore signing operation failed.',
      );
    } on MissingPluginException {
      throw const OnboardingDeviceKeyException(
        'unsupported_platform',
        'Android Keystore is unavailable on this platform.',
      );
    }
    throw const OnboardingDeviceKeyException(
      'invalid_signature',
      'The Android Keystore returned an invalid signature.',
    );
  }

  @override
  Future<void> delete(String keyReference) async {
    _validateReference(keyReference);
    try {
      await _channel.invokeMethod<void>('delete', {
        'key_reference': keyReference,
      });
    } on PlatformException catch (error) {
      throw OnboardingDeviceKeyException(
        error.code,
        error.message ?? 'The Android Keystore delete operation failed.',
      );
    } on MissingPluginException {
      throw const OnboardingDeviceKeyException(
        'unsupported_platform',
        'Android Keystore is unavailable on this platform.',
      );
    }
  }

  Future<OnboardingDeviceKeyIdentity> _identity(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      final result = await _channel.invokeMethod<Object?>(method, arguments);
      if (result is! Map) {
        throw const OnboardingDeviceKeyException(
          'invalid_platform_response',
          'The Android Keystore returned an invalid identity.',
        );
      }
      final keyReference = result['key_reference'];
      final publicKey = result['public_key_spki_der'];
      final fingerprint = result['fingerprint'];
      final hardwareBacked = result['hardware_backed'];
      final strongBoxBacked = result['strong_box_backed'];
      if (keyReference is! String ||
          publicKey is! List<int> ||
          fingerprint is! String ||
          hardwareBacked is! bool ||
          strongBoxBacked is! bool) {
        throw const OnboardingDeviceKeyException(
          'invalid_platform_response',
          'The Android Keystore returned an incomplete identity.',
        );
      }
      return OnboardingDeviceKeyIdentity(
        keyReference: keyReference,
        publicKeySpkiDer: publicKey,
        fingerprint: fingerprint,
        hardwareBacked: hardwareBacked,
        strongBoxBacked: strongBoxBacked,
      );
    } on OnboardingDeviceKeyException {
      rethrow;
    } on PlatformException catch (error) {
      throw OnboardingDeviceKeyException(
        error.code,
        error.message ?? 'The Android Keystore operation failed.',
      );
    } on MissingPluginException {
      throw const OnboardingDeviceKeyException(
        'unsupported_platform',
        'Android Keystore is unavailable on this platform.',
      );
    }
  }

  static void _validateReference(String value) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(value)) {
      throw const OnboardingDeviceKeyException(
        'invalid_key_reference',
        'The Android Keystore key reference is invalid.',
      );
    }
  }
}
