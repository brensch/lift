import { test, mock } from "node:test";
import assert from "node:assert/strict";
import { generateDemoData } from "../src/lib/demo-data.ts";
import { resolveRange, workoutsInRange } from "../src/lib/range.ts";

test("the data's now is when it was made, so every workout is in All", () => {
  const nowMs = new Date(2026, 6, 1, 20).getTime();
  mock.timers.enable({ apis: ["Date"], now: nowMs });
  try {
    const data = generateDemoData();
    assert.equal(data.nowS, Math.floor(nowMs / 1000));
    const { startS, endS } = resolveRange({ preset: "all" }, data.nowS, data.sinceS);
    assert.equal(workoutsInRange(data, startS, endS).length, data.workouts.length);
  } finally {
    mock.timers.reset();
  }
});
