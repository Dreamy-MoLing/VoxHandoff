import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app/agent_talk_app.dart';
import 'application/voice_session_controller.dart';
import 'application/speech_playback_controller.dart';
import 'domain/voice.dart';
import 'domain/speech.dart';
import 'infrastructure/audio/media_kit_audio_playback.dart';
import 'infrastructure/audio/record_audio_capture.dart';
import 'infrastructure/security/flutter_secure_value_store.dart';
import 'infrastructure/storage/drift_local_transcript_store.dart';
import 'infrastructure/stt/bundled_stt_launcher.dart';
import 'infrastructure/stt/stdio_stt_port.dart';
import 'infrastructure/stt/unavailable_stt_port.dart';
import 'infrastructure/tts/gpt_sovits_tts_port.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.environment['VOXHANDOFF_SECURE_STORAGE_SELF_TEST'] == '1') {
    await _runSecureStorageSelfTest();
    exit(exitCode);
  }
  MediaKit.ensureInitialized();
  final transcriptStore = await DriftLocalTranscriptStore.forApplication();
  final stt = _productionSttPort();
  final playback = MediaKitAudioPlayback();
  final tts = _productionTtsPort();
  runApp(
    ProviderScope(
      overrides: [
        audioCapturePortProvider.overrideWithValue(RecordAudioCapture()),
        sttPortProvider.overrideWithValue(stt),
        localTranscriptStoreProvider.overrideWithValue(transcriptStore),
        audioPlaybackPortProvider.overrideWithValue(playback),
        speechStopPortProvider.overrideWithValue(playback),
        if (tts != null) ...[
          ttsPortProvider.overrideWithValue(tts),
          speechEnabledProvider.overrideWithValue(true),
        ],
      ],
      child: const AgentTalkApp(),
    ),
  );
}

TtsPort? _productionTtsPort() {
  const baseUrl = String.fromEnvironment('VOXHANDOFF_GSV_BASE_URL');
  const referenceAudio = String.fromEnvironment('VOXHANDOFF_GSV_REF_AUDIO');
  const promptText = String.fromEnvironment('VOXHANDOFF_GSV_PROMPT_TEXT');
  if (baseUrl.isEmpty || referenceAudio.isEmpty) return null;
  final uri = Uri.tryParse(baseUrl);
  // M3 production wiring is local-only. A future remote provider must add the
  // same explicit provider disclosure and re-consent boundary as remote STT.
  if (uri == null || uri.scheme != 'http' || !_isLoopback(uri.host)) {
    return null;
  }
  return GptSoVitsTtsPort(
    config: GptSoVitsConfig(
      baseUri: uri,
      referenceAudioPath: referenceAudio,
      promptText: promptText,
    ),
  );
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

SttPort _productionSttPort() {
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    return StdioSttPort(launch: bundledSttLauncher());
  }
  return const UnavailableSttPort(
    safeMessage:
        'Local STT runs only in the desktop bundle. Configure a consented remote provider on mobile.',
  );
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
