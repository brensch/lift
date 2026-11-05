import { test } from "node:test";
import assert from "node:assert/strict";
import {
  formatCompact,
  formatDate,
  formatDuration,
  formatMax,
  formatNumber,
  formatWeight,
  volumeComparison,
} from "../src/lib/format.ts";

test("formatNumber drops a trailing .0 and groups thousands", () => {
  assert.equal(formatNumber(225), "225");
  assert.equal(formatNumber(102.06), "102.1");
  assert.equal(formatNumber(1284.4, 0), "1,284");
});

test("formatWeight converts to kg", () => {
  assert.equal(formatWeight(225, "lb"), "225 lb");
  assert.equal(formatWeight(220.46226218, "kg"), "100 kg");
});

test("formatCompact switches to K at 10,000 and M at a million", () => {
  assert.equal(formatCompact(9_999), "9,999");
  assert.equal(formatCompact(10_000), "10K");
  assert.equal(formatCompact(12_940), "12.9K");
  assert.equal(formatCompact(999_999), "1,000K");
  assert.equal(formatCompact(1_000_000), "1M");
  assert.equal(formatCompact(4_240_000), "4.2M");
  assert.equal(formatCompact(-12_000), "-12K");
});

test("formatDuration rounds to minutes and shows hours past 60", () => {
  assert.equal(formatDuration(29), "0m");
  assert.equal(formatDuration(59 * 60 + 29), "59m");
  assert.equal(formatDuration(59 * 60 + 30), "1h");
  assert.equal(formatDuration(3600), "1h");
  assert.equal(formatDuration(3660), "1h 1m");
  assert.equal(formatDuration(2 * 3600 + 15 * 60), "2h 15m");
});

test("formatDate is the local month and day", () => {
  assert.equal(formatDate(new Date(2026, 10, 3, 23, 30).getTime() / 1000), "Nov 3");
});

test("volumeComparison picks the heaviest thing that fits", () => {
  assert.equal(volumeComparison(329), null);
  assert.equal(volumeComparison(330), "≈ 1 sumo wrestler");
  assert.equal(volumeComparison(660), "≈ 2 sumo wrestlers");
  assert.equal(volumeComparison(989), "≈ 3 sumo wrestlers");
  assert.equal(volumeComparison(990), "≈ 1 grand piano");
  assert.equal(volumeComparison(25_000 * 2.44), "≈ 2.4 school buses");
  // Ten or more round to a whole number.
  assert.equal(volumeComparison(875_000 * 12.4), "≈ 12 loaded 747s");
  assert.equal(volumeComparison(22_500_000 * 1500), "≈ 1,500 Eiffel Towers");
});

test("formatMax shows a bodyweight lift's max as reps, unconverted", () => {
  assert.equal(formatMax(12.4, "kg", true), "12 reps");
  assert.equal(formatMax(225, "lb", false), "225 lb");
  assert.equal(formatMax(220.46226218, "kg", false), "100 kg");
});
