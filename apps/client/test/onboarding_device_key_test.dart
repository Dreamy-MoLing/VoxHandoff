import 'package:agent_talk_client/domain/onboarding_device_key.dart';
import 'package:agent_talk_client/infrastructure/security/android_keystore_device_key.dart';
import 'package:agent_talk_client/infrastructure/security/onboarding_device_key_store.dart';
import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const keyReference = '0123456789abcdef0123456789abcdef';
  const fingerprint =
      'sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  final channel = const MethodChannel(AndroidKeystoreDeviceKeyPort.channelName);
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'uses the platform bridge without transporting private key bytes',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return switch (call.method) {
          'create' => <String, Object?>{
            'key_reference': keyReference,
            'public_key_spki_der': Uint8List.fromList(List<int>.filled(91, 4)),
            'fingerprint': fingerprint,
            'hardware_backed': true,
            'strong_box_backed': true,
          },
          'sign' => Uint8List.fromList(List<int>.filled(70, 5)),
          'delete' => null,
          _ => throw PlatformException(code: 'unexpected_method'),
        };
      });
      final port = AndroidKeystoreDeviceKeyPort(channel: channel);

      final identity = await port.create();
      final signature = await port.sign(keyReference, const [1, 2, 3]);
      await port.delete(keyReference);

      expect(identity.hardwareBacked, isTrue);
      expect(identity.strongBoxBacked, isTrue);
      expect(identity.publicKeySpkiDer, hasLength(91));
      expect(signature, hasLength(70));
      expect(calls.map((call) => call.method), ['create', 'sign', 'delete']);
      expect(calls[1].arguments, isNot(contains('private_key')));
      expect(calls[1].arguments, isNot(contains('seed')));
    },
  );

  test(
    'secure reference store persists only the key alias reference',
    () async {
      final store = _MemorySecureValueStore();
      final references = SecureOnboardingDeviceKeyReferenceStore(store);

      await references.save(keyReference);

      expect(await references.load(), keyReference);
      expect(store.values.values.single, contains('key_reference'));
      expect(store.values.values.single, isNot(contains('private')));
      expect(store.values.values.single, isNot(contains('seed')));
      await references.delete();
      expect(await references.load(), isNull);
    },
  );

  test(
    'rejects malformed platform identity and invalid key references',
    () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => <String, Object?>{
          'key_reference': 'bad',
          'public_key_spki_der': Uint8List.fromList([1]),
          'fingerprint': fingerprint,
          'hardware_backed': false,
          'strong_box_backed': false,
        },
      );
      final port = AndroidKeystoreDeviceKeyPort(channel: channel);

      expect(() => port.create(), throwsA(isA<OnboardingDeviceKeyException>()));
      expect(
        () => port.sign('bad', const [1]),
        throwsA(isA<OnboardingDeviceKeyException>()),
      );
    },
  );
}

class _MemorySecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
