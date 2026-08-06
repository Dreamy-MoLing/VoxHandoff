import assert from "node:assert/strict";
import test from "node:test";
import {
  summarizeM4FrameBenchmark,
} from "./summarize-m4-frame-benchmark.mjs";

function completedRecords(sampleCount) {
  const records = [
    {
      benchmark: "m4_signal_core",
      status: "completed",
      warmup_frames: 5,
      measured_frames: sampleCount,
      refresh_rate_hz: 60,
      profile: "balanced60",
    },
  ];
  for (let index = 0; index < sampleCount; index += 1) {
    records.push({
      sample: index + 1,
      state: "idle",
      build_us: 400,
      raster_us: 1200,
      total_us: 2400,
    });
  }
  return records;
}

test("summarizes Android Flutter-prefixed benchmark output", () => {
  const lines = completedRecords(55).map(
    (record) => `I/flutter (1234): ${JSON.stringify(record)}`,
  );
  const summary = summarizeM4FrameBenchmark(`${lines.join("\n")}\n`);
  assert.equal(summary.status, "passed");
  assert.equal(summary.measured_frames, 55);
  assert.equal(summary.profile, "balanced60");
});

test("rejects an incomplete prefixed benchmark", () => {
  const lines = completedRecords(49).map(
    (record) => `flutter: ${JSON.stringify(record)}`,
  );
  assert.throws(
    () => summarizeM4FrameBenchmark(`${lines.join("\n")}\n`),
    /at least 50 samples/u,
  );
});
