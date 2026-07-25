import 'package:agent_talk_client/app/agent_talk_app.dart';
import 'package:agent_talk_client/presentation/design/agent_talk_theme.dart';
import 'package:agent_talk_client/presentation/pairing_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAtSize(WidgetTester tester, Size size) async {
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );
  await tester.pumpWidget(const ProviderScope(child: AgentTalkApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unpaired shell matches the desktop visual baseline', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(1280, 800));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/unpaired_desktop.png'),
    );
  });

  testWidgets('unpaired shell matches the phone visual baseline', (
    tester,
  ) async {
    await pumpAtSize(tester, const Size(390, 844));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/unpaired_phone.png'),
    );
  });

  testWidgets('pairing setup matches the desktop visual baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAgentTalkDarkTheme(),
          home: const Scaffold(body: DevicePairingDialog(restoreOnOpen: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DevicePairingDialog),
      matchesGoldenFile('goldens/pairing_setup_desktop.png'),
    );
  });

  testWidgets('pairing setup matches the phone visual baseline', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAgentTalkDarkTheme(),
          home: const Scaffold(body: DevicePairingDialog(restoreOnOpen: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DevicePairingDialog),
      matchesGoldenFile('goldens/pairing_setup_phone.png'),
    );
  });
}
