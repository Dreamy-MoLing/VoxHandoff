# M3 voice benchmark conclusion

Date: 2026-07-22

Profile: Fedora 44, Linux 7.1.4, Intel i5-1155G7 (4C/8T), 15 GiB RAM,
CPU inference

STT: faster-whisper 1.2.1, local `faster-whisper-base`, int8

TTS: local GPT-SoVITS HTTP service through the existing serialized wrapper

The corpus and runner are committed under `benchmarks/`. Five warmups were
excluded. `measurements.jsonl` contains exactly 110 redacted rows: 30 STT, 30
TTS, and 50 end-to-end STT → deterministic reply → TTS measurements. Synthetic
audio and temporary text were deleted at process exit.

## Result

- STT latency among non-empty finals passed the recommended hot budget:
  P50 500.04 ms, P95 1953.18 ms. Three of 30 GPT-SoVITS-generated requests
  still produced an empty base-model final, so this model/profile is rejected
  for default voice enablement. Mean character error rate was 0.678; this
  synthetic TTS corpus is not a substitute for the required human-microphone
  device corpus.
- TTS returned bounded WAV for 30/30 cases, but CPU synthesis missed the hot
  budget: P50 3723.92 ms, P95 5428.33 ms. N+1 prefetch can hide later segment
  latency, not first-segment latency.
- The 50-run external-service loop succeeded 44/50 (88%), below the 95% target;
  every failure remained in the denominator and came from an empty STT final.
- The checked client behavior therefore classifies this machine/model as
  `text-first degraded`: full text remains usable, automatic speech is off by
  default, and no failed transcript can become an Agent request. It must not be
  presented as a recommended voice-performance profile.

## Decision

M3's implementation and failure-domain gate are accepted, while this specific
CPU/base-model capability is rejected. The recommended latency targets remain
unchanged. Before a release profile enables automatic voice, it must rerun this
same gate with a stronger Chinese model and accelerated GPT-SoVITS, achieve at
least 95% on the 50-run denominator, and add 10 cold-start samples plus a named
human microphone/device corpus. An attempted unauthenticated download of the
official faster-whisper small model made no material progress and was cancelled;
no untested improvement is claimed.
