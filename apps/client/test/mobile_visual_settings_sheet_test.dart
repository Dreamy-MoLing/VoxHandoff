import 'package:agent_talk_client/infrastructure/security/device_key_vault.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/mobile_visual_preferences.dart';
import 'package:agent_talk_client/presentation/mobile_visual_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureValueStore implements SecureValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  testWidgets('settings sheet changes the mobile theme and exposes controls', (
    tester,
  ) async {
    final preferences = MobileVisualPreferences(
      store: _MemorySecureValueStore(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentTalkMobileDarkTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showMobileVisualSettingsSheet(
                  context,
                  preferences: preferences,
                  onOpenVoiceSettings: (_) async {},
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('视觉设置'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('亮色'));
    await tester.pump();

    expect(preferences.theme, MobileVisualTheme.light);
    expect(tester.takeException(), isNull);
  });
}
