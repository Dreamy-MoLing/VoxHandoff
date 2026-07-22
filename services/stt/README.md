# VoxHandoff local STT sidecar

This service is the replaceable local speech-recognition boundary for the
Flutter desktop client. It accepts bounded JSONL requests on stdin and emits
only versioned JSONL responses/events on stdout. The default backend is
`faster-whisper 1.2.1` with a caller-selected local model.

Development setup (Python 3.11–3.13):

```bash
cd services/stt
uv sync --locked --python 3.11
uv run python -m voxhandoff_stt --model base
```

Offline protocol tests do not load a model:

```bash
npm run test:stt
```

The protocol exposes `health`, `capabilities`, `warmup`, `start`, ordered
`push`, `end`, and `cancel`. Audio is mono signed 16-bit little-endian PCM at
16, 24, or 48 kHz. Frames, audio chunks, total duration, opaque identities,
and push sequence are bounded. Raw audio remains in memory while recording;
the WAV needed by faster-whisper is mode `0600`, removed in `finally`, and any
crash residue matching the private prefix is removed on the next startup.

Release builds must package an application-owned `voxhandoff-stt` executable
under the desktop bundle's `libexec` directory. The Flutter launcher never
searches `PATH` or accepts a command from UI/remote input. Building signed
installers remains the M5 release gate; M3 verifies the sidecar protocol and
the fixed-path launcher boundary.

The dependency is locked in `uv.lock`. `faster-whisper` is MIT licensed and
kept behind `SttBackend`, so another local engine can replace it without
changing the client/domain protocol. Official reference:
[SYSTRAN/faster-whisper](https://github.com/SYSTRAN/faster-whisper).
