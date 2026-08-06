import 'dart:ui' as ui;

import 'package:agent_talk_client/domain/signal_core.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/signal_core_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'selects balanced and high-refresh render profiles deterministically',
    () {
      expect(
        signalRenderProfileForRefreshRate(60),
        SignalRenderProfile.balanced60,
      );
      expect(
        signalRenderProfileForRefreshRate(120),
        SignalRenderProfile.highRefresh120,
      );
      expect(
        signalRenderProfileForRefreshRate(0),
        SignalRenderProfile.balanced60,
      );
      expect(
        signalRenderProfileForRefreshRate(99),
        SignalRenderProfile.balanced60,
      );
      expect(
        signalRenderProfileForRefreshRate(100),
        SignalRenderProfile.highRefresh120,
      );
      expect(
        signalRenderProfileForRefreshRate(144),
        SignalRenderProfile.highRefresh120,
      );
    },
  );

  testWidgets('keeps a semantic static core when shader loading fails', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentTalkDarkTheme(),
        home: Scaffold(
          body: SignalCoreView(
            snapshot: const SignalCoreSnapshot(
              state: SignalCoreState.uncertain,
              label: 'Request outcome uncertain',
              requestId: 'request-1',
              sourceIdentity: 'request-1',
              audioLevel: 0,
              playbackLevel: 0,
            ),
            dimension: 180,
            shaderLoader: _failedShader,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('signal-core-view')), findsOneWidget);
    expect(find.bySemanticsLabel('Request outcome uncertain'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('honors reduced motion without losing state geometry', (
    tester,
  ) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentTalkDarkTheme(),
        home: const Scaffold(
          body: SignalCoreView(
            snapshot: SignalCoreSnapshot(
              state: SignalCoreState.recording,
              label: 'Recording voice',
              sourceIdentity: 'voice-1',
              audioLevel: 0.8,
              playbackLevel: 0,
            ),
            dimension: 220,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.bySemanticsLabel('Recording voice'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fault texture is a one-shot transition pulse', (tester) async {
    Future<void> pumpState(SignalCoreState state) => tester.pumpWidget(
      MaterialApp(
        theme: buildAgentTalkDarkTheme(),
        home: Scaffold(
          body: SignalCoreView(
            snapshot: SignalCoreSnapshot(
              state: state,
              label: state.name,
              audioLevel: 0,
              playbackLevel: 0,
            ),
            dimension: 180,
            profile: SignalRenderProfile.balanced60,
            shaderLoader: _failedShader,
          ),
        ),
      ),
    );

    await pumpState(SignalCoreState.idle);
    await pumpState(SignalCoreState.failed);
    await tester.pump(const Duration(milliseconds: 140));
    final corePaint = find.descendant(
      of: find.byKey(const ValueKey('signal-core-view')),
      matching: find.byType(CustomPaint),
    );
    var painter =
        tester.widget<CustomPaint>(corePaint).painter! as SignalCorePainter;
    expect(painter.faultPulse, closeTo(1, 0.01));

    await tester.pump(const Duration(milliseconds: 160));
    painter =
        tester.widget<CustomPaint>(corePaint).painter! as SignalCorePainter;
    expect(painter.faultPulse, closeTo(0, 0.01));
  });

  testWidgets('idle core does not schedule continuous frames', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAgentTalkDarkTheme(),
        home: const Scaffold(
          body: SignalCoreView(
            snapshot: SignalCoreSnapshot(
              state: SignalCoreState.idle,
              label: 'VoxHandoff idle',
              audioLevel: 0,
              playbackLevel: 0,
            ),
            dimension: 180,
            profile: SignalRenderProfile.balanced60,
            shaderLoader: _failedShader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Future<ui.FragmentProgram> _failedShader() =>
    Future<ui.FragmentProgram>.error(StateError('synthetic shader failure'));
