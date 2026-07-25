import 'dart:io';

import 'package:agent_talk_client/domain/desktop_capabilities.dart';
import 'package:agent_talk_client/infrastructure/desktop/production_desktop_integration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Wayland reports the global hotkey degradation without hiding it',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channelName in [
        'window_manager',
        'tray_manager',
        'local_notifier',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channelName), (
          call,
        ) async {
          calls.add('$channelName:${call.method}');
          return null;
        });
      }
      final integration = ProductionDesktopIntegration(
        environment: const {'XDG_SESSION_TYPE': 'wayland'},
      );
      addTearDown(() async {
        await integration.close();
        for (final channelName in [
          'window_manager',
          'tray_manager',
          'local_notifier',
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
        }
      });

      final snapshot = await integration.initialize(onVoiceToggle: () async {});

      expect(snapshot.isDesktop, isTrue);
      expect(snapshot.hotkey.level, DesktopCapabilityLevel.degraded);
      expect(snapshot.hotkey.safeMessage, contains('Wayland'));
      expect(snapshot.tray.level, DesktopCapabilityLevel.available);
      expect(calls, contains('window_manager:setPreventClose'));
    },
    skip: !Platform.isLinux,
  );

  test(
    'attention notification contains only fixed safe metadata',
    () async {
      final notificationPayloads = <Object?>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('tray_manager'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('local_notifier'),
        (call) async {
          if (call.method == 'notify') {
            notificationPayloads.add(call.arguments);
          }
          return null;
        },
      );
      final integration = ProductionDesktopIntegration(
        environment: const {'XDG_SESSION_TYPE': 'wayland'},
      );
      addTearDown(() async {
        await integration.close();
        for (final channelName in [
          'window_manager',
          'tray_manager',
          'local_notifier',
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
        }
      });
      await integration.initialize(onVoiceToggle: () async {});
      integration.onWindowBlur();

      await integration.showAttention(DesktopAttentionKind.approval);

      expect(notificationPayloads, hasLength(1));
      final serialized = notificationPayloads.single.toString();
      expect(serialized, contains('Open the app'));
      expect(serialized, isNot(contains('full agent reply secret')));
      expect(serialized, isNot(contains('operationSummarySha256')));
    },
    skip: !Platform.isLinux,
  );

  test(
    'close-to-tray is enabled only after tray setup succeeds',
    () async {
      final windowCalls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('window_manager'),
        (call) async {
          windowCalls.add(call.method);
          return null;
        },
      );
      messenger.setMockMethodCallHandler(const MethodChannel('tray_manager'), (
        call,
      ) async {
        if (call.method == 'setIcon') {
          throw PlatformException(code: 'tray_unavailable');
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('local_notifier'),
        (_) async => null,
      );
      final integration = ProductionDesktopIntegration(
        environment: const {'XDG_SESSION_TYPE': 'wayland'},
      );
      addTearDown(() async {
        await integration.close();
        for (final channelName in [
          'window_manager',
          'tray_manager',
          'local_notifier',
        ]) {
          messenger.setMockMethodCallHandler(MethodChannel(channelName), null);
        }
      });

      final snapshot = await integration.initialize(onVoiceToggle: () async {});

      expect(snapshot.tray.level, DesktopCapabilityLevel.degraded);
      expect(windowCalls, isNot(contains('setPreventClose')));
    },
    skip: !Platform.isLinux,
  );
}
