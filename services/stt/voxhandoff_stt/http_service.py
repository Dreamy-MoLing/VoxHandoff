from __future__ import annotations

import argparse
import base64
import binascii
import hmac
import io
import json
import os
import signal
import ssl
import sys
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, BinaryIO, TextIO

from .backend import FasterWhisperBackend, SttBackend
from .service import SttService


MAX_REQUEST_BYTES = 8 * 1024 * 1024
MAX_AUDIO_SECONDS = 120
MAX_LANGUAGE_LENGTH = 16
_OPAQUE_ID_MAX_LENGTH = 256


class HttpSttError(Exception):
    def __init__(self, code: str, message: str, status: int = HTTPStatus.BAD_REQUEST) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.status = status


class HttpSttProvider:
    """Small HTTPS-facing adapter over the existing versioned STT service."""

    def __init__(self, backend: SttBackend, *, temp_root: Path) -> None:
        self._backend = backend
        self._temp_root = temp_root
        self._ready = False

    @property
    def ready(self) -> bool:
        return self._ready

    def warmup(self) -> None:
        self._backend.warmup()
        self._ready = True

    def health(self) -> dict[str, str]:
        if not self._ready:
            raise HttpSttError(
                "stt_not_ready",
                "The STT provider is not ready.",
                HTTPStatus.SERVICE_UNAVAILABLE,
            )
        return {
            "status": "ready",
            "component_version": "1.0",
            "backend": self._backend.name,
            "model": "faster-whisper-base",
        }

    def transcribe(self, value: dict[str, Any]) -> dict[str, Any]:
        params = validate_transcribe_payload(value)
        request_id = f"http-{uuid.uuid4().hex}"
        session_id = params["session_id"]
        audio = params["audio"]
        protocol_params = {
            "session_id": session_id,
            "sample_rate": params["sample_rate"],
            "channels": params["channels"],
        }
        if params["language"] is not None:
            protocol_params["language"] = params["language"]
        frames = [_request_frame("start", "start", protocol_params)]
        # The stdio protocol bounds a single audio chunk (MAX_CHUNK_BYTES in
        # protocol.py). Split the request body into successive push frames so
        # recordings longer than ~8 seconds still reach the backend. Never log
        # PCM bytes; only chunk sizes are diagnostic metadata.
        chunk_size = 262_144
        sequence = 0
        for offset in range(0, len(audio), chunk_size):
            sequence += 1
            frames.append(
                _request_frame(
                    "push",
                    "push",
                    {
                        "session_id": session_id,
                        "sequence": sequence,
                        "audio_base64": base64.b64encode(
                            audio[offset : offset + chunk_size]
                        ).decode("ascii"),
                    },
                )
            )
        frames.append(_request_frame(request_id, "end", {"session_id": session_id}))
        payload = b"".join(frames)
        output = io.StringIO()
        errors = io.StringIO()
        service = SttService(
            self._backend,
            output=output,
            error_output=errors,
            temp_root=self._temp_root,
            max_audio_seconds=MAX_AUDIO_SECONDS,
            provisional_seconds=MAX_AUDIO_SECONDS,
        )
        service.serve(io.BytesIO(payload))
        diagnostics = errors.getvalue()
        if diagnostics:
            # The sidecar keeps diagnostics in memory for this bounded HTTP
            # request. Forward only its already-redacted metadata; never log
            # the request body, PCM, credentials, or transcript.
            sys.stderr.write(diagnostics)
            sys.stderr.flush()
        replies = _decode_replies(output)
        reply = next((item for item in replies if item.get("id") == request_id), None)
        if reply is None:
            raise HttpSttError(
                "stt_no_response",
                "The STT provider did not return a transcription.",
                HTTPStatus.INTERNAL_SERVER_ERROR,
            )
        error = reply.get("error")
        if isinstance(error, dict):
            code = error.get("code")
            message = error.get("message")
            raise HttpSttError(
                code if isinstance(code, str) else "stt_failed",
                message if isinstance(message, str) else "The STT transcription failed.",
                HTTPStatus.UNPROCESSABLE_ENTITY,
            )
        result = reply.get("result")
        if not isinstance(result, dict) or not isinstance(result.get("text"), str):
            raise HttpSttError(
                "stt_response_invalid",
                "The STT provider returned an invalid transcription.",
                HTTPStatus.INTERNAL_SERVER_ERROR,
            )
        return {
            "text": result["text"],
            "language": result.get("language"),
            "confidence": result.get("confidence"),
        }


