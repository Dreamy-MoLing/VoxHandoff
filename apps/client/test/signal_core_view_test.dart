import 'dart:ui' as ui;

import 'package:agent_talk_client/domain/signal_core.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/signal_core_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

Future<ui.FragmentProgram> _failedShader() =>
    Future<ui.FragmentProgram>.error(StateError('synthetic shader failure'));
