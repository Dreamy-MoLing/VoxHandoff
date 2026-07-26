import { readFile } from "node:fs/promises";
import process from "node:process";

const [, , inputPath] = process.argv;
if (inputPath === undefined) {
  throw new Error("usage: node scripts/summarize-m4-frame-benchmark.mjs <raw.jsonl>");
}

const records = (await readFile(inputPath, "utf8"))
  .split(/\r?\n/u)
  .filter((line) => line.startsWith("{"))
  .map((line) => JSON.parse(line));
const metadata = records.find((record) => record.benchmark === "m4_signal_core");
const samples = records.filter((record) => Number.isInteger(record.sample));
if (
  metadata?.status !== "completed"
  || samples.length < 50
  || samples.length !== metadata.measured_frames
) {
  throw new Error("M4 frame benchmark must contain one completed header and at least 50 samples.");
}

const percentile = (values, ratio) => {
  const ordered = [...values].sort((left, right) => left - right);
  return ordered[Math.ceil(ordered.length * ratio) - 1];
};
const refreshRate = Number(metadata.refresh_rate_hz);
const frameBudgetUs = refreshRate >= 100 ? 8_333 : 16_667;
const build = samples.map((sample) => Number(sample.build_us));
const raster = samples.map((sample) => Number(sample.raster_us));
const total = samples.map((sample) => Number(sample.total_us));
const overBudget = total.filter((duration) => duration > frameBudgetUs).length;
const summary = {
  benchmark: "m4_signal_core",
  status: overBudget === 0 ? "passed" : "failed",
  measured_frames: samples.length,
  refresh_rate_hz: refreshRate,
  profile: metadata.profile,
  frame_budget_us: frameBudgetUs,
  build_p50_us: percentile(build, 0.5),
  build_p95_us: percentile(build, 0.95),
  raster_p50_us: percentile(raster, 0.5),
  raster_p95_us: percentile(raster, 0.95),
  total_p50_us: percentile(total, 0.5),
  total_p95_us: percentile(total, 0.95),
  over_budget_frames: overBudget,
};
process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
if (summary.status !== "passed") process.exitCode = 1;
