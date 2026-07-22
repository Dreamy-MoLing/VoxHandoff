from __future__ import annotations

import base64
import io
import json
import math
import struct
import tempfile
import unittest
from pathlib import Path

from voxhandoff_stt.backend import Transcript
from voxhandoff_stt.service import SttService


class FakeBackend:
    name = "fake-stt"
    model = "fixture-v1"

    def __init__(self) -> None:
        self.warmed = False
        self.calls = 0

    def warmup(self) -> None:
        self.warmed = True

    def transcribe(self, audio_path: Path, *, language: str | None) -> Transcript:
        self.calls += 1
        self.assert_private_wav(audio_path)
        return Transcript("检查 packages/core 的测试。", language or "zh", 0.99)

    @staticmethod
    def assert_private_wav(audio_path: Path) -> None:
        assert audio_path.suffix == ".wav"
        assert audio_path.stat().st_mode & 0o077 == 0


def request(request_id: str, method: str, params: dict | None = None) -> bytes:
    return (
        json.dumps(
            {
                "protocol": {"major": 1, "minor": 0},
                "id": request_id,
                "method": method,
                "params": params or {},
            }
        ).encode()
        + b"\n"
    )


def voiced_pcm(seconds: float = 0.2, sample_rate: int = 16000) -> bytes:
    samples = []
    for index in range(round(seconds * sample_rate)):
        value = round(math.sin(index * 2 * math.pi * 440 / sample_rate) * 4000)
        samples.append(struct.pack("<h", value))
    return b"".join(samples)


class SttServiceTest(unittest.TestCase):
    def run_service(self, payload: bytes, *, provisional_seconds: float = 100.0):
        output = io.StringIO()
        errors = io.StringIO()
        backend = FakeBackend()
        with tempfile.TemporaryDirectory() as directory:
            service = SttService(
                backend,
                output=output,
                error_output=errors,
                temp_root=Path(directory),
                provisional_seconds=provisional_seconds,
            )
            code = service.serve(io.BytesIO(payload))
            remaining = list(Path(directory).iterdir())
        return code, [json.loads(line) for line in output.getvalue().splitlines()], errors.getvalue(), backend, remaining

    def test_health_warmup_and_streaming_final(self) -> None:
        audio = voiced_pcm()
        payload = b"".join(
            [
                request("health", "health"),
                request("warm", "warmup"),
                request(
                    "start",
                    "start",
                    {"session_id": "session-1", "sample_rate": 16000, "channels": 1, "language": "zh"},
                ),
                request(
                    "push",
                    "push",
                    {
                        "session_id": "session-1",
                        "sequence": 1,
                        "audio_base64": base64.b64encode(audio).decode(),
                    },
                ),
                request("end", "end", {"session_id": "session-1"}),
            ]
        )
        code, replies, errors, backend, remaining = self.run_service(payload)
        self.assertEqual(code, 0)
        self.assertEqual(replies[0]["result"]["status"], "cold")
        self.assertEqual(replies[1]["result"]["status"], "warm")
        self.assertEqual(replies[-1]["result"]["text"], "检查 packages/core 的测试。")
        self.assertTrue(backend.warmed)
        self.assertEqual(backend.calls, 1)
        self.assertEqual(errors, "")
        self.assertEqual(remaining, [])

    def test_cancel_discards_audio_and_unknown_end_fails_safely(self) -> None:
        audio = voiced_pcm()
        payload = b"".join(
            [
                request("start", "start", {"session_id": "session-2", "sample_rate": 16000, "channels": 1}),
                request(
                    "push",
                    "push",
                    {
                        "session_id": "session-2",
                        "sequence": 1,
                        "audio_base64": base64.b64encode(audio).decode(),
                    },
                ),
                request("cancel", "cancel", {"session_id": "session-2"}),
                request("end", "end", {"session_id": "session-2"}),
            ]
        )
        _, replies, errors, backend, remaining = self.run_service(payload)
        self.assertEqual(replies[2]["result"]["status"], "cancelled")
        self.assertEqual(replies[3]["error"]["code"], "stt_session_unknown")
        self.assertEqual(backend.calls, 0)
        self.assertEqual(errors, "")
        self.assertEqual(remaining, [])

    def test_silence_never_becomes_a_request(self) -> None:
        silence = bytes(6400)
        payload = b"".join(
            [
                request("start", "start", {"session_id": "session-3", "sample_rate": 16000, "channels": 1}),
                request(
                    "push",
                    "push",
                    {
                        "session_id": "session-3",
                        "sequence": 1,
                        "audio_base64": base64.b64encode(silence).decode(),
                    },
                ),
                request("end", "end", {"session_id": "session-3"}),
            ]
        )
        _, replies, _, backend, _ = self.run_service(payload)
        self.assertEqual(replies[-1]["error"]["code"], "stt_no_audio")
        self.assertEqual(backend.calls, 0)

    def test_rejects_sequence_gap_and_malformed_frames_without_echoing_payload(self) -> None:
        secret_marker = "not-a-real-secret-value"
        payload = b"".join(
            [
                b'{"bad":"' + secret_marker.encode() + b'"}\n',
                request("start", "start", {"session_id": "session-4", "sample_rate": 16000, "channels": 1}),
                request(
                    "gap",
                    "push",
                    {
                        "session_id": "session-4",
                        "sequence": 2,
                        "audio_base64": base64.b64encode(voiced_pcm()).decode(),
                    },
                ),
            ]
        )
        _, replies, errors, _, _ = self.run_service(payload)
        self.assertEqual(replies[0]["error"]["code"], "protocol_version_unsupported")
        self.assertEqual(replies[-1]["error"]["code"], "stt_audio_sequence_invalid")
        combined = json.dumps(replies) + errors
        self.assertNotIn(secret_marker, combined)

    def test_startup_removes_crash_residue(self) -> None:
        output = io.StringIO()
        errors = io.StringIO()
        backend = FakeBackend()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stale = root / "voxhandoff-stt-crash.wav"
            stale.write_bytes(b"private audio")
            unrelated = root / "keep.txt"
            unrelated.write_text("keep")
            service = SttService(backend, output=output, error_output=errors, temp_root=root)
            service.close()
            self.assertFalse(stale.exists())
            self.assertTrue(unrelated.exists())


if __name__ == "__main__":
    unittest.main()
