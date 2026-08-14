# VoxHandoff local STT sidecar

This service is the replaceable local speech-recognition boundary for the
Flutter desktop client. It accepts bounded JSONL requests on stdin and emits
only versioned JSONL responses/events on stdout. The default backend is
`faster-whisper 1.2.1` with a caller-selected local model.

Development setup (Python 3.11–3.13; the model must already exist locally):

```bash
cd services/stt
uv sync --locked --python 3.11
uv run python -m voxhandoff_stt --model /absolute/path/to/faster-whisper-model
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

The sidecar rejects a missing, relative, or non-directory model path before
loading faster-whisper; it never passes a model name to the engine, so a
production start cannot implicitly download from the network. Release builds
must package an application-owned `voxhandoff-stt` executable under the
desktop bundle's `libexec` directory. The Flutter launcher never searches
`PATH` or accepts a command from UI/remote input. Building signed installers
remains the M5 release gate; M3 verifies the sidecar protocol and the fixed-
path launcher boundary.

The Linux Flutter release install supports this explicitly with
`-DVOXHANDOFF_STT_EXECUTABLE=/absolute/path/to/voxhandoff-stt` and can enforce it
with `-DVOXHANDOFF_REQUIRE_STT_BUNDLE=ON`. The default development build does not
invent or download an executable; a release without that option remains a text-first
degraded build and must not be called the M5 voice release.

The dependency is locked in `uv.lock`. `faster-whisper` is MIT licensed and
kept behind `SttBackend`, so another local engine can replace it without
changing the client/domain protocol. Official reference:
[SYSTRAN/faster-whisper](https://github.com/SYSTRAN/faster-whisper).

## Linux release packaging

The desktop release ships one application-owned executable. The selected
packaging method is PyInstaller `--onefile`, with the build tool and its hooks
pinned in `packaging/requirements-build.txt`; the sidecar runtime remains
resolved by `uv.lock`. This keeps the Python runtime and native Python
dependencies out of the user's PATH while leaving
the speech model external and explicitly selected by `--model`.

PyInstaller is platform-native rather than a cross-compiler, so build each
Linux architecture on a matching Linux host. It also does not bundle glibc;
the release image must therefore use a compatible glibc baseline. The model is
intentionally not included in the executable because it is large, user data,
and must not be downloaded implicitly.

`zipapp` was rejected because it still requires a suitable target Python and
does not manage native dependencies by itself; `uv build` produces Python
distribution archives rather than the fixed executable expected by the Flutter
launcher. PyInstaller and its hook package are GPLv2-or-later with the
PyInstaller distribution exception and Apache/GPL dual licensing respectively;
`altgraph` is MIT. If PyInstaller becomes unsuitable for a target platform, the
sidecar's unchanged JSONL boundary permits replacing only this packaging layer
with a native build such as Nuitka or a platform-specific bundle.

References: [PyInstaller usage and platform notes](https://pyinstaller.org/en/stable/usage.html),
[Python `zipapp` documentation](https://docs.python.org/3/library/zipapp.html),
and the [Python packaging overview](https://packaging.python.org/overview/).

Build a Linux executable (Python 3.11 is the default; override
`PYTHON_VERSION` only with a version supported by this project):

```bash
cd services/stt
PYTHON_VERSION=3.11 ./scripts/build-linux.sh
# default artifact:
# services/stt/dist/linux-x86_64/voxhandoff-stt
```

Use `VOXHANDOFF_STT_OUTPUT_DIR=/absolute/path` to choose another output
directory. The command uses `uv run --locked --with-requirements`, so an
unexpected sidecar lockfile change fails the build instead of silently
resolving new runtime versions. The three packaging tool versions are exact
pins in the build requirements file.

Verify the packaged executable fails closed when the model is absent:

```bash
artifact=/absolute/path/to/voxhandoff-stt
set +e
"$artifact" --model /absolute/path/that-does-not-exist </dev/null
status=$?
set -e
test "$status" -eq 2
```

With an existing local model directory, verify the version 1.0 JSONL health
and capability frames:

```bash
printf '%s\n' \
  '{"protocol":{"major":1,"minor":0},"id":"health","method":"health","params":{}}' \
  '{"protocol":{"major":1,"minor":0},"id":"capabilities","method":"capabilities","params":{}}' \
  | "$artifact" --model /absolute/path/to/faster-whisper-model
```

The health frame must carry protocol `{ "major": 1, "minor": 0 }` and a
`cold`/`ready` status; the capabilities frame must carry the same protocol and
the PCM16LE, mono, 16/24/48 kHz contract. `health` and `capabilities` do not
load the model; run `warmup` separately when a real model is available.

For an Android live acceptance provider, the repository also includes a narrow
HTTPS adapter over the same backend and protocol. It binds to loopback by
default, warms the explicitly selected local model before listening, exposes
`GET /v1/health` and authenticated `POST /v1/transcribe`, and requires a
separate Bearer token from `VOXHANDOFF_STT_HTTP_TOKEN`. TLS certificates and
keys are supplied explicitly; the adapter does not download models or accept
an unauthenticated transcription request:

```bash
cd services/stt
VOXHANDOFF_STT_HTTP_TOKEN='独立的测试token' \
  uv run python -m voxhandoff_stt.http_service \
  --model /absolute/path/to/faster-whisper-model \
  --tls-cert /absolute/path/to/provider.crt \
  --tls-key /absolute/path/to/provider.key
```

The HTTPS adapter is intended to be placed behind a private Tailscale TCP
forwarder for device acceptance. The mobile client must still validate the
certificate chain and exact origin, and the user must accept the provider
disclosure before audio is uploaded.

The pinned Flutter 3.44.6 command does not expose arbitrary CMake `-D`
arguments. Configure the same release build directory with CMake once, then
run the normal Flutter build so its subsequent configure reuses the cache:

```bash
cd apps/client
flutter build linux --release --config-only
cmake -S linux -B build/linux/x64/release -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DVOXHANDOFF_STT_EXECUTABLE=/absolute/path/to/voxhandoff-stt \
  -DVOXHANDOFF_REQUIRE_STT_BUNDLE=ON
flutter build linux --release
test -x build/linux/x64/release/bundle/libexec/voxhandoff-stt
```

On a locked SDK checkout whose cache is writable, use the repository's normal
`AGENT_TALK_FLUTTER_ROOT` wrapper for both Flutter commands. The release
bundle path above is the only path the desktop launcher accepts; it never
searches `PATH`.
