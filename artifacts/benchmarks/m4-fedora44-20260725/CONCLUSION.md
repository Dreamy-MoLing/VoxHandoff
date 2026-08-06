# M4 Fedora 44 signal-core frame probe

The Linux x64 release build passed the local 60 Hz rendering profile on the
named Fedora workstation. After five shader warmup frames, the probe measured
five frames for each of the 11 signal-core states. All 55 frames stayed within
the 16,667 microsecond frame budget; total frame time was 3,570 microseconds at
P50 and 7,287 microseconds at P95.

This evidence is intentionally scoped to the recorded 60.001 Hz Intel Iris Xe
Wayland environment and does not prove the optional 120 Hz profile.

The repository performance policy also requires a named Android reference
device before the M4 gate can close. On 2026-07-25 the development host had no
Android SDK, `adb`, or attached Android USB device. Therefore the implementation
and desktop profile pass, but the cross-device M4 performance gate remains
blocked on external Android hardware. CI builds must not be presented as a
substitute for this missing device result.

Reproduce the desktop probe with a Linux release bundle:

```bash
VOXHANDOFF_M4_RENDER_BENCHMARK=1 \
  ./apps/client/build/linux/x64/release/bundle/agent_talk_client \
  > artifacts/benchmarks/m4-fedora44-20260725/measurements.jsonl
npm run benchmark:m4:summary -- \
  artifacts/benchmarks/m4-fedora44-20260725/measurements.jsonl
```
