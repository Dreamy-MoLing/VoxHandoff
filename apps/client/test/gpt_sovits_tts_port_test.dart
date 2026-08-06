import 'package:agent_talk_client/infrastructure/tts/gpt_sovits_tts_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GPT-SoVITS endpoint is restricted to an exact loopback HTTP origin',
    () {
      for (final unsafe in [
        Uri.parse('https://127.0.0.1:8642'),
        Uri.parse('http://tts.example.test:8642'),
        Uri.parse('http://user@127.0.0.1:8642'),
        Uri.parse('http://127.0.0.1:8642/tenant'),
        Uri.parse('http://127.0.0.1:8642/?target=other'),
        Uri.parse('http://127.0.0.1:8642/#other'),
      ]) {
        expect(
          () => GptSoVitsConfig(
            baseUri: unsafe,
            referenceAudioPath: '/private/local-reference.wav',
            promptText: '参考文本',
          ),
          throwsFormatException,
          reason: unsafe.toString(),
        );
      }

      expect(
        () => GptSoVitsConfig(
          baseUri: Uri.parse('http://127.0.0.1:8642'),
          referenceAudioPath: '/private/local-reference.wav',
          promptText: '参考文本',
        ),
        returnsNormally,
      );
    },
  );
}
