import 'package:agent_talk_client/domain/desktop_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const available = DesktopCapability.available('available');
  const degraded = DesktopCapability.degraded('degraded');

  test('headless startup accepts explicit tray degradation', () {
    const snapshot = DesktopCapabilitySnapshot(
      isDesktop: true,
      hotkey: available,
      tray: degraded,
      notifications: available,
      window: available,
    );

    expect(
      snapshot.passesStartupSelfTest(wayland: false, headless: true),
      isTrue,
    );
    expect(
      snapshot.passesStartupSelfTest(wayland: false, headless: false),
      isFalse,
    );
  });

  test('startup still requires notifications and window controls', () {
    const snapshot = DesktopCapabilitySnapshot(
      isDesktop: true,
      hotkey: degraded,
      tray: degraded,
      notifications: degraded,
      window: available,
    );

    expect(
      snapshot.passesStartupSelfTest(wayland: true, headless: true),
      isFalse,
    );
  });
}
