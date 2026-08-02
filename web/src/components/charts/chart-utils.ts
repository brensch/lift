import { useEffect, useRef, useState } from "react";

// Chart palette, validated with the dataviz six-checks against the site
// surface #141414 (CVD ΔE ≥ 8, normal-vision ΔE ≥ 15, contrast ≥ 3:1).
// Slot order is the safety mechanism — don't reshuffle casually.
export const SERIES_1 = "#3987e5"; // blue — primary series / emphasis
export const SERIES_2 = "#d95926"; // orange
export const SERIES_3 = "#199e70"; // aqua
export const CONTEXT = "#8f8f8f"; // de-emphasis gray for context series
export const GRID = "#262626"; // hairline grid, one step off surface
export const SURFACE = "#141414"; // chart surface (cards)

/** Measure a container's content width via ResizeObserver. */
export function useMeasuredWidth<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const [width, setWidth] = useState(0);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver((entries) => {
      const w = entries[0]?.contentRect.width ?? 0;
      setWidth((prev) => (Math.abs(prev - w) < 1 ? prev : w));
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return { ref, width };
}

/** Round tick steps: 1/2/2.5/5 × 10^n covering [min, max] in ~count steps. */
export function niceTicks(min: number, max: number, count = 4): number[] {
  if (!isFinite(min) || !isFinite(max)) return [];
  if (min === max) {
    min = min === 0 ? 0 : min * 0.9;
    max = max === 0 ? 1 : max * 1.1;
  }
  const span = max - min;
  const rawStep = span / count;
  const mag = 10 ** Math.floor(Math.log10(rawStep));
  let step = mag;
  for (const m of [1, 2, 2.5, 5, 10]) {
    if (mag * m >= rawStep) {
      step = mag * m;
      break;
    }
  }
  const start = Math.ceil(min / step) * step;
  const ticks: number[] = [];
  for (let v = start; v <= max + step * 1e-6; v += step) {
    ticks.push(Math.round(v * 1e6) / 1e6);
  }
  return ticks;
}

export function scaleLinear(
  domainMin: number,
  domainMax: number,
  rangeMin: number,
  rangeMax: number
) {
  const d = domainMax - domainMin || 1;
  return (v: number) => rangeMin + ((v - domainMin) / d) * (rangeMax - rangeMin);
}

const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

/** Month-boundary ticks across a unix-seconds domain, thinned to maxTicks. */
export function timeTicks(
  minS: number,
  maxS: number,
  maxTicks = 6
): { value: number; label: string }[] {
  const start = new Date(minS * 1000);
  const end = new Date(maxS * 1000);
  const months: { value: number; label: string }[] = [];
  const cursor = new Date(start.getFullYear(), start.getMonth() + 1, 1);
  while (cursor <= end) {
    months.push({
      value: cursor.getTime() / 1000,
      label:
        cursor.getMonth() === 0
          ? `${MONTHS[0]} '${String(cursor.getFullYear() % 100).padStart(2, "0")}`
          : MONTHS[cursor.getMonth()],
    });
    cursor.setMonth(cursor.getMonth() + 1);
  }
  if (months.length <= maxTicks) return months;
  const stride = Math.ceil(months.length / maxTicks);
  return months.filter((_, i) => i % stride === 0);
}