class _SttHttpHandler(BaseHTTPRequestHandler):
    server: _SttHttpServer
    protocol_version = "HTTP/1.1"
    server_version = "VoxHandoffSTT"
    sys_version = ""

    def do_GET(self) -> None:  # noqa: N802
        if self.path != "/v1/health":
            self._respond(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found"}})
            return
        try:
            payload = self.server.provider.health()
        except HttpSttError as error:
            self._respond(error.status, {"error": {"code": error.code, "message": error.message}})
            return
        self._respond(HTTPStatus.OK, payload)

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/v1/transcribe":
            self._respond(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found"}})
            return
        expected = f"Bearer {self.server.token}"
        received = self.headers.get("Authorization", "")
        if not hmac.compare_digest(received, expected):
            self.send_response(HTTPStatus.UNAUTHORIZED)
            self.send_header("WWW-Authenticate", "Bearer")
            self._finish_headers()
            self.wfile.write(b'{"error":{"code":"unauthorized"}}')
            return
        try:
            body = read_request_body(self.rfile, self.headers)
            value = json.loads(body)
            if not isinstance(value, dict):
                raise HttpSttError("request_invalid", "The STT request is invalid.")
            result = self.server.provider.transcribe(value)
        except HttpSttError as error:
            # Keep live diagnostics bounded to the stable error code. Never
            # log request bodies, provider tokens, or transcription text.
            self.server.error_output.write(
                f"stt_http_error code={error.code} status={error.status}\n"
            )
            self.server.error_output.flush()
            self._respond(error.status, {"error": {"code": error.code, "message": error.message}})
            return
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError):
            self._respond(
                HTTPStatus.BAD_REQUEST,
                {"error": {"code": "request_invalid", "message": "The STT request is invalid."}},
            )
            return
        except Exception:
            self.server.error_output.write("stt_http_internal_failure\n")
            self.server.error_output.flush()
            self._respond(
                HTTPStatus.INTERNAL_SERVER_ERROR,
                {
                    "error": {
                        "code": "stt_internal_failure",
                        "message": "The STT provider failed.",
                    }
                },
            )
            return
        self._respond(HTTPStatus.OK, result)

    def log_message(self, format: str, *args: object) -> None:
        self.server.error_output.write("stt_http " + (format % args) + "\n")
        self.server.error_output.flush()

    def _respond(self, status: int, payload: dict[str, Any]) -> None:
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.send_header("Cache-Control", "no-store")
        self._finish_headers()
        self.wfile.write(encoded)

    def _finish_headers(self) -> None:
        self.send_header("Connection", "close")
        self.end_headers()


class _SttHttpServer(ThreadingHTTPServer):
    def __init__(
        self,
        address: tuple[str, int],
        provider: HttpSttProvider,
        token: str,
        error_output: TextIO,
    ) -> None:
        super().__init__(address, _SttHttpHandler)
        self.provider = provider
        self.token = token
        self.error_output = error_output
        self.daemon_threads = True
        self.allow_reuse_address = False


def validate_transcribe_payload(value: dict[str, Any]) -> dict[str, Any]:
    if value.get("protocol") != {"major": 1, "minor": 0}:
        raise HttpSttError("protocol_version_unsupported", "The STT protocol version is unsupported.")
    session_id = value.get("session_id")
    if not isinstance(session_id, str) or not 0 < len(session_id) <= _OPAQUE_ID_MAX_LENGTH:
        raise HttpSttError("session_id_invalid", "The STT session identity is invalid.")
    if any(ord(character) <= 0x20 or ord(character) == 0x7F for character in session_id):
        raise HttpSttError("session_id_invalid", "The STT session identity is invalid.")
    if value.get("audio_format") != "pcm_s16le":
        raise HttpSttError("stt_audio_format_unsupported", "The STT audio format is unsupported.")
    sample_rate = value.get("sample_rate")
    channels = value.get("channels")
    if sample_rate not in {16000, 24000, 48000} or channels != 1:
        raise HttpSttError("stt_audio_format_unsupported", "The STT audio format is unsupported.")
    language = value.get("language")
    if language is not None and (not isinstance(language, str) or len(language) > MAX_LANGUAGE_LENGTH):
        raise HttpSttError("stt_language_invalid", "The STT language is invalid.")
    encoded = value.get("audio_base64")
    maximum_bytes = sample_rate * channels * 2 * MAX_AUDIO_SECONDS
    if not isinstance(encoded, str) or len(encoded) > maximum_bytes * 2:
        raise HttpSttError("stt_audio_chunk_invalid", "The STT audio is invalid.")
    try:
        audio = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as error:
        raise HttpSttError("stt_audio_chunk_invalid", "The STT audio is invalid.") from error
    if not audio or len(audio) > maximum_bytes or len(audio) % 2:
        raise HttpSttError("stt_audio_chunk_invalid", "The STT audio is invalid.")
    return {
        "session_id": session_id,
        "sample_rate": sample_rate,
        "channels": channels,
        "language": language,
        "audio": audio,
    }


def read_request_body(source: BinaryIO, headers: Any) -> bytes:
    content_length = headers.get("Content-Length")
    if content_length is not None:
        try:
            length = int(content_length)
        except ValueError as error:
            raise HttpSttError("request_length_invalid", "The STT request length is invalid.") from error
        if length < 0 or length > MAX_REQUEST_BYTES:
            raise HttpSttError("request_too_large", "The STT request is too large.", HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
        body = source.read(length)
        if len(body) != length:
            raise HttpSttError("request_incomplete", "The STT request is incomplete.")
        return body
    transfer_encoding = headers.get("Transfer-Encoding", "").lower()
    if transfer_encoding != "chunked":
        raise HttpSttError("request_length_required", "The STT request length is required.", HTTPStatus.LENGTH_REQUIRED)
    body = bytearray()
    while True:
        line = source.readline(128)
        if not line or not line.endswith(b"\r\n"):
            raise HttpSttError("request_incomplete", "The STT request is incomplete.")
        try:
            size = int(line[:-2].split(b";", 1)[0], 16)
        except ValueError as error:
            raise HttpSttError("request_chunk_invalid", "The STT request is invalid.") from error
        if size == 0:
            while source.readline(128) not in {b"\r\n", b""}:
                pass
            return bytes(body)
        if size < 0 or len(body) + size > MAX_REQUEST_BYTES:
            raise HttpSttError("request_too_large", "The STT request is too large.", HTTPStatus.REQUEST_ENTITY_TOO_LARGE)
        chunk = source.read(size)
        if len(chunk) != size or source.read(2) != b"\r\n":
            raise HttpSttError("request_incomplete", "The STT request is incomplete.")
        body.extend(chunk)


def _request_frame(request_id: str, method: str, params: dict[str, Any]) -> bytes:
    return (
        json.dumps(
            {
                "protocol": {"major": 1, "minor": 0},
                "id": request_id,
                "method": method,
                "params": params,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        + b"\n"
    )


def _decode_replies(output: TextIO) -> list[dict[str, Any]]:
    replies: list[dict[str, Any]] = []
    for line in output.getvalue().splitlines():
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            replies.append(value)
    return replies


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="VoxHandoff HTTPS STT provider")
    parser.add_argument("--model", default=os.environ.get("VOXHANDOFF_STT_MODEL_PATH", ""))
    parser.add_argument("--device", default=os.environ.get("VOXHANDOFF_STT_DEVICE", "cpu"))
    parser.add_argument("--compute-type", default=os.environ.get("VOXHANDOFF_STT_COMPUTE_TYPE", "int8"))
    parser.add_argument("--bind", default=os.environ.get("VOXHANDOFF_STT_HTTP_BIND", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("VOXHANDOFF_STT_HTTP_PORT", "18654")))
    parser.add_argument("--tls-cert", required=True)
    parser.add_argument("--tls-key", required=True)
    parser.add_argument("--token-env", default="VOXHANDOFF_STT_HTTP_TOKEN")
    parser.add_argument(
        "--temp-root",
        type=Path,
        default=Path(os.environ.get("VOXHANDOFF_STT_TEMP_ROOT", ""))
        if os.environ.get("VOXHANDOFF_STT_TEMP_ROOT")
        else Path.home() / ".cache" / "voxhandoff" / "stt",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    model_path = Path(args.model).expanduser()
    if not model_path.is_absolute() or not model_path.is_dir():
        print("VoxHandoff STT requires an existing local model directory.", file=sys.stderr)
        return 2
    token = os.environ.get(args.token_env, "")
    if len(token) < 16 or len(token) > 512 or any(character.isspace() for character in token):
        print("VoxHandoff HTTPS STT requires a valid token environment variable.", file=sys.stderr)
        return 2
    if not 1 <= args.port <= 65535:
        print("VoxHandoff HTTPS STT requires a valid port.", file=sys.stderr)
        return 2
    backend = FasterWhisperBackend(
        str(model_path.resolve()),
        device=args.device,
        compute_type=args.compute_type,
    )
    provider = HttpSttProvider(backend, temp_root=args.temp_root)
    try:
        provider.warmup()
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(certfile=args.tls_cert, keyfile=args.tls_key)
        server = _SttHttpServer((args.bind, args.port), provider, token, sys.stderr)
        server.socket = context.wrap_socket(server.socket, server_side=True)
    except Exception:
        print("VoxHandoff HTTPS STT failed to start.", file=sys.stderr)
        return 2

    def stop(_signum: int, _frame: Any) -> None:
        server.shutdown()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    print(f"voxhandoff-stt-https listening on {args.bind}:{args.port}", file=sys.stderr)
    try:
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
