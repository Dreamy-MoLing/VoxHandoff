from __future__ import annotations

import base64
import binascii
import json
import re
from dataclasses import dataclass
from typing import Any


PROTOCOL_MAJOR = 1
PROTOCOL_MINOR = 0
MAX_LINE_BYTES = 1_048_576
MAX_CHUNK_BYTES = 262_144
_OPAQUE = re.compile(r"^[^\x00-\x20\x7f]{1,256}$")


class ProtocolError(Exception):
    def __init__(self, code: str, safe_message: str) -> None:
        super().__init__(safe_message)
        self.code = code
        self.safe_message = safe_message


@dataclass(frozen=True)
class Request:
    request_id: str
    method: str
    params: dict[str, Any]


def parse_request(line: bytes) -> Request:
    if len(line) > MAX_LINE_BYTES:
        raise ProtocolError("protocol_frame_too_large", "The STT protocol frame is too large.")
    try:
        value = json.loads(line)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProtocolError("protocol_json_invalid", "The STT protocol frame is invalid.") from exc
    if not isinstance(value, dict):
        raise ProtocolError("protocol_frame_invalid", "The STT protocol frame is invalid.")
    protocol = value.get("protocol")
    if protocol != {"major": PROTOCOL_MAJOR, "minor": PROTOCOL_MINOR}:
        raise ProtocolError("protocol_version_unsupported", "The STT protocol version is unsupported.")
    request_id = value.get("id")
    method = value.get("method")
    params = value.get("params", {})
    if not isinstance(request_id, str) or not _OPAQUE.fullmatch(request_id):
        raise ProtocolError("protocol_request_id_invalid", "The STT request identity is invalid.")
    if not isinstance(method, str) or not _OPAQUE.fullmatch(method):
        raise ProtocolError("protocol_method_invalid", "The STT method is invalid.")
    if not isinstance(params, dict):
        raise ProtocolError("protocol_params_invalid", "The STT request parameters are invalid.")
    return Request(request_id=request_id, method=method, params=params)


def require_opaque(params: dict[str, Any], name: str) -> str:
    value = params.get(name)
    if not isinstance(value, str) or not _OPAQUE.fullmatch(value):
        raise ProtocolError(f"{name}_invalid", f"The STT {name.replace('_', ' ')} is invalid.")
    return value


def decode_chunk(params: dict[str, Any]) -> bytes:
    encoded = params.get("audio_base64")
    if not isinstance(encoded, str) or len(encoded) > MAX_CHUNK_BYTES * 2:
        raise ProtocolError("stt_audio_chunk_invalid", "The STT audio chunk is invalid.")
    try:
        chunk = base64.b64decode(encoded, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise ProtocolError("stt_audio_chunk_invalid", "The STT audio chunk is invalid.") from exc
    if not chunk or len(chunk) > MAX_CHUNK_BYTES or len(chunk) % 2 != 0:
        raise ProtocolError("stt_audio_chunk_invalid", "The STT audio chunk is invalid.")
    return chunk


def envelope(**values: Any) -> dict[str, Any]:
    return {"protocol": {"major": PROTOCOL_MAJOR, "minor": PROTOCOL_MINOR}, **values}
