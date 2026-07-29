import assert from "node:assert/strict";
import test from "node:test";

import {
  summarizeMvpHomeBenchmark,
} from "./summarize-mvp-home-benchmark.mjs";

function completedRecords({
  stressFrames = 120,
  idleFrames = 60,
  totalUs = 4_000,
} = {}) {
  const records = [{
    benchmark: "mvp_home_screen",
    status: "completed",
    warmup_frames: 10,
    stress_frames: stressFrames,
    idle_frames: idleFrames,
    history_events: 2_000,
    refresh_rate_hz: 60,
    profile: "balanced60",
  }];
  for (let index = 0; index < stressFrames + idleFrames; index += 1) {
    records.push({
      sample: index + 1,
      phase: index < stressFrames ? "stress" : "idle",
      build_us: 600,
      raster_us: 1_200,
      total_us: totalUs,
      rss_bytes: 100_000_000 + index,
    });
  }
  return records;
}

test("summarizes the actual HomeScreen stress and idle phases", () => {
  const content = completedRecords()
    .map((record) => `flutter: ${JSON.stringify(record)}`)
    .join("\n");
  const summary = summarizeMvpHomeBenchmark(content);

  assert.equal(summary.status, "passed");
  assert.equal(summary.history_events, 2_000);
  assert.equal(summary.stress.frames, 120);
  assert.equal(summary.idle.frames, 60);
  assert.equal(summary.stress.total_p95_us, 4_000);
  assert.equal(summary.rss_growth_bytes, 179);
});

test("fails a profile whose stress P95 exceeds the frame budget", () => {
  const content = completedRecords({ totalUs: 20_000 })
    .map(JSON.stringify)
    .join("\n");
  assert.equal(summarizeMvpHomeBenchmark(content).status, "failed");
});

test("rejects incomplete phase output", () => {
  const records = completedRecords();
  records.pop();
  assert.throws(
    () => summarizeMvpHomeBenchmark(records.map(JSON.stringify).join("\n")),
    /every stress\/idle sample/u,
  );
});
