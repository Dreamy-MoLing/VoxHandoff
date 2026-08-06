import { readFile } from "node:fs/promises";
import process from "node:process";
import { pathToFileURL } from "node:url";

import { parseBenchmarkRecord } from "./summarize-m4-frame-benchmark.mjs";

const percentile = (values, ratio) => {
  const ordered = [...values].sort((left, right) => left - right);
  return ordered[Math.ceil(ordered.length * ratio) - 1];
};

const finiteNumbers = (samples, field) => samples.map((sample) => {
  const value = Number(sample[field]);
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`MVP HomeScreen sample has invalid ${field}.`);
  }
  return value;
});

const phaseSummary = (samples, frameBudgetUs) => {
  const build = finiteNumbers(samples, "build_us");
  const raster = finiteNumbers(samples, "raster_us");
  const total = finiteNumbers(samples, "total_us");
  return {
    frames: samples.length,
    build_p50_us: percentile(build, 0.5),
    build_p95_us: percentile(build, 0.95),
    raster_p50_us: percentile(raster, 0.5),
    raster_p95_us: percentile(raster, 0.95),
    total_p50_us: percentile(total, 0.5),
    total_p95_us: percentile(total, 0.95),
    over_budget_frames: total.filter((value) => value > frameBudgetUs).length,
  };
};

export function summarizeMvpHomeBenchmark(content) {
  const records = content
    .split(/\r?\n/u)
    .map(parseBenchmarkRecord)
    .filter((record) => record !== undefined);
  const metadata = records.find(
    (record) => record.benchmark === "mvp_home_screen",
  );
  const samples = records.filter((record) => Number.isInteger(record.sample));
  const stressFrames = Number(metadata?.stress_frames);
  const idleFrames = Number(metadata?.idle_frames);
  if (
    metadata?.status !== "completed"
    || !Number.isInteger(stressFrames)
    || !Number.isInteger(idleFrames)
    || stressFrames < 60
    || idleFrames < 30
    || samples.length !== stressFrames + idleFrames
  ) {
    throw new Error(
      "MVP HomeScreen benchmark must contain one completed header and every stress/idle sample.",
    );
  }
  const stress = samples.filter((sample) => sample.phase === "stress");
  const idle = samples.filter((sample) => sample.phase === "idle");
  if (stress.length !== stressFrames || idle.length !== idleFrames) {
    throw new Error("MVP HomeScreen benchmark phase counts do not match its header.");
  }

  const refreshRate = Number(metadata.refresh_rate_hz);
  if (!Number.isFinite(refreshRate) || refreshRate <= 0) {
    throw new Error("MVP HomeScreen benchmark has an invalid refresh rate.");
  }
  const frameBudgetUs = refreshRate >= 100 ? 8_333 : 16_667;
  const stressSummary = phaseSummary(stress, frameBudgetUs);
  const idleSummary = phaseSummary(idle, frameBudgetUs);
  const rss = finiteNumbers(samples, "rss_bytes");
  const passed =
    stressSummary.total_p95_us <= frameBudgetUs
    && idleSummary.total_p95_us <= frameBudgetUs;

  return {
    benchmark: "mvp_home_screen",
    status: passed ? "passed" : "failed",
    history_events: Number(metadata.history_events),
    refresh_rate_hz: refreshRate,
    profile: metadata.profile,
    frame_budget_us: frameBudgetUs,
    stress: stressSummary,
    idle: idleSummary,
    rss_start_bytes: rss[0],
    rss_peak_bytes: Math.max(...rss),
    rss_growth_bytes: rss.at(-1) - rss[0],
  };
}

async function main() {
  const [, , inputPath] = process.argv;
  if (inputPath === undefined) {
    throw new Error(
      "usage: node scripts/summarize-mvp-home-benchmark.mjs <raw.jsonl>",
    );
  }
  const summary = summarizeMvpHomeBenchmark(await readFile(inputPath, "utf8"));
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  if (summary.status !== "passed") process.exitCode = 1;
}

if (
  process.argv[1] !== undefined
  && pathToFileURL(process.argv[1]).href === import.meta.url
) {
  await main();
}
