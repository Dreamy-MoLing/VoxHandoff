import 'package:agent_talk_client/app/agent_talk_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpAtSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const ProviderScope(child: AgentTalkApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('unpaired shell matches the desktop visual baseline', (tester) async {
    await pumpAtSize(tester, const Size(1280, 800));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/unpaired_desktop.png'),
    );
  });

  testWidgets('unpaired shell matches the phone visual baseline', (tester) async {
    await pumpAtSize(tester, const Size(390, 844));

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/unpaired_phone.png'),
    );
  });
}
