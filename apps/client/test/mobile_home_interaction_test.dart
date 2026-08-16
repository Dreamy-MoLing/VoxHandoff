import 'package:agent_talk_client/app/agent_talk_app.dart';
import 'package:agent_talk_client/application/chat_source_controller.dart';
import 'package:agent_talk_client/application/client_session_controller.dart';
import 'package:agent_talk_client/application/hermes_conversation_controller.dart';
import 'package:agent_talk_client/application/voice_session_controller.dart';
import 'package:agent_talk_client/domain/client_session.dart';
import 'package:agent_talk_client/domain/hermes_conversation.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _phoneSize = Size(390, 844);
const _coreKey = ValueKey<String>('signal-core-view');
const _longPress = Duration(milliseconds: 540);

class _FakeVoiceSessionController extends VoiceSessionController {
  var starts = 0;
  var stops = 0;
  var cancels = 0;

  @override
  VoiceSessionState build() => const VoiceSessionState();

  @override
  Future<void> startRecording({String? language}) async {
    starts += 1;
    state = state.copyWith(
      phase: VoiceInputPhase.recording,
      sessionId: 'test-voice-session',
      audioLevel: 0.72,
    );
  }

  @override
  Future<void> stopRecording() async {
    stops += 1;
    state = state.copyWith(
      phase: VoiceInputPhase.idle,
      clearSession: true,
      clearTranscript: true,
      audioLevel: 0,
    );
  }

  @override
  Future<void> cancelRecording() async {
    cancels += 1;
    state = state.copyWith(
      phase: VoiceInputPhase.cancelled,
      clearSession: true,
      clearTranscript: true,
      audioLevel: 0,
    );
  }
}

class _FakeClientSessionController extends ClientSessionController {
  _FakeClientSessionController(this.initialPhase);

  final GatewayConnectionPhase initialPhase;

  @override
  ClientSessionState build() =>
      ClientSessionState(connectionPhase: initialPhase);
}

class _FakeChatSourceController extends ChatSourceController {
  _FakeChatSourceController(this.initialSource);

  final ChatSource initialSource;

  @override
  ChatSource build() => initialSource;
}

class _FakeHermesConversationController extends HermesConversationController {
  _FakeHermesConversationController(this.initialState);

  final HermesConversationState initialState;

  @override
  HermesConversationState build() => initialState;
}

class _MobileHarness {
  const _MobileHarness({required this.voice, required this.session});

  final _FakeVoiceSessionController voice;
  final _FakeClientSessionController session;
}

Future<_MobileHarness> _pumpPhone(
  WidgetTester tester, {
  GatewayConnectionPhase connectionPhase = GatewayConnectionPhase.unpaired,
  ChatSource source = ChatSource.hermes,
  HermesConversationState? hermesConversation,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = _phoneSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (reducedMotion) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
  }

  final voice = _FakeVoiceSessionController();
  final session = _FakeClientSessionController(connectionPhase);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        voiceSessionProvider.overrideWith(() => voice),
        clientSessionProvider.overrideWith(() => session),
        chatSourceProvider.overrideWith(
          () => _FakeChatSourceController(source),
        ),
        if (hermesConversation != null)
          hermesConversationProvider.overrideWith(
            () => _FakeHermesConversationController(hermesConversation),
          ),
      ],
      child: const AgentTalkApp(),
    ),
  );
  await tester.pump();
  return _MobileHarness(voice: voice, session: session);
}

Future<void> _enterTextMode(WidgetTester tester) async {
  await tester.tapAt(_coreInteractionPoint(tester));
  await tester.pump();
}

Offset _coreInteractionPoint(WidgetTester tester) {
  final topLeft = tester.getTopLeft(find.byKey(_coreKey));
  final size = tester.getSize(find.byKey(_coreKey));
  return Offset(
    (topLeft.dx + size.width / 2).clamp(1, _phoneSize.width - 1),
    (topLeft.dy + size.height / 2).clamp(1, _phoneSize.height - 1),
  );
}

Future<TestGesture> _startCorePress(WidgetTester tester) =>
    tester.startGesture(_coreInteractionPoint(tester));

void _expectCoreSize(WidgetTester tester, double expected) {
  expect(tester.getSize(find.byKey(_coreKey)).width, closeTo(expected, 0.1));
}

