from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from threading import Lock
from typing import Protocol


@dataclass(frozen=True)
class Transcript:
    text: str
    language: str | None = None
    confidence: float | None = None


class SttBackend(Protocol):
    @property
    def name(self) -> str: ...

    @property
    def model(self) -> str: ...

    def warmup(self) -> None: ...

    def transcribe(self, audio_path: Path, *, language: str | None) -> Transcript: ...


class FasterWhisperBackend:
    def __init__(
        self,
        model: str,
        *,
        device: str = "cpu",
        compute_type: str = "int8",
    ) -> None:
        self._model_name = model
        self._device = device
        self._compute_type = compute_type
        self._instance = None
        self._lock = Lock()

    @property
    def name(self) -> str:
        return "faster-whisper"

    @property
    def model(self) -> str:
        return self._model_name

    def warmup(self) -> None:
        self._load()

    def _load(self):
        with self._lock:
            if self._instance is None:
                from faster_whisper import WhisperModel

                self._instance = WhisperModel(
                    self._model_name,
                    device=self._device,
                    compute_type=self._compute_type,
                )
            return self._instance

    def transcribe(self, audio_path: Path, *, language: str | None) -> Transcript:
        model = self._load()
        with self._lock:
            text, info = self._run(model, audio_path, language=language, vad_filter=True)
            # The service has already rejected silent/near-silent PCM by RMS.
            # Silero VAD can still discard a short technical utterance in full;
            # retrying only that empty result avoids a false "no speech" while
            # retaining VAD for normal recordings.
            if not text:
                text, info = self._run(model, audio_path, language=language, vad_filter=False)
        probability = getattr(info, "language_probability", None)
        confidence = float(probability) if probability is not None else None
        detected = getattr(info, "language", None)
        return Transcript(text=text, language=detected, confidence=confidence)

    @staticmethod
    def _run(model, audio_path: Path, *, language: str | None, vad_filter: bool):
        segments, info = model.transcribe(
            str(audio_path),
            language=language,
            beam_size=5,
            vad_filter=vad_filter,
            vad_parameters={"min_silence_duration_ms": 500} if vad_filter else None,
            condition_on_previous_text=False,
        )
        return "".join(segment.text for segment in segments).strip(), info
