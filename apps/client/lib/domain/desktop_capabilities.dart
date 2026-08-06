enum DesktopCapabilityLevel { unsupported, available, degraded }

class DesktopCapability {
  const DesktopCapability({required this.level, required this.safeMessage});

  const DesktopCapability.unsupported(String safeMessage)
    : this(level: DesktopCapabilityLevel.unsupported, safeMessage: safeMessage);

  const DesktopCapability.available(String safeMessage)
    : this(level: DesktopCapabilityLevel.available, safeMessage: safeMessage);

  const DesktopCapability.degraded(String safeMessage)
    : this(level: DesktopCapabilityLevel.degraded, safeMessage: safeMessage);

  final DesktopCapabilityLevel level;
  final String safeMessage;
}

class DesktopCapabilitySnapshot {
  const DesktopCapabilitySnapshot({
    required this.isDesktop,
    required this.hotkey,
    required this.tray,
    required this.notifications,
    required this.window,
  });

  const DesktopCapabilitySnapshot.unsupported()
    : this(
        isDesktop: false,
        hotkey: const DesktopCapability.unsupported(
          'Global voice hotkeys are available only on desktop.',
        ),
        tray: const DesktopCapability.unsupported(
          'The system tray is available only on desktop.',
        ),
        notifications: const DesktopCapability.unsupported(
          'Desktop notifications are available only on desktop.',
        ),
        window: const DesktopCapability.unsupported(
          'Desktop window controls are available only on desktop.',
        ),
      );

  final bool isDesktop;
  final DesktopCapability hotkey;
  final DesktopCapability tray;
  final DesktopCapability notifications;
  final DesktopCapability window;

  bool get hasDegradedCapability =>
      hotkey.level == DesktopCapabilityLevel.degraded ||
      tray.level == DesktopCapabilityLevel.degraded ||
      notifications.level == DesktopCapabilityLevel.degraded ||
      window.level == DesktopCapabilityLevel.degraded;

  bool passesStartupSelfTest({required bool wayland, required bool headless}) {
    if (!isDesktop) return false;
    final degradationExpected = wayland || headless;
    final hotkeyPassed =
        hotkey.level == DesktopCapabilityLevel.available ||
        (degradationExpected &&
            hotkey.level == DesktopCapabilityLevel.degraded);
    final trayPassed =
        tray.level == DesktopCapabilityLevel.available ||
        (degradationExpected && tray.level == DesktopCapabilityLevel.degraded);
    return hotkeyPassed &&
        trayPassed &&
        notifications.level == DesktopCapabilityLevel.available &&
        window.level == DesktopCapabilityLevel.available;
  }

  String get safeSummary => [
    hotkey,
    tray,
    notifications,
    window,
  ].map((capability) => capability.safeMessage).join('\n');
}

enum DesktopAttentionKind { approval, clarification, completed, failed }

typedef DesktopVoiceToggle = Future<void> Function();

abstract interface class DesktopIntegrationPort {
  Future<DesktopCapabilitySnapshot> initialize({
    required DesktopVoiceToggle onVoiceToggle,
  });

  Future<void> showAttention(DesktopAttentionKind kind);

  Future<void> showWindow();

  Future<void> close();
}
