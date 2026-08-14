import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/presentation/mobile_visual_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureValueStore implements SecureValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test(
    'persists and restores presentation-only theme and font choices',
    () async {
      final store = _MemorySecureValueStore();
      final original = MobileVisualPreferences(store: store);

      await original.setTheme(MobileVisualTheme.light);
      await original.setFontSize(26);

      final restored = MobileVisualPreferences(store: store);
      await restored.restore();

      expect(restored.theme, MobileVisualTheme.light);
      expect(restored.fontSize, 26);
      expect(restored.customBackgroundPreview, isFalse);
    },
  );

  test('ignores malformed or out-of-range visual preference records', () async {
    final store = _MemorySecureValueStore();
    final preferences = MobileVisualPreferences(store: store);
    await store.write(
      'voxhandoff.v1.mobile-visual-preferences',
      '{"version":1,"theme":"light","font_size":99}',
    );

    await preferences.restore();

    expect(preferences.theme, MobileVisualTheme.light);
    expect(preferences.fontSize, 21);
  });
}
