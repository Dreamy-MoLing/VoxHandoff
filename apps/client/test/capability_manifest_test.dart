import 'package:agent_talk_client/domain/capability_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CapabilityManifest', () {
    test('解析 design 第 5 节示例 JSON', () {
      final manifest = CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": true },
        "stt": { "available": true, "capabilities": { } },
        "tts": { "available": true, "voices": [ ], "recommended_voice": "Bronya" },
        "hermes": { "profile": "p", "model": "m", "capabilities": { } }
      }
      ''');
      expect(manifest.chat.available, isTrue);
      expect(manifest.stt.available, isTrue);
      expect(manifest.tts.available, isTrue);
      expect(manifest.tts.recommendedVoice, 'Bronya');
      expect(manifest.hermes.profile, 'p');
      expect(manifest.hermes.model, 'm');
      expect(manifest.chatAvailable, isTrue);
      expect(manifest.sttAvailable, isTrue);
      expect(manifest.ttsAvailable, isTrue);
      expect(manifest.hermesAvailable, isTrue);
    });

    test('未知字段被容忍且保留，不影响判定', () {
      final manifest = CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": true, "future_flag": "x", "nested": { "a": 1 } },
        "stt": { "available": true, "capabilities": { "real_time": true } },
        "tts": { "available": true, "voices": ["A"], "recommended_voice": "A", "sample_rate": 22050 },
        "hermes": { "profile": "p", "model": "m", "future": [1, 2] },
        "top_level_unknown": { "any": true }
      }
      ''');
      expect(manifest.chat.available, isTrue);
      expect(manifest.stt.capabilities['real_time'], isTrue);
      expect(manifest.tts.voices, ['A']);
      expect(manifest.tts.extra.containsKey('sample_rate'), isTrue);
      expect(manifest.hermes.extra.containsKey('future'), isTrue);
      expect(manifest.others.containsKey('top_level_unknown'), isTrue);
    });

    test('缺失字段按不可用降级，不抛错', () {
      final manifest = CapabilityManifest.fromJsonString('{ }');
      expect(manifest.chat.available, isFalse);
      expect(manifest.stt.available, isFalse);
      expect(manifest.tts.available, isFalse);
      expect(manifest.hermes.available, isFalse);
      expect(manifest.chatAvailable, isFalse);
    });

    test('非布尔 available 视为不可用；voices 非列表视为空', () {
      final manifest = CapabilityManifest.fromJsonString('''
      {
        "chat": { "available": "yes" },
        "stt": { "available": 1, "capabilities": "not-a-map" },
        "tts": { "available": true, "voices": "Bronya", "recommended_voice": 42 },
        "hermes": { "profile": "p", "model": "m" }
      }
      ''');
      expect(manifest.chat.available, isFalse);
      expect(manifest.stt.available, isFalse);
      expect(manifest.stt.capabilities, isEmpty);
      expect(manifest.tts.available, isTrue);
      expect(manifest.tts.voices, isEmpty);
      expect(manifest.tts.recommendedVoice, isNull);
      expect(manifest.hermes.available, isTrue);
    });

    test('hermes 无 available 但存在内容时视为已配置', () {
      final manifest = CapabilityManifest.fromJsonString('''
      { "hermes": { "model": "hermes-1", "capabilities": { "tools": true } } }
      ''');
      expect(manifest.hermes.available, isTrue);
      expect(manifest.hermes.model, 'hermes-1');
    });

    test('voices 过滤非字符串项', () {
      final manifest = CapabilityManifest.fromJsonString('''
      { "tts": { "available": true, "voices": ["Bronya", 7, null, true, "Miao"] } }
      ''');
      expect(manifest.tts.voices, ['Bronya', 'Miao']);
    });

    test('非法 JSON 抛出 ManifestParseException', () {
      expect(
        () => CapabilityManifest.fromJsonString('{ not json'),
        throwsA(
          isA<ManifestParseException>().having(
            (e) => e.code,
            'code',
            'manifest_invalid_json',
          ),
        ),
      );
    });

    test('顶层非对象抛出 ManifestParseException', () {
      expect(
        () => CapabilityManifest.fromJsonString('["chat"]'),
        throwsA(isA<ManifestParseException>()),
      );
      expect(
        () => CapabilityManifest.fromJsonString('42'),
        throwsA(isA<ManifestParseException>()),
      );
    });

    test('section 值为非对象时按不可用降级', () {
      final manifest = CapabilityManifest.fromJsonString('''
      {
        "chat": "available",
        "stt": 3,
        "tts": [true],
        "hermes": null
      }
      ''');
      expect(manifest.chat.available, isFalse);
      expect(manifest.stt.available, isFalse);
      expect(manifest.tts.available, isFalse);
      expect(manifest.hermes.available, isFalse);
    });

    test('hermes 显式 available:false 不会被内容推导覆盖', () {
      final manifest = CapabilityManifest.fromJsonString('''
      { "hermes": { "available": false, "profile": "p", "model": "m" } }
      ''');
      expect(manifest.hermes.available, isFalse);
    });
  });
}
