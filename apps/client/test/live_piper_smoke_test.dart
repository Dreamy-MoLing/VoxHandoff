import 'dart:io';

import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/infrastructure/tts/piper_http_tts_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final enabled = Platform.environment['VOXHANDOFF_LIVE_PIPER'] == '1';

  test(
    'live Piper loopback probe and synthesis return bounded WAV',
    () async {
      final port = PiperHttpTtsPort(
        config: PiperHttpTtsConfig(baseUri: Uri.parse('http://127.0.0.1:5000')),
      );
      addTearDown(port.close);
      await port.warmUp();
      final result = await port.synthesize(
        SpeechSegment(
          conversationId: 'm5',
          requestId: 'piper-smoke',
          messageRevision: BigInt.one,
          index: 0,
          text: 'Voice chat is ready.',
        ),
      );
      expect(result.mimeType, 'audio/wav');
      expect(result.bytes.length, greaterThan(44));
      expect(result.bytes.sublist(0, 4), [0x52, 0x49, 0x46, 0x46]);
    },
    skip: !enabled ? 'Set VOXHANDOFF_LIVE_PIPER=1 to run live smoke.' : false,
  );
}
