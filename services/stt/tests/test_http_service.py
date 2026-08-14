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
from voxhandoff_stt.http_service import (
    HttpSttError,
    HttpSttProvider,
    read_request_body,
    validate_transcribe_payload,
)


class FakeBackend:
    name = "fake-stt"
    model = "fixture-v1"

    def warmup(self) -> None:
        pass

    def transcribe(self, audio_path: Path, *, language: str | None) -> Transcript:
        assert audio_path.stat().st_mode & 0o077 == 0
        return Transcript("中文 HTTPS 识别。", language or "zh", 0.91)


def voiced_pcm(seconds: float = 0.2, sample_rate: int = 16000) -> bytes:
    return b"".join(
        struct.pack("<h", round(math.sin(index * 2 * math.pi * 440 / sample_rate) * 4000))
        for index in range(round(seconds * sample_rate))
    )


class _Headers(dict[str, str]):
    pass


class HttpSttServiceTest(unittest.TestCase):
    def test_disclosure_returns_declared_upload_contract(self) -> None:
        with tempfile.TemporaryDirectory() as root:
            provider = HttpSttProvider(FakeBackend(), temp_root=Path(root))
            provider.warmup()
            declaration = provider.disclosure()
            protocol = declaration["protocol"]
            provider_id = declaration["provider_id"]
            tls_policy = declaration["tls_policy"]
            retention_policy = declaration["retention_policy"]
            streaming = declaration["streaming"]
        self.assertEqual(protocol, {"major": 1, "minor": 0})
        self.assertEqual(provider_id, "voxhandoff-stt")
        self.assertIn("TLS", str(tls_policy))
        self.assertIn("deleted", str(retention_policy))
        self.assertIs(streaming, False)
        self.assertIsInstance(declaration["revision"], str)

    def test_validation_requires_protocol_audio_contract(self) -> None:
        with self.assertRaisesRegex(HttpSttError, "protocol version"):
            validate_transcribe_payload({})
        with self.assertRaisesRegex(HttpSttError, "audio format"):
            validate_transcribe_payload(
                {
                    "protocol": {"major": 1, "minor": 0},
                    "session_id": "session-1",
                    "audio_format": "wav",
                    "sample_rate": 16000,
                    "channels": 1,
                    "audio_base64": "AA==",
                }
            )

    def test_transcribe_reuses_versioned_sidecar_contract(self) -> None:
        audio = voiced_pcm()
        value = {
            "protocol": {"major": 1, "minor": 0},
            "session_id": "session-1",
            "audio_format": "pcm_s16le",
            "sample_rate": 16000,
            "channels": 1,
            "language": "zh",
            "audio_base64": base64.b64encode(audio).decode("ascii"),
        }
        with tempfile.TemporaryDirectory() as directory:
            provider = HttpSttProvider(FakeBackend(), temp_root=Path(directory))
            provider.warmup()
            result = provider.transcribe(value)
            self.assertEqual(result["text"], "中文 HTTPS 识别。")
            self.assertEqual(result["language"], "zh")
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_content_length_body_is_bounded(self) -> None:
        body = b'{"ok":true}'
        self.assertEqual(
            read_request_body(io.BytesIO(body), _Headers({"Content-Length": str(len(body))})),
            body,
        )
        with self.assertRaisesRegex(HttpSttError, "too large"):
            read_request_body(io.BytesIO(), _Headers({"Content-Length": str(9 * 1024 * 1024)}))

    def test_chunked_body_is_decoded_with_limit(self) -> None:
        body = b"b\r\n{" + b'"ok":true}' + b"\r\n0\r\n\r\n"
        self.assertEqual(read_request_body(io.BytesIO(body), _Headers({"Transfer-Encoding": "chunked"})), b'{"ok":true}')


if __name__ == "__main__":
    unittest.main()
