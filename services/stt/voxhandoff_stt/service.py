from __future__ import annotations

import json
import math
import os
import tempfile
import time
import wave
from concurrent.futures import Future, ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from threading import Lock
from typing import Any, BinaryIO, TextIO

from . import __version__
from .backend import SttBackend, Transcript
from .protocol import ProtocolError, Request, decode_chunk, envelope, parse_request, require_opaque


@dataclass
class _Session:
    session_id: str
    sample_rate: int
    channels: int
    language: str | None
    audio: bytearray = field(default_factory=bytearray)
    next_sequence: int = 1
    event_sequence: int = 0
    last_provisional_bytes: int = 0
    provisional_future: Future[Transcript] | None = None
    final_future: Future[Transcript] | None = None
    final_request_id: str | None = None
    final_path: Path | None = None
    final_started_at: float | None = None
    final_audio_duration_ms: int | None = None
    generation: int = 0
    started_at: float = field(default_factory=time.monotonic)


class SttService:
    def __init__(
        self,
        backend: SttBackend,
        *,
        output: TextIO,
        error_output: TextIO,
        temp_root: Path,
        max_audio_seconds: int = 120,
        provisional_seconds: float = 2.0,
    ) -> None:
        self._backend = backend
        self._output = output
        self._error_output = error_output
        self._temp_root = temp_root
        self._max_audio_seconds = max_audio_seconds
        self._provisional_seconds = provisional_seconds
        self._backend_ready = False
        self._sessions: dict[str, _Session] = {}
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="voxhandoff-stt")
        self._write_lock = Lock()
        self._cleanup_stale_audio()

    def close(self) -> None:
        # EOF means the caller will not submit more work. Let an accepted final
        # transcription finish so its response is not silently lost, then scrub
        # any idle/cancelled session residue.
        self._executor.shutdown(wait=True, cancel_futures=False)
        for session in self._sessions.values():
            session.audio.clear()
            if session.final_path is not None:
                session.final_path.unlink(missing_ok=True)
        self._sessions.clear()

    def serve(self, source: BinaryIO) -> int:
        try:
            for raw in source:
                request_id: str | None = None
                try:
                    request = parse_request(raw.rstrip(b"\r\n"))
                    request_id = request.request_id
                    result = self._dispatch(request)
                    if result is not None:
                        self._write(envelope(id=request.request_id, result=result))
                except ProtocolError as exc:
                    self._write(
                        envelope(
                            id=request_id,
                            error={"stage": "stt", "code": exc.code, "message": exc.safe_message},
                        )
                    )
                except Exception:
                    self._write(
                        envelope(
                            id=request_id,
                            error={
                                "stage": "stt",
                                "code": "stt_internal_failure",
                                "message": "The local STT sidecar failed.",
                            },
                        )
                    )
                    self._error_output.write("stt_internal_failure\n")
                    self._error_output.flush()
            return 0
        finally:
            self.close()

    def _dispatch(self, request: Request) -> dict[str, Any] | None:
        method = request.method
        if method == "health":
            return {
                "status": "ready" if self._backend_ready else "cold",
                "component_version": __version__,
                "backend": self._backend.name,
                "model": self._backend.model,
            }
        if method == "capabilities":
            return {
                "audio_format": "pcm_s16le",
                "sample_rates": [16000, 24000, 48000],
                "channels": [1],
                "provisional": True,
                "final": True,
                "max_audio_seconds": self._max_audio_seconds,
            }
        if method == "warmup":
            started = time.monotonic()
            try:
                self._backend.warmup()
                self._backend_ready = True
            except Exception as exc:
                raise ProtocolError("stt_warmup_failed", "The local STT model could not warm up.") from exc
            return {"status": "warm", "duration_ms": _duration_ms(started)}
        if method == "start":
            return self._start(request.params)
        if method == "push":
            return self._push(request.params)
        if method == "end":
            self._end(request)
            return None
        if method == "cancel":
            return self._cancel(request.params)
        raise ProtocolError("protocol_method_unsupported", "The STT method is unsupported.")

    def _start(self, params: dict[str, Any]) -> dict[str, Any]:
        session_id = require_opaque(params, "session_id")
        sample_rate = params.get("sample_rate")
        channels = params.get("channels")
        language = params.get("language")
        if sample_rate not in {16000, 24000, 48000} or channels != 1:
            raise ProtocolError("stt_audio_format_unsupported", "The STT audio format is unsupported.")
        if language is not None and (not isinstance(language, str) or len(language) > 16):
            raise ProtocolError("stt_language_invalid", "The STT language is invalid.")
        if session_id in self._sessions:
            raise ProtocolError("stt_session_conflict", "The STT session identity is already in use.")
        self._sessions[session_id] = _Session(
            session_id=session_id,
            sample_rate=sample_rate,
            channels=channels,
            language=language or None,
        )
        return {"session_id": session_id, "status": "recording"}

    def _push(self, params: dict[str, Any]) -> dict[str, Any]:
        session = self._require_session(params)
        if session.final_request_id is not None:
            raise ProtocolError("stt_session_finalizing", "The STT session is already finalizing.")
        sequence = params.get("sequence")
        if sequence != session.next_sequence:
            raise ProtocolError("stt_audio_sequence_invalid", "The STT audio sequence is invalid.")
        chunk = decode_chunk(params)
        maximum = session.sample_rate * session.channels * 2 * self._max_audio_seconds
        if len(session.audio) + len(chunk) > maximum:
            raise ProtocolError("stt_audio_too_long", "The STT recording is too long.")
        session.audio.extend(chunk)
        session.next_sequence += 1
        self._maybe_schedule_provisional(session)
        return {"session_id": session.session_id, "accepted_sequence": sequence}

    def _end(self, request: Request) -> None:
        session = self._require_session(request.params)
        if session.final_request_id is not None:
            raise ProtocolError("stt_session_finalizing", "The STT session is already finalizing.")
        voice_rms = _audio_rms(session.audio)
        if voice_rms is None or voice_rms < 32.0:
            # This is bounded diagnostic metadata only: never log PCM bytes,
            # speech text, credentials, or the temporary audio path.
            self._error_output.write(
                f"stt_audio_stats bytes={len(session.audio)} "
                f"rms={voice_rms if voice_rms is not None else 0.0:.2f} "
                "threshold=32.00\n"
            )
            self._error_output.flush()
            self._sessions.pop(session.session_id)
            session.audio.clear()
            raise ProtocolError("stt_no_audio", "No speech was detected in the recording.")

        session.generation += 1
        generation = session.generation
        if session.provisional_future is not None:
            session.provisional_future.cancel()
        try:
            path = self._create_wav(session, bytes(session.audio))
        except Exception:
            self._sessions.pop(session.session_id, None)
            session.audio.clear()
            raise
        session.final_request_id = request.request_id
        session.final_path = path
        session.final_started_at = time.monotonic()
        session.final_audio_duration_ms = _audio_duration_ms(session)
        session.audio.clear()
        try:
            future = self._executor.submit(self._transcribe_path, path, session.language)
        except Exception:
            self._sessions.pop(session.session_id, None)
            path.unlink(missing_ok=True)
            raise
        session.final_future = future

        def completed(result: Future[Transcript]) -> None:
            try:
                path.unlink(missing_ok=True)
            except OSError:
                self._error_output.write("stt_temp_cleanup_failed\n")
                self._error_output.flush()
            if generation != session.generation or self._sessions.get(session.session_id) is not session:
                return
            self._sessions.pop(session.session_id, None)
            try:
                transcript = result.result()
                if not transcript.text:
                    raise ProtocolError("stt_empty_transcript", "The STT service returned no transcript.")
            except ProtocolError as exc:
                self._write(
                    envelope(
                        id=request.request_id,
                        error={"stage": "stt", "code": exc.code, "message": exc.safe_message},
                    )
                )
                return
            except Exception:
                self._write(
                    envelope(
                        id=request.request_id,
                        error={
                            "stage": "stt",
                            "code": "stt_final_failed",
                            "message": "The local STT final transcription failed.",
                        },
                    )
                )
                self._error_output.write("stt_final_failed\n")
                self._error_output.flush()
                return
            self._write(
                envelope(
                    id=request.request_id,
                    result={
                        "session_id": session.session_id,
                        "text": transcript.text,
                        "language": transcript.language,
                        "confidence": transcript.confidence,
                        "duration_ms": _duration_ms(session.final_started_at or time.monotonic()),
                        "audio_duration_ms": session.final_audio_duration_ms,
                    },
                )
            )

        future.add_done_callback(completed)

    def _cancel(self, params: dict[str, Any]) -> dict[str, Any]:
        session = self._require_session(params)
        self._sessions.pop(session.session_id)
        session.generation += 1
        session.audio.clear()
        future = session.provisional_future
        if future is not None:
            future.cancel()
        final_future = session.final_future
        if final_future is not None:
            final_future.cancel()
        if session.final_path is not None:
            try:
                session.final_path.unlink(missing_ok=True)
            except OSError:
                self._error_output.write("stt_temp_cleanup_failed\n")
                self._error_output.flush()
        if session.final_request_id is not None:
            self._write(
                envelope(
                    id=session.final_request_id,
                    error={
                        "stage": "stt",
                        "code": "stt_cancelled",
                        "message": "The local STT transcription was cancelled.",
                    },
                )
            )
        return {"session_id": session.session_id, "status": "cancelled"}

    def _require_session(self, params: dict[str, Any]) -> _Session:
        session_id = require_opaque(params, "session_id")
        session = self._sessions.get(session_id)
        if session is None:
            raise ProtocolError("stt_session_unknown", "The STT session is unknown.")
        return session

    def _maybe_schedule_provisional(self, session: _Session) -> None:
        threshold = int(session.sample_rate * 2 * self._provisional_seconds)
        if len(session.audio) - session.last_provisional_bytes < threshold:
            return
        if session.provisional_future is not None and not session.provisional_future.done():
            return
        snapshot = bytes(session.audio)
        generation = session.generation
        session.last_provisional_bytes = len(snapshot)
        future = self._executor.submit(self._transcribe, session, snapshot)
        session.provisional_future = future

        def completed(result: Future[Transcript]) -> None:
            if generation != session.generation or self._sessions.get(session.session_id) is not session:
                return
            try:
                transcript = result.result()
            except Exception:
                self._emit_event(session, "transcript.provisional_failed", safe_code="stt_provisional_failed")
                return
            if transcript.text:
                self._emit_event(session, "transcript.provisional", text=transcript.text)

        future.add_done_callback(completed)

    def _emit_event(self, session: _Session, event: str, **payload: Any) -> None:
        session.event_sequence += 1
        self._write(
            envelope(
                event=event,
                session_id=session.session_id,
                sequence=session.event_sequence,
                **payload,
            )
        )

    def _transcribe(self, session: _Session, audio: bytes) -> Transcript:
        path = self._create_wav(session, audio)
        try:
            return self._transcribe_path(path, session.language)
        finally:
            path.unlink(missing_ok=True)

    def _create_wav(self, session: _Session, audio: bytes) -> Path:
        self._temp_root.mkdir(mode=0o700, parents=True, exist_ok=True)
        descriptor, path_text = tempfile.mkstemp(
            prefix="voxhandoff-stt-",
            suffix=".wav",
            dir=self._temp_root,
        )
        path = Path(path_text)
        try:
            os.chmod(path, 0o600)
            with os.fdopen(descriptor, "wb") as raw:
                descriptor = -1
                with wave.open(raw, "wb") as writer:
                    writer.setnchannels(session.channels)
                    writer.setsampwidth(2)
                    writer.setframerate(session.sample_rate)
                    writer.writeframes(audio)
            return path
        except Exception:
            if descriptor >= 0:
                os.close(descriptor)
            path.unlink(missing_ok=True)
            raise

    def _transcribe_path(self, path: Path, language: str | None) -> Transcript:
        return self._backend.transcribe(path, language=language)

    def _cleanup_stale_audio(self) -> None:
        self._temp_root.mkdir(mode=0o700, parents=True, exist_ok=True)
        for path in self._temp_root.glob("voxhandoff-stt-*.wav"):
            try:
                path.unlink()
            except OSError:
                self._error_output.write("stt_temp_cleanup_failed\n")
                self._error_output.flush()

    def _write(self, value: dict[str, Any]) -> None:
        encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
        with self._write_lock:
            self._output.write(encoded + "\n")
            self._output.flush()


def _duration_ms(started: float) -> int:
    return max(0, round((time.monotonic() - started) * 1000))


def _audio_duration_ms(session: _Session) -> int:
    frames = len(session.audio) // (2 * session.channels)
    return round(frames * 1000 / session.sample_rate)


def _audio_rms(audio: bytearray) -> float | None:
    if len(audio) < 3200 or len(audio) % 2:
        return None
    sample_count = len(audio) // 2
    stride = max(1, sample_count // 16000)
    squares = 0.0
    inspected = 0
    view = memoryview(audio)
    for offset in range(0, len(audio) - 1, 2 * stride):
        sample = int.from_bytes(view[offset : offset + 2], "little", signed=True)
        squares += float(sample * sample)
        inspected += 1
    return math.sqrt(squares / max(inspected, 1))


def _contains_voice(audio: bytearray) -> bool:
    rms = _audio_rms(audio)
    return rms is not None and rms >= 32.0
