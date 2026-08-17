import 'dart:convert';

import '../../domain/manual_trust.dart';
import 'device_key_vault.dart';

/// 手动连接 TOFU 信任记录的持久层。
///
/// 只有显式接受的记录才会被保存；未知指纹绝不会自动写入。
/// 存储损坏时按"无信任记录"处理——宁可从新提示，不静默信任。
abstract interface class TofuTrustStore {
  Future<bool> isTrusted(Uri origin, String fingerprint);

  Future<void> record(Uri origin, String fingerprint);

  Future<List<TofuTrustRecord>> records();
}

class SecureTofuTrustStore implements TofuTrustStore {
  SecureTofuTrustStore(this._store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _key = 'voxhandoff.v1.tofu-trust';
  final SecureValueStore _store;
  final DateTime Function() _clock;

  @override
  Future<bool> isTrusted(Uri origin, String fingerprint) async {
    if (!origin.hasScheme || origin.scheme.toLowerCase() != 'https') {
      return false;
    }
    final originKey = normalizeTofuOrigin(origin);
    final stored = await records();
    for (final record in stored) {
      if (record.matches(originKey, fingerprint)) return true;
    }
    return false;
  }

  @override
  Future<void> record(Uri origin, String fingerprint) async {
    final originKey = normalizeTofuOrigin(origin);
    final existing = await records();
    for (final record in existing) {
      if (record.matches(originKey, fingerprint)) return;
    }
    final record = TofuTrustRecord(
      origin: originKey,
      fingerprint: fingerprint,
      acceptedAt: _clock().toUtc(),
    );
    await _store.write(
      _key,
      jsonEncode({
        'version': 1,
        'records': [
          for (final item in [...existing, record]) _encode(item),
        ],
      }),
    );
  }

  @override
  Future<List<TofuTrustRecord>> records() async {
    final raw = await _store.read(_key);
    return raw == null ? const [] : _decode(raw);
  }

  List<TofuTrustRecord> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> || decoded['version'] != 1) {
        return const [];
      }
      final list = decoded['records'];
      if (list is! List) return const [];
      final records = <TofuTrustRecord>[];
      for (final item in list) {
        if (item is! Map<String, Object?> ||
            item['origin'] is! String ||
            item['fingerprint'] is! String ||
            item['accepted_at'] is! String) {
          continue;
        }
        final acceptedAt = DateTime.tryParse(item['accepted_at']! as String);
        final origin = item['origin']! as String;
        final fingerprint = item['fingerprint']! as String;
        if (acceptedAt == null ||
            origin.isEmpty ||
            fingerprint.isEmpty ||
            fingerprint.length > 128) {
          continue;
        }
        records.add(
          TofuTrustRecord(
            origin: origin,
            fingerprint: fingerprint,
            acceptedAt: acceptedAt,
          ),
        );
      }
      return List.unmodifiable(records);
    } on FormatException {
      // 损坏数据按无信任记录处理（fail-safe：重新提示）。
      return const [];
    } on Object {
      return const [];
    }
  }

  Map<String, Object?> _encode(TofuTrustRecord record) => {
    'origin': record.origin,
    'fingerprint': record.fingerprint,
    'accepted_at': record.acceptedAt.toIso8601String(),
  };
}
