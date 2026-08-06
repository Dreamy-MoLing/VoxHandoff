from __future__ import annotations

import argparse
import json
import statistics
import subprocess
import tempfile
import time
from pathlib import Path

from voxhandoff_stt.backend import FasterWhisperBackend


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description="Run the redacted VoxHandoff M3 voice gate")
    value.add_argument("--corpus", type=Path, required=True)
    value.add_argument("--gsv-wrapper", type=Path, required=True)
    value.add_argument("--model", type=Path, required=True)
    value.add_argument("--output", type=Path, required=True)
    value.add_argument("--summarize-existing", action="store_true")
    return value


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, round((len(ordered) - 1) * fraction)))
    return round(ordered[index], 2)


def edit_distance(left: str, right: str) -> int:
    previous = list(range(len(right) + 1))
    for row, left_character in enumerate(left, 1):
        current = [row]
        for column, right_character in enumerate(right, 1):
            current.append(
                min(
                    current[-1] + 1,
                    previous[column] + 1,
                    previous[column - 1] + (left_character != right_character),
                )
            )
        previous = current
    return previous[-1]


def normalized(text: str) -> str:
    return "".join(character.lower() for character in text if character.isalnum())


def synthesize(wrapper: Path, text: str, root: Path, name: str) -> tuple[Path, float]:
    input_path = root / f"{name}.txt"
    output_path = root / f"{name}.wav"
    input_path.write_text(text, encoding="utf-8")
    started = time.monotonic()
    subprocess.run(
        [str(wrapper), "--input-path", str(input_path), "--output-path", str(output_path)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=240,
    )
    return output_path, (time.monotonic() - started) * 1000


def transcribe(backend: FasterWhisperBackend, audio: Path) -> tuple[str, float]:
    started = time.monotonic()
    result = backend.transcribe(audio, language="zh")
    return result.text, (time.monotonic() - started) * 1000


def write_summary(rows: list[dict[str, object]], args: argparse.Namespace, path: Path) -> None:
    summary: dict[str, object] = {
        "schema": "voxhandoff.m3.voice-benchmark.v1",
        "warmups_excluded": 5,
        "environment": {
            "stt_backend": "faster-whisper",
            "stt_model": args.model.name,
            "tts_backend": "GPT-SoVITS through explicit local wrapper",
            "audio_source": "synthetic GPT-SoVITS corpus; not a human microphone corpus",
        },
    }
    for gate in ("stt-30", "tts-30", "e2e-50"):
        selected = [row for row in rows if row["gate"] == gate]
        successful = [row for row in selected if row["success"]]
        latency = [float(row["latency_ms"]) for row in successful]
        summary[gate] = {
            "total": len(selected),
            "successful": len(successful),
            "success_rate": round(len(successful) / len(selected), 4),
            "latency_p50_ms": percentile(latency, 0.50),
            "latency_p95_ms": percentile(latency, 0.95),
        }
        if gate == "stt-30":
            summary[gate]["mean_cer"] = round(
                statistics.mean(float(row["cer"]) for row in selected), 4
            )
    path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    args = parser().parse_args()
    corpus = json.loads(args.corpus.read_text(encoding="utf-8"))
    if len(corpus) != 30:
        raise ValueError("M3 corpus must contain exactly 30 cases")
    args.output.mkdir(parents=True, exist_ok=True)
    raw_path = args.output / "measurements.jsonl"
    summary_path = args.output / "summary.json"
    if args.summarize_existing:
        rows = [json.loads(line) for line in raw_path.read_text(encoding="utf-8").splitlines()]
        write_summary(rows, args, summary_path)
        print(summary_path)
        return 0
    backend = FasterWhisperBackend(str(args.model), device="cpu", compute_type="int8")
    rows: list[dict[str, object]] = []
    cached_audio: list[Path] = []

    def record(row: dict[str, object]) -> None:
        rows.append(row)
        with raw_path.open("a", encoding="utf-8") as output:
            output.write(json.dumps(row, ensure_ascii=False) + "\n")

    raw_path.write_text("", encoding="utf-8")
    with tempfile.TemporaryDirectory(prefix="voxhandoff-m3-bench-") as temporary:
        root = Path(temporary)
        for index in range(5):
            audio, _ = synthesize(
                args.gsv_wrapper, corpus[index]["text"], root, f"warm-{index}"
            )
            transcribe(backend, audio)

        for case in corpus:
            audio, tts_ms = synthesize(
                args.gsv_wrapper, case["text"], root, f"measured-{case['id']}"
            )
            cached_audio.append(audio)
            transcript, stt_ms = transcribe(backend, audio)
            expected = normalized(case["text"])
            actual = normalized(transcript)
            cer = edit_distance(expected, actual) / max(1, len(expected))
            for row in [
                    {
                        "gate": "tts-30",
                        "case_id": case["id"],
                        "success": True,
                        "latency_ms": round(tts_ms, 2),
                    },
                    {
                        "gate": "stt-30",
                        "case_id": case["id"],
                        "success": bool(actual),
                        "latency_ms": round(stt_ms, 2),
                        "cer": round(cer, 4),
                    },
                ]:
                record(row)

        for index in range(50):
            started = time.monotonic()
            success = True
            try:
                transcript, _ = transcribe(backend, cached_audio[index % len(cached_audio)])
                if not transcript:
                    raise RuntimeError("empty transcript")
                synthesize(
                    args.gsv_wrapper,
                    "处理完成，请查看完整文字结果。",
                    root,
                    f"e2e-{index:02d}",
                )
            except Exception:
                success = False
            record({
                    "gate": "e2e-50",
                    "case_id": f"e2e-{index + 1:02d}",
                    "success": success,
                    "latency_ms": round((time.monotonic() - started) * 1000, 2),
                })

    write_summary(rows, args, summary_path)
    print(summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
