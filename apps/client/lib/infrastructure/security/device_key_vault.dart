import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../domain/device_pairing.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class DeviceKeyVaultException implements Exception {
  const DeviceKeyVaultException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DeviceKeyVaultException($code): $message';
}

class DeviceKeyVault implements DeviceKeyVaultPort {
  factory DeviceKeyVault({
    required SecureValueStore store,
    Ed25519? algorithm,
    Sha256? sha256,
    Random? random,
    Future<List<int>> Function()? seedFactory,
  }) => DeviceKeyVault._(
    store,
    algorithm ?? Ed25519(),
    sha256 ?? Sha256(),
    random ?? Random.secure(),
    seedFactory,
  );

  DeviceKeyVault._(
    this._store,
    this._algorithm,
    this._sha256,
    this._random,
    this._seedFactory,
  );

  static const _recordPrefix = 'agent-talk.v1.pending-device-key.';
  static const _activeRecordPrefix = 'agent-talk.v1.active-device-key.';
  static const _spkiPrefix = <int>[
    0x30,
    0x2a,
    0x30,
    0x05,
    0x06,
    0x03,
    0x2b,
    0x65,
    0x70,
    0x03,
    0x21,
    0x00,
  ];

  final SecureValueStore _store;
  final Ed25519 _algorithm;
  final Sha256 _sha256;
  final Random _random;
  final Future<List<int>> Function()? _seedFactory;

  @override
  Future<DevicePublicIdentity> createPendingKey() async {
    final seed = await _newSeed();
    SimpleKeyPair? keyPair;
    try {
      keyPair = await _algorithm.newKeyPairFromSeed(seed);
      final publicKey = await keyPair.extractPublicKey();
      final keyReference = await _uniqueOpaqueReference();
      await _store.write(
        '$_recordPrefix$keyReference',
        jsonEncode({
          'version': 1,
          'algorithm': 'ed25519',
          'state': 'pending',
          'credential_id': null,
          'seed': base64UrlEncode(seed),
          'public_key': base64UrlEncode(publicKey.bytes),
        }),
      );
      return _publicIdentity(keyReference, publicKey.bytes);
    } finally {
      seed.fillRange(0, seed.length, 0);
      if (keyPair != null) {
        _destroy(keyPair);
      }
    }
  }

  @override
  Future<DevicePublicIdentity> inspect(String keyReference) async {
    final record = await _readRecord(keyReference);
    try {
      return _publicIdentity(keyReference, record.publicKeyBytes);
    } finally {
      record.seed.fillRange(0, record.seed.length, 0);
    }
  }

  @override
  Future<List<int>> sign(String keyReference, List<int> payload) async {
    final record = await _readRecord(keyReference);
    SimpleKeyPair? keyPair;
    try {
      keyPair = await _algorithm.newKeyPairFromSeed(record.seed);
      final publicKey = await keyPair.extractPublicKey();
      if (!_constantTimeEquals(publicKey.bytes, record.publicKeyBytes)) {
        throw const DeviceKeyVaultException(
          'corrupt_key',
          'The stored device public key does not match its private seed.',
        );
      }
      final signature = await _algorithm.sign(payload, keyPair: keyPair);
      if (signature.bytes.length != 64) {
        throw const DeviceKeyVaultException(
          'invalid_signature',
          'The device signer returned an invalid Ed25519 signature.',
        );
      }
      return List.unmodifiable(signature.bytes);
    } finally {
      record.seed.fillRange(0, record.seed.length, 0);
      if (keyPair != null) {
        _destroy(keyPair);
      }
    }
  }

  @override
  Future<void> discard(String keyReference) async {
    _validateReference(keyReference);
    await _store.delete('$_recordPrefix$keyReference');
  }

  @override
  Future<void> promotePendingKey(
    String keyReference,
    String credentialId,
  ) async {
    _validateReference(keyReference);
    _validateOpaqueId(credentialId, 'credential ID');
    final pendingKey = '$_recordPrefix$keyReference';
    final activeKey = '$_activeRecordPrefix$keyReference';
    final pendingEncoded = await _store.read(pendingKey);
    final activeEncoded = await _store.read(activeKey);

    if (pendingEncoded == null) {
      if (activeEncoded == null) {
        throw const DeviceKeyVaultException(
          'key_not_found',
          'The device key does not exist.',
        );
      }
      final active = _decodeRecord(activeEncoded, expectedState: 'active');
      try {
        if (active.credentialId != credentialId) {
          throw const DeviceKeyVaultException(
            'credential_conflict',
            'The active device key belongs to a different credential.',
          );
        }
      } finally {
        active.seed.fillRange(0, active.seed.length, 0);
      }
      return;
    }

    final pending = _decodeRecord(pendingEncoded, expectedState: 'pending');
    try {
      if (activeEncoded != null) {
        final active = _decodeRecord(activeEncoded, expectedState: 'active');
        try {
          if (active.credentialId != credentialId ||
              !_constantTimeEquals(active.seed, pending.seed) ||
              !_constantTimeEquals(
                active.publicKeyBytes,
                pending.publicKeyBytes,
              )) {
            throw const DeviceKeyVaultException(
              'credential_conflict',
              'The active device key conflicts with the pending key.',
            );
          }
        } finally {
          active.seed.fillRange(0, active.seed.length, 0);
        }
      } else {
        await _store.write(
          activeKey,
          jsonEncode({
            'version': 1,
            'algorithm': 'ed25519',
            'state': 'active',
            'credential_id': credentialId,
            'seed': base64UrlEncode(pending.seed),
            'public_key': base64UrlEncode(pending.publicKeyBytes),
          }),
        );
      }
      await _store.delete(pendingKey);
    } finally {
      pending.seed.fillRange(0, pending.seed.length, 0);
    }
  }

