import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:agent_talk_client/presentation/qr_pairing_scanner_page.dart';

void main() {
  testWidgets('keeps the camera stopped until scanning is requested', (
    tester,
  ) async {
    final controller = MobileScannerController(
      autoStart: false,
      formats: const [BarcodeFormat.qrCode],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(home: QrPairingScannerPage(controller: controller)),
    );
    await tester.pump();

    expect(find.text('开始扫描'), findsOneWidget);
    expect(controller.value.isRunning, isFalse);
    expect(controller.value.isStarting, isFalse);
  });
}
