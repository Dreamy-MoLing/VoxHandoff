import 'package:agent_talk_client/presentation/voice_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'voice settings keep Hermes, STT, and Piper configuration distinct',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () => showVoiceSettingsSheet(context),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      expect(find.text('Hermes'), findsOneWidget);
      expect(find.text('Local faster-whisper STT'), findsOneWidget);
      expect(find.text('Local Piper TTS'), findsOneWidget);
      expect(find.text('Configure direct LLM API'), findsOneWidget);
      expect(find.byKey(const Key('gateway-import-ca-button')), findsOneWidget);
      expect(find.text('Test STT readiness'), findsOneWidget);
      final testButton = find.widgetWithText(
        OutlinedButton,
        'Test TTS readiness',
      );
      expect(tester.widget<OutlinedButton>(testButton).onPressed, isNull);

      await tester.ensureVisible(find.byType(Switch).last);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(find.text('Piper HTTP origin'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(testButton).onPressed, isNotNull);
    },
  );
}
