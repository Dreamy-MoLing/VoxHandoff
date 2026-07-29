# Hermes MVP Fedora 44 HomeScreen frame probe

The Linux x64 release build passed the recorded 60 Hz HomeScreen profile on
the named Fedora workstation. The probe rendered the real `HomeScreen` with
2,000 durable events, then measured 120 frames while Agent deltas, recording
levels, TTS levels, and SignalCore were updating together. Stress total frame
time was 8,687 microseconds at P50 and 12,759 microseconds at P95, below the
16,667 microsecond frame budget. One stress frame exceeded the budget.

The following 60-frame idle phase measured a 6,056 microsecond total P50 and
12,964 microsecond total P95. Two idle samples exceeded the budget. RSS peaked
at 174,137,344 bytes and ended 2,203,648 bytes below its first measured value.
The summary gate is deliberately based on each phase's P95, while retaining
every over-budget sample in the evidence.

This benchmark uses a driver ticker to request the 60 measured idle frames.
The separate widget test proves that an actual idle SignalCore does not
schedule continuous frames. This result is scoped to the recorded 60.001 Hz
Intel Iris Xe Wayland environment; it does not prove a 120 Hz mobile profile.

Reproduce with the Linux release bundle:

```bash
VOXHANDOFF_MVP_RENDER_BENCHMARK=1 \
  ./apps/client/build/linux/x64/release/bundle/agent_talk_client \
  > artifacts/benchmarks/mvp-fedora44-20260729/measurements.jsonl
npm run benchmark:mvp:summary -- \
  artifacts/benchmarks/mvp-fedora44-20260729/measurements.jsonl
```
