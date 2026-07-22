from __future__ import annotations

import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from voxhandoff_stt.backend import FasterWhisperBackend


class FakeWhisperModel:
    def __init__(self, texts: list[str]) -> None:
        self._texts = iter(texts)
        self.vad_calls: list[bool] = []

    def transcribe(self, _path: str, **options):
        self.vad_calls.append(options["vad_filter"])
        text = next(self._texts)
        segments = [SimpleNamespace(text=text)] if text else []
        info = SimpleNamespace(language="zh", language_probability=0.99)
        return segments, info


class FasterWhisperBackendTest(unittest.TestCase):
    def test_retries_an_empty_vad_result_after_service_voice_gate(self) -> None:
        model = FakeWhisperModel(["", "短技术请求。"])
        backend = FasterWhisperBackend("fixture")
        backend._instance = model
        with tempfile.NamedTemporaryFile(suffix=".wav") as audio:
            result = backend.transcribe(Path(audio.name), language="zh")
        self.assertEqual(result.text, "短技术请求。")
        self.assertEqual(model.vad_calls, [True, False])

    def test_keeps_the_normal_vad_path_single_pass(self) -> None:
        model = FakeWhisperModel(["正常请求。"])
        backend = FasterWhisperBackend("fixture")
        backend._instance = model
        with tempfile.NamedTemporaryFile(suffix=".wav") as audio:
            result = backend.transcribe(Path(audio.name), language="zh")
        self.assertEqual(result.text, "正常请求。")
        self.assertEqual(model.vad_calls, [True])


if __name__ == "__main__":
    unittest.main()
