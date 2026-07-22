import 'dart:typed_data';

import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/stt/remote_stt_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final disclosure = RemoteSttDisclosure(
    providerId: 'safe-fixture-provider',
    origin: Uri(scheme: 'https', host: 'stt.example.test'),
    tlsPolicy: 'system-roots-hostname-verified',
    retentionPolicy: 'fixture-no-retention',
    streaming: false,
    revision: 'fixture-v1',
  );

  test('remote STT fails closed when any disclosed fact changes', () {
    final accepted = RemoteSttConsent(
      disclosure: disclosure,
      acceptedAt: DateTime.utc(2026, 7, 22),
    );
    expect(
      () => ConsentedRemoteSttPort(
        disclosure: RemoteSttDisclosure(
          providerId: 'safe-fixture-provider',
          origin: Uri(scheme: 'https', host: 'stt.example.test'),
          tlsPolicy: 'system-roots-hostname-verified',
          retentionPolicy: 'fixture-24-hours',
          streaming: false,
          revision: 'fixture-v1',
        ),
        consent: accepted,
        transport: _FakeRemoteTransport(),
      ),
      throwsA(
        isA<VoicePortException>().having(
          (error) => error.failure.code,
          'code',
          'remote_stt_consent_required',
        ),
      ),
    );
  });

  test(
    'consented adapter buffers PCM, finalizes, and cancels locally',
    () async {
      final transport = _FakeRemoteTransport();
      final port = ConsentedRemoteSttPort(
        disclosure: disclosure,
        consent: RemoteSttConsent(
          disclosure: disclosure,
          acceptedAt: DateTime.utc(2026, 7, 22),
        ),
        transport: transport,
      );
      final session = await port.start(
        sessionId: 'session-safe',
        audio: const AudioCaptureConfig(),
        language: 'zh',
      );
      await session.push(Uint8List.fromList([1, 0, 2, 0]));
      final result = await session.finish();
      expect(result.text, '检查测试。');
      expect(transport.request?.audio, Uint8List.fromList([1, 0, 2, 0]));

      final cancelled = await port.start(
        sessionId: 'session-cancel',
        audio: const AudioCaptureConfig(),
      );
      await cancelled.push(Uint8List.fromList([3, 0]));
      await cancelled.cancel();
      expect(transport.calls, 1);
    },
  );
}

class _FakeRemoteTransport implements RemoteSttTransport {
  RemoteSttRequest? request;
  int calls = 0;

  @override
  Future<FinalTranscript> transcribe(
    RemoteSttDisclosure disclosure,
    RemoteSttRequest request,
  ) async {
    calls += 1;
    this.request = request;
    return const FinalTranscript(
      text: '检查测试。',
      audioDuration: Duration(milliseconds: 100),
      transcriptionDuration: Duration(milliseconds: 20),
    );
  }

  @override
  Future<void> warmUp(RemoteSttDisclosure disclosure) async {}

  @override
  Future<void> close() async {}
}
