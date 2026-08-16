import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/agent_talk_app.dart';
import 'application/desktop_integration_controller.dart';
import 'application/direct_chat_controller.dart';
import 'application/hermes_conversation_controller.dart';
import 'application/speech_playback_controller.dart';
import 'application/voice_provider_settings_controller.dart';
import 'application/voice_session_controller.dart';
import 'domain/voice.dart';
import 'infrastructure/audio/media_kit_audio_playback.dart';
import 'infrastructure/audio/record_audio_capture.dart';
import 'infrastructure/desktop/production_desktop_integration.dart';
import 'infrastructure/security/flutter_secure_value_store.dart';
import 'infrastructure/security/remote_stt_trusted_root_certificate_store.dart';
import 'infrastructure/security/voice_provider_settings_store.dart';
import 'infrastructure/storage/drift_local_direct_chat_store.dart';
import 'infrastructure/storage/drift_local_transcript_store.dart';
import 'infrastructure/voice/production_voice_port_factory.dart';
import 'presentation/m4_render_benchmark.dart';
import 'presentation/mvp_render_benchmark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.environment['VOXHANDOFF_SECURE_STORAGE_SELF_TEST'] == '1') {
    await _runSecureStorageSelfTest();
    exit(exitCode);
  }
  if (Platform.environment['VOXHANDOFF_AUDIO_CAPTURE_SELF_TEST'] == '1') {
    await _runAudioCaptureSelfTest();
    exit(exitCode);
  }
  if (Platform.environment['VOXHANDOFF_DESKTOP_INTEGRATION_SELF_TEST'] == '1') {
    await _runDesktopIntegrationSelfTest();
    exit(exitCode);
  }
  if (shouldRunMvpRenderBenchmark(Platform.environment)) {
    await runMvpRenderBenchmark();
    exit(exitCode);
  }
  if (shouldRunM4RenderBenchmark(Platform.environment)) {
    await runM4RenderBenchmark();
    exit(exitCode);
  }
  MediaKit.ensureInitialized();
  final transcriptStore = await DriftLocalTranscriptStore.forApplication();
  final directChatStore = await DriftLocalDirectChatStore.forApplication();
  final playback = MediaKitAudioPlayback();
  final secureValueStore = FlutterSecureValueStore();
  List<int>? remoteTrustedRootCertificates;
  try {
    remoteTrustedRootCertificates = await loadRemoteSttTrustedRootCertificates(
      secureValueStore,
    );
  } on Object {
    // A malformed Gateway profile must not prevent the app from opening. The
    // remote provider will fail closed unless it uses system trust.
  }
  final isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  runApp(
    ProviderScope(
      overrides: [
        audioCapturePortProvider.overrideWithValue(RecordAudioCapture()),
        voicePortFactoryProvider.overrideWithValue(
          ProductionVoicePortFactory(
            secureValueStore: secureValueStore,
            remoteTrustedRootCertificates: remoteTrustedRootCertificates,
            remoteTrustedRootCertificatesProvider: () async {
              try {
                return loadRemoteSttTrustedRootCertificates(secureValueStore);
              } on Object {
                return remoteTrustedRootCertificates;
              }
            },
          ),
        ),
        voiceProviderSettingsStoreProvider.overrideWithValue(
          VoiceProviderSettingsStore(secureValueStore),
        ),
        localTranscriptStoreProvider.overrideWithValue(transcriptStore),
        directChatHistoryStoreProvider.overrideWithValue(directChatStore),
        directContextStoreProvider.overrideWithValue(directChatStore),
        hermesConversationHistoryStoreProvider.overrideWithValue(
          directChatStore,
        ),
        audioPlaybackPortProvider.overrideWithValue(playback),
        if (isDesktop)
          desktopIntegrationPortProvider.overrideWithValue(
            ProductionDesktopIntegration(),
          ),
      ],
      child: const AgentTalkApp(),
    ),
  );
}

Future<void> _runDesktopIntegrationSelfTest() async {
  if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
    stderr.writeln(
      'desktop integration self-test failed: desktop platform required',
    );
    exitCode = 1;
    return;
  }
  final integration = ProductionDesktopIntegration();
  try {
    final snapshot = await integration.initialize(onVoiceToggle: () async {});
    stdout.writeln(
      'desktop integration self-test: '
      'hotkey=${snapshot.hotkey.level.name} '
      'tray=${snapshot.tray.level.name} '
      'notifications=${snapshot.notifications.level.name} '
      'window=${snapshot.window.level.name}',
    );
    final wayland =
        Platform.isLinux &&
        (Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() == 'wayland' ||
            (Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty ?? false));
    final headless =
        Platform.environment['VOXHANDOFF_DESKTOP_SELF_TEST_HEADLESS'] == '1';
    if (!snapshot.passesStartupSelfTest(wayland: wayland, headless: headless)) {
      stderr.writeln(
        'desktop integration self-test failed: required capability unavailable',
      );
      exitCode = 1;
    }
  } finally {
    await integration.close();
  }
}

Future<void> _runAudioCaptureSelfTest() async {
  final capture = RecordAudioCapture();
  var bytes = 0;
  final done = Completer<void>();
  StreamSubscription<Uint8List>? subscription;
  try {
    final session = await capture.start(const AudioCaptureConfig());
    subscription = session.audioChunks.listen(
      (chunk) => bytes += chunk.length,
      onError: (Object _) {
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    await session.stop();
    await done.future.timeout(const Duration(seconds: 5));
    if (bytes < 3200) {
      stderr.writeln('audio capture self-test failed: insufficient PCM');
      exitCode = 1;
      return;
    }
    stdout.writeln('audio capture self-test passed: PCM stream received');
  } on Object {
    stderr.writeln('audio capture self-test failed: microphone unavailable');
    exitCode = 1;
  } finally {
    await subscription?.cancel();
    await capture.close();
  }
}

Future<void> _runSecureStorageSelfTest() async {
  const key = 'voxhandoff.v1.platform-self-test';
  const expected = 'non-secret-round-trip';
  final store = FlutterSecureValueStore();
  try {
    await store.write(key, expected);
    if (await store.read(key) != expected) {
      stderr.writeln('secure storage self-test failed at read-back');
      exitCode = 1;
      return;
    }
  } finally {
    await store.delete(key);
  }
  if (await store.read(key) != null) {
    stderr.writeln('secure storage self-test failed at cleanup');
    exitCode = 1;
    return;
  }
  stdout.writeln('secure storage self-test passed');
}
