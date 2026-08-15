import 'package:agent_talk_client/app/agent_talk_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps an editable draft local until explicit confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AgentTalkApp()));

    expect(find.text('Not paired'), findsOneWidget);
    expect(
      find.textContaining('Draft text stays on this device'),
      findsOneWidget,
    );
    expect(find.text('Send unavailable'), findsOneWidget);
    expect(find.byTooltip('Record voice draft'), findsOneWidget);
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send unavailable'),
    );
    expect(sendButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  review this first  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();

    expect(find.text('Confirmed locally'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.textContaining('review this first'), findsOneWidget);
  });

  testWidgets('keeps the shell usable at a phone-sized viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AgentTalkApp()));

    expect(find.text('Pair Gateway to start'), findsNothing);
    expect(find.text('未配对'), findsOneWidget);
    expect(find.byTooltip('打开设置'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('signal-core-view')));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Hermes workspace'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
