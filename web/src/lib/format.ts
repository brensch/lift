export type DisplayUnit = "lb" | "kg";

export const LB_PER_KG = 2.2046226218;

export function lbToDisplay(lb: number, unit: DisplayUnit): number {
  return unit === "kg" ? lb / LB_PER_KG : lb;
}

/** 225 → "225", 102.06 → "102.1" — weights read cleaner without trailing .0 */
export function formatNumber(n: number, maxDecimals = 1): string {
  const rounded =
    Math.round(n * 10 ** maxDecimals) / 10 ** maxDecimals;
  return rounded.toLocaleString("en-US", {
    maximumFractionDigits: maxDecimals,
  });
}

export function formatWeight(lb: number, unit: DisplayUnit): string {
  return `${formatNumber(lbToDisplay(lb, unit))} ${unit}`;
}

/** 1,284 / 12.9K / 4.2M — for stat tiles and axis ticks */
export function formatCompact(n: number): string {
  if (Math.abs(n) >= 1_000_000) return `${formatNumber(n / 1_000_000)}M`;
  if (Math.abs(n) >= 10_000) return `${formatNumber(n / 1_000)}K`;
  return formatNumber(n, 0);
}

export function formatDuration(totalSeconds: number): string {
  const minutes = Math.round(totalSeconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

export function formatDate(unixSeconds: number): string {
  const d = new Date(unixSeconds * 1000);
  return `${MONTHS[d.getMonth()]} ${d.getDate()}`;
}

export function formatDateFull(unixSeconds: number): string {
  const d = new Date(unixSeconds * 1000);
  return `${MONTHS[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`;
}

export function formatMonthYear(unixSeconds: number): string {
  const d = new Date(unixSeconds * 1000);
  return `${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
}

/** Things you have collectively lifted, heaviest comparison that fits. */
const VOLUME_COMPARISONS: { lb: number; name: string; plural: string }[] = [
  { lb: 22_500_000, name: "Eiffel Tower", plural: "Eiffel Towers" },
  { lb: 875_000, name: "loaded 747", plural: "loaded 747s" },
  { lb: 330_000, name: "blue whale", plural: "blue whales" },
  { lb: 66_000, name: "humpback whale", plural: "humpback whales" },
  { lb: 25_000, name: "school bus", plural: "school buses" },
  { lb: 15_500, name: "T. rex", plural: "T. rexes" },
  { lb: 2_600, name: "giraffe", plural: "giraffes" },
  { lb: 990, name: "grand piano", plural: "grand pianos" },
  { lb: 330, name: "sumo wrestler", plural: "sumo wrestlers" },
];

export function volumeComparison(totalLb: number): string | null {
  for (const c of VOLUME_COMPARISONS) {
    const count = totalLb / c.lb;
    if (count >= 1) {
      const rounded = count >= 10 ? Math.round(count) : Math.round(count * 10) / 10;
      return `≈ ${rounded.toLocaleString("en-US")} ${rounded === 1 ? c.name : c.plural}`;
    }
  }
  return null;
}
