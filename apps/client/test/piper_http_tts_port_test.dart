import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_talk_client/domain/speech.dart';
import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/tts/piper_http_tts_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Piper configuration only accepts exact loopback HTTP origins', () {
    for (final unsafe in [
      Uri.parse('https://127.0.0.1:5000'),
      Uri.parse('http://tts.example.test:5000'),
      Uri.parse('http://user@127.0.0.1:5000'),
      Uri.parse('http://127.0.0.1:5000/tenant'),
      Uri.parse('http://127.0.0.1:5000/?target=other'),
    ]) {
      expect(
        () => PiperHttpTtsConfig(baseUri: unsafe),
        throwsFormatException,
        reason: unsafe.toString(),
      );
    }
  });

  test(
    'Piper probe sends no text and synthesis accepts bounded WAV only',
    () async {
      final received = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      unawaited(
        server.forEach((request) async {
          received.add(request.uri);
          if (request.uri.path == '/info') {
            request.response.headers.contentType = ContentType.json;
            request.response.write(jsonEncode({'voice': 'test'}));
          } else if (request.uri.path == '/synthesize') {
            expect(request.method, 'POST');
            final body = await utf8.decoder.bind(request).join();
            expect(jsonDecode(body), {
              'text': 'hello',
              'voice': 'test',
              'length_scale': 1.25,
            });
            request.response.add(_wavBytes);
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        }),
      );
      final port = PiperHttpTtsPort(
        config: PiperHttpTtsConfig(
          baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
          voice: 'test',
          lengthScale: 1.25,
        ),
      );
      addTearDown(port.close);

      await port.warmUp();
      final speech = await port.synthesize(
        SpeechSegment(
          conversationId: 'conversation',
          requestId: 'request',
          messageRevision: BigInt.one,
          index: 0,
          text: 'hello',
        ),
      );

      expect(received.map((uri) => uri.path), ['/info', '/synthesize']);
      expect(speech.mimeType, 'audio/wav');
      expect(speech.bytes, _wavBytes);
    },
  );

  test('Piper probe exposes a safe configuration failure', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    unawaited(
      server.forEach((request) async {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
      }),
    );
    final port = PiperHttpTtsPort(
      config: PiperHttpTtsConfig(
        baseUri: Uri.parse('http://127.0.0.1:${server.port}'),
      ),
    );
    addTearDown(port.close);

    await expectLater(
      port.warmUp(),
      throwsA(
        isA<VoicePortException>().having(
          (error) => error.failure.code,
          'code',
          'piper_connection_failed',
        ),
      ),
    );
  });
}

final _wavBytes = List<int>.generate(44, (index) {
  const riff = [0x52, 0x49, 0x46, 0x46];
  const wave = [0x57, 0x41, 0x56, 0x45];
  if (index < 4) return riff[index];
  if (index >= 8 && index < 12) return wave[index - 8];
  return 0;
});
