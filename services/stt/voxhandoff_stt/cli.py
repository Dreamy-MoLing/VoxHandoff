from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from .backend import FasterWhisperBackend
from .service import SttService


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="VoxHandoff local STT sidecar")
    parser.add_argument("--model", default=os.environ.get("VOXHANDOFF_STT_MODEL", "base"))
    parser.add_argument("--device", default=os.environ.get("VOXHANDOFF_STT_DEVICE", "cpu"))
    parser.add_argument(
        "--compute-type",
        default=os.environ.get("VOXHANDOFF_STT_COMPUTE_TYPE", "int8"),
    )
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
    backend = FasterWhisperBackend(
        args.model,
        device=args.device,
        compute_type=args.compute_type,
    )
    service = SttService(
        backend,
        output=sys.stdout,
        error_output=sys.stderr,
        temp_root=args.temp_root,
    )
    return service.serve(sys.stdin.buffer)