void main() {
  testWidgets('idle tap enters text mode', (tester) async {
    await _pumpPhone(tester);

    expect(find.byType(TextField), findsNothing);
    await _enterTextMode(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('打开设置'), findsOneWidget);
  });

  testWidgets('text tap returns to idle mode', (tester) async {
    await _pumpPhone(tester);
    await _enterTextMode(tester);

    await tester.tapAt(_coreInteractionPoint(tester));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('打开设置'), findsNothing);
  });

  testWidgets('539ms does not enter recording', (tester) async {
    final harness = await _pumpPhone(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(const Duration(milliseconds: 539));
    expect(harness.voice.starts, 0);
    expect(find.byType(TextField), findsNothing);

    await gesture.up();
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('540ms enters recording exactly once', (tester) async {
    final harness = await _pumpPhone(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(_longPress);
    await tester.pump(const Duration(seconds: 2));

    expect(harness.voice.starts, 1);
    _expectCoreSize(tester, 436.8);
    expect(find.bySemanticsLabel(RegExp(r'^正在录音')), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(harness.voice.starts, 1);
    expect(harness.voice.stops, 1);
  });

  testWidgets('long-press end does not produce an extra tap', (tester) async {
    final harness = await _pumpPhone(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(_longPress);
    await gesture.up();
    await tester.pump();

    expect(harness.voice.starts, 1);
    expect(harness.voice.stops, 1);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('cancel before threshold clears the pending press', (
    tester,
  ) async {
    final harness = await _pumpPhone(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(const Duration(milliseconds: 539));
    await gesture.cancel();
    await tester.pump(_longPress);

    expect(harness.voice.starts, 0);
    expect(harness.voice.stops, 0);
    expect(harness.voice.cancels, 0);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('cancel after threshold finalizes voice without a tap', (
    tester,
  ) async {
    final harness = await _pumpPhone(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(_longPress);
    expect(harness.voice.starts, 1);
    await gesture.cancel();
    await tester.pump();

    expect(harness.voice.stops, 1);
    expect(harness.voice.cancels, 0);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('text long-press preserves conversation and top bar', (
    tester,
  ) async {
    final harness = await _pumpPhone(tester);
    await _enterTextMode(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(_longPress);
    await tester.pump();

    expect(harness.voice.starts, 1);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('打开设置'), findsOneWidget);
    expect(find.text('未配对'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('text long-press enters the recording visual state', (
    tester,
  ) async {
    final harness = await _pumpPhone(tester);
    await _enterTextMode(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(_longPress);
    await tester.pump();

    expect(harness.voice.starts, 1);
    expect(find.bySemanticsLabel(RegExp(r'^正在录音')), findsOneWidget);
    await gesture.up();
  });

  testWidgets('idle long-press does not open conversation early', (
    tester,
  ) async {
    final harness = await _pumpPhone(tester);
    final gesture = await _startCorePress(tester);

    await tester.pump(const Duration(milliseconds: 539));
    expect(find.byType(TextField), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(harness.voice.starts, 1);
    expect(find.byType(TextField), findsNothing);
    await gesture.up();
  });

  testWidgets('abnormal connection capsule remains persistent', (tester) async {
    await _pumpPhone(tester);
    await _enterTextMode(tester);

    expect(find.text('未配对'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('未配对'), findsOneWidget);
  });

  testWidgets('Hermes conversation shows its unconfigured status', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      source: ChatSource.hermesConversation,
      hermesConversation: _hermesState(HermesConversationPhase.unconfigured),
    );
    await _enterTextMode(tester);

    expect(find.text('未配置'), findsOneWidget);
    expect(find.text('未配对'), findsNothing);
  });

  testWidgets('Hermes conversation shows its failure status', (tester) async {
    await _pumpPhone(
      tester,
      source: ChatSource.hermesConversation,
      hermesConversation: _hermesState(HermesConversationPhase.failed),
    );
    await _enterTextMode(tester);

    expect(find.text('连接失败'), findsOneWidget);
    expect(find.text('未配对'), findsNothing);
  });

  testWidgets('Hermes ready status uses the connected indicator', (
    tester,
  ) async {
    await _pumpPhone(
      tester,
      source: ChatSource.hermesConversation,
      hermesConversation: _hermesState(HermesConversationPhase.ready),
    );
    await _enterTextMode(tester);

    expect(find.byTooltip('连接状态：已连接'), findsOneWidget);
    expect(find.text('未配对'), findsNothing);
  });

  testWidgets('connected capsule disappears after three seconds', (
    tester,
  ) async {
    final harness = await _pumpPhone(
      tester,
      connectionPhase: GatewayConnectionPhase.connecting,
    );
    await _enterTextMode(tester);
    harness.session.setConnectionPhase(GatewayConnectionPhase.connected);
    await tester.pump();

    expect(find.text('已连接'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('已连接'), findsNothing);
    expect(find.byTooltip('连接状态：已连接'), findsOneWidget);
  });

  testWidgets('reduced motion retains mobile core semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpPhone(tester, reducedMotion: true);
    await _enterTextMode(tester);

    expect(find.bySemanticsLabel('VoxHandoff 待命'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('390x844 uses final core size and clipping geometry', (
    tester,
  ) async {
    await _pumpPhone(tester);

    _expectCoreSize(tester, 358.8);
    await _enterTextMode(tester);
    _expectCoreSize(tester, 436.8);
    expect(tester.getBottomRight(find.byKey(_coreKey)).dy, greaterThan(844));
  });
}

HermesConversationState _hermesState(HermesConversationPhase phase) =>
    HermesConversationState(
      phase: phase,
      configuration: HermesConversationConfiguration(
        providerProfileId: 'hermes-provider-1',
        origin: Uri.parse('https://hermes.example.test'),
        model: 'hermes-model',
        conversationId: 'hermes-conversation-1',
        sessionId: 'hermes-session-1',
        sessionKey: 'hermes-session-key',
      ),
      credentialAvailable: true,
    );
