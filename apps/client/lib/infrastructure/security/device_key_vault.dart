import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

abstract interface class SecureValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class DevicePublicIdentity {
  DevicePublicIdentity({
    required this.keyReference,
    required List<int> publicKeySpkiDer,
    required this.fingerprint,
  }) : publicKeySpkiDer = List.unmodifiable(publicKeySpkiDer);

  final String keyReference;
  final List<int> publicKeySpkiDer;
  final String fingerprint;

  @override
  String toString() =>
      'DevicePublicIdentity(keyReference: $keyReference, fingerprint: $fingerprint)';
}

class DeviceKeyVaultException implements Exception {
  const DeviceKeyVaultException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'DeviceKeyVaultException($code): $message';
}

class DeviceKeyVault {
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

  Future<DevicePublicIdentity> inspect(String keyReference) async {
    final record = await _readRecord(keyReference);
    return _publicIdentity(keyReference, record.publicKeyBytes);
  }

  Future<List<int>> sign(String keyReference, List<int> payload) async {
    final record = await _readRecord(keyReference);
    final keyPair = await _algorithm.newKeyPairFromSeed(record.seed);
    try {
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
      _destroy(keyPair);
    }
  }

  Future<void> discard(String keyReference) async {
    _validateReference(keyReference);
    await _store.delete('$_recordPrefix$keyReference');
  }

  Future<List<int>> _newSeed() async {
    final factory = _seedFactory;
    late final List<int> seed;
    if (factory == null) {
      final generatedKeyPair = await _algorithm.newKeyPair();
      try {
        seed = await generatedKeyPair.extractPrivateKeyBytes();
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
    final encoded = await _store.read('$_recordPrefix$keyReference');
    if (encoded == null) {
      throw const DeviceKeyVaultException(
        'key_not_found',
        'The pending device key does not exist.',
      );
    }
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
      return _StoredDeviceKey(seed: seed, publicKeyBytes: publicKey);
    } on FormatException {
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
      if (await _store.read('$_recordPrefix$reference') == null) {
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
  _StoredDeviceKey({required List<int> seed, required List<int> publicKeyBytes})
    : seed = Uint8List.fromList(seed),
      publicKeyBytes = Uint8List.fromList(publicKeyBytes);

  final Uint8List seed;
  final Uint8List publicKeyBytes;
}