  Future<List<int>> _newSeed() async {
    final factory = _seedFactory;
    late final List<int> seed;
    if (factory == null) {
      final generatedKeyPair = await _algorithm.newKeyPair();
      try {
        seed = List<int>.of(
          await generatedKeyPair.extractPrivateKeyBytes(),
          growable: false,
        );
      } finally {
        _destroy(generatedKeyPair);
      }
    } else {
      seed = await factory();
    }
    if (seed.length != 32 || seed.any((byte) => byte < 0 || byte > 255)) {
      throw const DeviceKeyVaultException(
        'invalid_seed',
        'An Ed25519 device seed must contain exactly 32 bytes.',
      );
    }
    return Uint8List.fromList(seed);
  }

  Future<DevicePublicIdentity> _publicIdentity(
    String keyReference,
    List<int> rawPublicKey,
  ) async {
    if (rawPublicKey.length != 32) {
      throw const DeviceKeyVaultException(
        'corrupt_key',
        'An Ed25519 public key must contain exactly 32 bytes.',
      );
    }
    final spki = Uint8List.fromList([..._spkiPrefix, ...rawPublicKey]);
    final digest = await _sha256.hash(spki);
    return DevicePublicIdentity(
      keyReference: keyReference,
      publicKeySpkiDer: spki,
      fingerprint: 'sha256:${_hex(digest.bytes)}',
    );
  }

  Future<_StoredDeviceKey> _readRecord(String keyReference) async {
    _validateReference(keyReference);
    final activeEncoded = await _store.read(
      '$_activeRecordPrefix$keyReference',
    );
    var encoded = activeEncoded;
    encoded ??= await _store.read('$_recordPrefix$keyReference');
    if (encoded == null) {
      throw const DeviceKeyVaultException(
        'key_not_found',
        'The device key does not exist.',
      );
    }
    return _decodeRecord(
      encoded,
      expectedState: activeEncoded == null ? 'pending' : 'active',
    );
  }

  static _StoredDeviceKey _decodeRecord(
    String encoded, {
    required String expectedState,
  }) {
    Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      throw const DeviceKeyVaultException(
        'corrupt_key',
        'The pending device key record is malformed.',
      );
    }
    if (decoded is! Map<String, Object?> ||
        decoded['version'] != 1 ||
        decoded['algorithm'] != 'ed25519' ||
        decoded['state'] != expectedState ||
        (expectedState == 'pending'
            ? decoded['credential_id'] != null
            : decoded['credential_id'] is! String) ||
        decoded['seed'] is! String ||
        decoded['public_key'] is! String) {
      throw const DeviceKeyVaultException(
        'corrupt_key',
        'The pending device key record has an unsupported shape.',
      );
    }
    try {
      final seed = base64Url.decode(decoded['seed']! as String);
      final publicKey = base64Url.decode(decoded['public_key']! as String);
      if (seed.length != 32 || publicKey.length != 32) {
        throw const FormatException('invalid Ed25519 key length');
      }
      final credentialId = decoded['credential_id'] as String?;
      if (credentialId != null) {
        _validateOpaqueId(credentialId, 'credential ID');
      }
      return _StoredDeviceKey(
        seed: seed,
        publicKeyBytes: publicKey,
        credentialId: credentialId,
      );
    } on FormatException catch (_) {
      throw const DeviceKeyVaultException(
        'corrupt_key',
        'The pending device key record contains invalid key bytes.',
      );
    } on DeviceKeyVaultException catch (_) {
      throw const DeviceKeyVaultException(
        'corrupt_key',
        'The pending device key record contains invalid key bytes.',
      );
    }
  }

  Future<String> _uniqueOpaqueReference() async {
    for (var attempt = 0; attempt < 8; attempt += 1) {
      final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
      final reference = _hex(bytes);
      if (await _store.read('$_recordPrefix$reference') == null &&
          await _store.read('$_activeRecordPrefix$reference') == null) {
        return reference;
      }
    }
    throw const DeviceKeyVaultException(
      'key_reference_collision',
      'A unique pending device key reference could not be generated.',
    );
  }

  static void _validateReference(String value) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(value)) {
      throw const DeviceKeyVaultException(
        'invalid_key_reference',
        'The device key reference is invalid.',
      );
    }
  }

  static void _validateOpaqueId(String value, String label) {
    if (value.isEmpty ||
        value.length > 256 ||
        value.contains(RegExp(r'[\u0000-\u001f\u007f]'))) {
      throw DeviceKeyVaultException(
        'invalid_opaque_id',
        'The $label is invalid.',
      );
    }
  }

  static void _destroy(SimpleKeyPair keyPair) {
    if (!keyPair.hasBeenDestroyed) {
      keyPair.destroy();
    }
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    var difference = left.length ^ right.length;
    final length = left.length > right.length ? left.length : right.length;
    for (var index = 0; index < length; index += 1) {
      difference |=
          (index < left.length ? left[index] : 0) ^
          (index < right.length ? right[index] : 0);
    }
    return difference == 0;
  }
}

class _StoredDeviceKey {
  _StoredDeviceKey({
    required List<int> seed,
    required List<int> publicKeyBytes,
    required this.credentialId,
  }) : seed = Uint8List.fromList(seed),
       publicKeyBytes = Uint8List.fromList(publicKeyBytes);

  final Uint8List seed;
  final Uint8List publicKeyBytes;
  final String? credentialId;
}
