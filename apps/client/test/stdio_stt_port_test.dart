import 'dart:io';
import 'dart:typed_data';

import 'package:agent_talk_client/domain/voice.dart';
import 'package:agent_talk_client/infrastructure/stt/stdio_stt_port.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stdio STT rejects stale events and can cancel pending final', () async {
    final port = StdioSttPort(
      launch: () => Process.start('python3', ['-u', '-c', _sidecarFixture]),
    );
    addTearDown(port.close);
    final session = await port.start(
      sessionId: 'session-fixture',
      audio: const AudioCaptureConfig(),
      language: 'zh',
    );
    final updates = <TranscriptUpdate>[];
    final subscription = session.updates.listen(updates.add);
    addTearDown(subscription.cancel);

    await session.push(Uint8List.fromList([1, 0, 2, 0]));
    await Future<void>.delayed(Duration.zero);
    expect(updates, hasLength(1));
    expect(updates.single.text, '较新文本');
    expect(updates.single.sequence, 2);

    final finishing = expectLater(
      session.finish(),
      throwsA(
        isA<VoicePortException>().having(
          (error) => error.failure.code,
          'code',
          'stt_cancelled',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await session.cancel();
    await finishing;
  });
}

const _sidecarFixture = r'''
import json
import sys

protocol = {"major": 1, "minor": 0}
pending_end = None

def emit(value):
    value["protocol"] = protocol
    print(json.dumps(value, ensure_ascii=False, separators=(",", ":")), flush=True)

for line in sys.stdin:
    request = json.loads(line)
    request_id = request["id"]
    method = request["method"]
    params = request.get("params", {})
    if method == "start":
        emit({"id": request_id, "result": {"status": "recording"}})
    elif method == "push":
        emit({"event": "transcript.provisional", "session_id": params["session_id"], "sequence": 2, "text": "较新文本"})
        emit({"event": "transcript.provisional", "session_id": params["session_id"], "sequence": 1, "text": "迟到旧文本"})
        emit({"id": request_id, "result": {"accepted_sequence": params["sequence"]}})
    elif method == "end":
        pending_end = request_id
    elif method == "cancel":
        if pending_end is not None:
            emit({"id": pending_end, "error": {"stage": "stt", "code": "stt_cancelled", "message": "cancelled"}})
            pending_end = None
        emit({"id": request_id, "result": {"status": "cancelled"}})
''';
