import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../domain/desktop_capabilities.dart';

class ProductionDesktopIntegration
    with TrayListener, WindowListener
    implements DesktopIntegrationPort {
  ProductionDesktopIntegration({Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final Map<String, String> _environment;
  final List<LocalNotification> _notifications = [];
  late DesktopVoiceToggle _onVoiceToggle;
  HotKey? _voiceHotKey;
  bool _initialized = false;
  bool _closed = false;
  bool _trayAvailable = false;
  bool _windowAvailable = false;
  bool _closeToTrayEnabled = false;
  bool _notificationsAvailable = false;
  bool _windowFocused = true;
  bool _voiceToggleInFlight = false;

  bool get _isDesktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  Future<DesktopCapabilitySnapshot> initialize({
    required DesktopVoiceToggle onVoiceToggle,
  }) async {
    if (_initialized) {
      throw StateError('Desktop integration is already initialized.');
    }
    _initialized = true;
    _onVoiceToggle = onVoiceToggle;
    if (!_isDesktop) {
      return const DesktopCapabilitySnapshot.unsupported();
    }

    final window = await _initializeWindow();
    final tray = await _initializeTray();
    if (_trayAvailable && _windowAvailable) {
      try {
        await windowManager.setPreventClose(true);
        _closeToTrayEnabled = true;
      } on Object {
        // The tray remains useful even if close-to-tray is unavailable.
      }
    }
    final notifications = await _initializeNotifications();
    final hotkey = await _initializeHotkey();
    return DesktopCapabilitySnapshot(
      isDesktop: true,
      hotkey: hotkey,
      tray: tray,
      notifications: notifications,
      window: window,
    );
  }

  Future<DesktopCapability> _initializeWindow() async {
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      _windowAvailable = true;
      return const DesktopCapability.available(
        'Window show and focus controls are available.',
      );
    } on Object {
      return const DesktopCapability.degraded(
        'Window controls are unavailable; normal platform close behavior remains active.',
      );
    }
  }

  Future<DesktopCapability> _initializeTray() async {
    try {
      final iconPath = Platform.isWindows
          ? 'assets/tray/voxhandoff-tray.ico'
          : 'assets/tray/voxhandoff-tray.png';
      await trayManager.setIcon(iconPath, isTemplate: Platform.isMacOS);
      await trayManager.setToolTip('VoxHandoff');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(label: 'Show VoxHandoff', onClick: (_) => showWindow()),
            MenuItem.separator(),
            MenuItem(label: 'Quit VoxHandoff', onClick: (_) => _quit()),
          ],
        ),
      );
      trayManager.addListener(this);
      _trayAvailable = true;
      return const DesktopCapability.available(
        'The system tray can restore the window and quit VoxHandoff.',
      );
    } on Object {
      return const DesktopCapability.degraded(
        'The system tray is unavailable; closing the window will exit normally.',
      );
    }
  }

  Future<DesktopCapability> _initializeNotifications() async {
    try {
      await localNotifier.setup(
        appName: 'VoxHandoff',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _notificationsAvailable = true;
      return const DesktopCapability.available(
        'Safe desktop attention notifications are available.',
      );
    } on Object {
      return const DesktopCapability.degraded(
        'Desktop notifications are unavailable; attention states remain visible in the app.',
      );
    }
  }

  Future<DesktopCapability> _initializeHotkey() async {
    final sessionType = _environment['XDG_SESSION_TYPE']?.toLowerCase();
    final hasWaylandDisplay =
        _environment['WAYLAND_DISPLAY']?.isNotEmpty ?? false;
    if (Platform.isLinux && (sessionType == 'wayland' || hasWaylandDisplay)) {
      return const DesktopCapability.degraded(
        'The global voice hotkey is unavailable on Wayland; Ctrl+Shift+Space still works while the app is focused.',
      );
    }
    final hotKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: const [HotKeyModifier.control, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (_) => unawaited(_toggleVoice()),
      );
      _voiceHotKey = hotKey;
      return const DesktopCapability.available(
        'Ctrl+Shift+Space toggles the voice draft globally.',
      );
    } on Object {
      return const DesktopCapability.degraded(
        'The global voice hotkey could not be registered; Ctrl+Shift+Space still works while the app is focused.',
      );
    }
  }

  Future<void> _toggleVoice() async {
    if (_voiceToggleInFlight || _closed) return;
    _voiceToggleInFlight = true;
    try {
      await _onVoiceToggle();
    } finally {
      _voiceToggleInFlight = false;
    }
  }

  @override
  Future<void> showAttention(DesktopAttentionKind kind) async {
    if (!_notificationsAvailable || _closed || _windowFocused) return;
    final (title, body) = switch (kind) {
      DesktopAttentionKind.approval => (
        'VoxHandoff needs approval',
        'Open the app to review the pending approval.',
      ),
      DesktopAttentionKind.clarification => (
        'VoxHandoff needs clarification',
        'Open the app to review the pending clarification.',
      ),
      DesktopAttentionKind.completed => (
        'VoxHandoff request completed',
        'Open the app to review the complete Agent reply.',
      ),
      DesktopAttentionKind.failed => (
        'VoxHandoff request failed',
        'Open the app to review the failure stage and recovery options.',
      ),
    };
    final notification = LocalNotification(
      title: title,
      body: body,
      silent: false,
    );
    notification.onClick = () => unawaited(showWindow());
    notification.onClose = (_) {
      localNotifier.removeListener(notification);
      _notifications.remove(notification);
    };
    _notifications.add(notification);
    try {
      await notification.show();
    } on Object {
      localNotifier.removeListener(notification);
      _notifications.remove(notification);
    }
  }

  @override
  Future<void> showWindow() async {
    if (!_windowAvailable || _closed) return;
    await windowManager.show();
    await windowManager.focus();
    _windowFocused = true;
  }

  Future<void> _quit() async {
    if (_closed) return;
    if (_windowAvailable) {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showWindow());
  }

  @override
  void onWindowClose() {
    if (_closeToTrayEnabled && !_closed) {
      unawaited(windowManager.hide());
    }
  }

  @override
  void onWindowFocus() {
    _windowFocused = true;
  }

  @override
  void onWindowBlur() {
    _windowFocused = false;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final hotKey = _voiceHotKey;
    if (hotKey != null) {
      await hotKeyManager.unregister(hotKey);
    }
    if (_trayAvailable) {
      trayManager.removeListener(this);
      await trayManager.destroy();
    }
    if (_windowAvailable) {
      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);
    }
    for (final notification in List<LocalNotification>.from(_notifications)) {
      try {
        await notification.destroy();
      } on Object {
        localNotifier.removeListener(notification);
      }
    }
    _notifications.clear();
  }
}
