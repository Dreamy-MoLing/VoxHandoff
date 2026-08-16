import 'package:agent_talk_client/application/voice_provider_settings_controller.dart';
import 'package:agent_talk_client/domain/interaction_mode.dart';
import 'package:agent_talk_client/presentation/voice_settings_sheet.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/stt/remote_stt_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fetches remote STT disclosure into the settings form', (
    tester,
  ) async {
    final disclosure = RemoteSttDisclosure(
      providerId: 'declared-provider',
      origin: Uri.parse('https://stt.example.test'),
      tlsPolicy: 'declared TLS policy',
      retentionPolicy: 'declared retention policy',
      streaming: false,
      revision: 'declared-v2',
    );
    String? fetchedToken;
    String? fetchedProviderId;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteSttTransportFactoryProvider.overrideWithValue(
            (tokenProvider) => _FakeDisclosureTransport(
              disclosure,
              tokenProvider,
              onFetch: (providerId, token) {
                fetchedProviderId = providerId;
                fetchedToken = token;
              },
            ),
          ),
        ],
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
    await tester.tap(find.byKey(const Key('stt-provider-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已同意的 HTTPS 来源（Android）').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ExpansionTile>(
            find.byKey(const Key('remote-stt-advanced-disclosure')),
          )
          .initiallyExpanded,
      isFalse,
    );

    final tokenField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '远程来源令牌',
    );
    await tester.ensureVisible(tokenField);
    await tester.enterText(tokenField, 'input-token');

    final fetchButton = find.byKey(
      const Key('remote-stt-fetch-disclosure-button'),
    );
    await tester.ensureVisible(fetchButton);
    await tester.tap(fetchButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remote-stt-advanced-disclosure')));
    await tester.pumpAndSettle();

    expect(fetchedProviderId, 'voxhandoff-stt');
    expect(fetchedToken, 'input-token');
    expect(
      tester
          .widget<TextField>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText == '远程来源 ID',
            ),
          )
          .controller!
          .text,
      'declared-provider',
    );
    expect(
      tester
          .widget<TextField>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField &&
                  widget.decoration?.labelText == 'TLS 策略披露',
            ),
          )
          .controller!
          .text,
      'declared TLS policy',
    );
    expect(find.byKey(const Key('remote-stt-disclosure-error')), findsNothing);
  });

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
      expect(find.text('本地 faster-whisper STT'), findsOneWidget);
      expect(find.text('本地 Piper TTS'), findsOneWidget);
      expect(find.text('配置 Direct LLM 接口'), findsOneWidget);
      expect(find.byKey(const Key('gateway-import-ca-button')), findsOneWidget);
      expect(find.text('测试 STT 就绪状态'), findsOneWidget);
      final testButton = find.widgetWithText(OutlinedButton, '测试 TTS 就绪状态');
      expect(tester.widget<OutlinedButton>(testButton).onPressed, isNull);

      await tester.ensureVisible(find.byType(Switch).last);
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      expect(find.text('Piper HTTP 地址'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(testButton).onPressed, isNotNull);
    },
  );

  testWidgets('interaction mode selector updates the persisted default', (
    tester,
  ) async {
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

    final selector = find.byKey(const Key('voice-interaction-mode'));
    expect(selector, findsOneWidget);
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('通话模式（预览后发送）').last);
    await tester.pumpAndSettle();

    final mode = ProviderScope.containerOf(
      tester.element(selector),
      listen: false,
    ).read(voiceProviderSettingsProvider).settings.interactionMode;
    expect(mode, InteractionMode.call);
  });
}

class _FakeDisclosureTransport implements RemoteSttTransport {
  _FakeDisclosureTransport(
    this.disclosure,
    this.tokenProvider, {
    required this.onFetch,
  });

  final RemoteSttDisclosure disclosure;
  final RemoteSttTokenProvider tokenProvider;
  final void Function(String providerId, String token) onFetch;

  @override
  Future<void> warmUp(RemoteSttDisclosure disclosure) async {}

  @override
  Future<RemoteSttDisclosure> fetchDisclosure(
    Uri origin,
    String providerId,
  ) async {
    onFetch(providerId, await tokenProvider(providerId));
    return disclosure;
  }

  @override
  Future<FinalTranscript> transcribe(
    RemoteSttDisclosure disclosure,
    RemoteSttRequest request,
  ) => throw UnimplementedError();

  @override
  Future<void> close() async {}
}
