import { useMemo, useState } from "react";
import {
  GRID,
  niceTicks,
  scaleLinear,
  useMeasuredWidth,
} from "./chart-utils";

export interface Column {
  label: string; // x label / tooltip title
  value: number;
}

const PAD = { top: 12, right: 8, bottom: 26, left: 44 };
const HEIGHT = 240;
const MAX_BAR_W = 24;

/**
 * Single-series column chart: ≤24px bars with 4px rounded caps growing from
 * a square baseline, per-bar hover tooltip, hairline grid.
 */
export function ColumnChart({
  data,
  color,
  yFormat,
  tooltipValue,
}: {
  data: Column[];
  color: string;
  yFormat: (v: number) => string;
  tooltipValue: (c: Column) => string;
}) {
  const { ref, width } = useMeasuredWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);

  const plotW = Math.max(width - PAD.left - PAD.right, 0);
  const plotH = HEIGHT - PAD.top - PAD.bottom;

  const { yScale, yTicks } = useMemo(() => {
    const max = Math.max(...data.map((d) => d.value), 1);
    const ticks = niceTicks(0, max * 1.08, 4);
    const hi = Math.max(ticks[ticks.length - 1] ?? max, max);
    return {
      yScale: scaleLinear(0, hi, PAD.top + plotH, PAD.top),
      yTicks: ticks,
    };
  }, [data, plotH]);

  if (width === 0) return <div ref={ref} style={{ height: HEIGHT }} />;
  if (data.length === 0) {
    return (
      <div
        ref={ref}
        style={{ height: HEIGHT }}
        className="flex items-center justify-center text-sm text-muted"
      >
        No sessions yet
      </div>
    );
  }

  const slot = plotW / data.length;
  const barW = Math.min(MAX_BAR_W, Math.max(slot - 4, 2));
  const baseline = PAD.top + plotH;
  const labelStride = Math.max(1, Math.ceil((data.length * 34) / plotW));

  const hovered = hover !== null ? data[hover] : null;
  const tooltipLeft =
    hover !== null
      ? Math.min(Math.max(PAD.left + slot * hover + slot / 2 - 60, 4), width - 130)
      : 0;

  return (
    <div ref={ref} className="relative" style={{ height: HEIGHT }}>
      <svg width={width} height={HEIGHT} className="block">
        {yTicks.map((t) => (
          <line
            key={t}
            x1={PAD.left}
            x2={PAD.left + plotW}
            y1={yScale(t)}
            y2={yScale(t)}
            stroke={GRID}
            strokeWidth={1}
          />
        ))}
        {yTicks.map((t) => (
          <text
            key={`yl-${t}`}
            x={PAD.left - 8}
            y={yScale(t) + 3.5}
            textAnchor="end"
            className="fill-muted"
            style={{ font: "11px var(--font-sans)", fontVariantNumeric: "tabular-nums" }}
          >
            {yFormat(t)}
          </text>
        ))}

        {data.map((d, i) => {
          const cx = PAD.left + slot * i + slot / 2;
          const top = yScale(d.value);
          const h = Math.max(baseline - top, d.value > 0 ? 2 : 0);
          const r = Math.min(4, barW / 2, h);
          return (
            <g key={i}>
              {h > 0 && (
                // Rounded cap at the data end, square at the baseline
                <path
                  d={`M${cx - barW / 2},${baseline}
                      L${cx - barW / 2},${baseline - h + r}
                      Q${cx - barW / 2},${baseline - h} ${cx - barW / 2 + r},${baseline - h}
                      L${cx + barW / 2 - r},${baseline - h}
                      Q${cx + barW / 2},${baseline - h} ${cx + barW / 2},${baseline - h + r}
                      L${cx + barW / 2},${baseline} Z`}
                  fill={color}
                  opacity={hover === null || hover === i ? 1 : 0.45}
                  style={{ transition: "opacity 120ms" }}
                />
              )}
              {i % labelStride === 0 && (
                <text
                  x={cx}
                  y={HEIGHT - 8}
                  textAnchor="middle"
                  className="fill-muted"
                  style={{ font: "11px var(--font-sans)" }}
                >
                  {d.label}
                </text>
              )}
              {/* Hit target: the full slot, never just the painted bar */}
              <rect
                x={PAD.left + slot * i}
                y={PAD.top}
                width={slot}
                height={plotH}
                fill="transparent"
                onPointerEnter={() => setHover(i)}
                onPointerLeave={() => setHover(null)}
              />
            </g>
          );
        })}
      </svg>

      {hovered && (
        <div
          className="absolute pointer-events-none border border-border rounded-lg bg-background/95 backdrop-blur-sm px-3 py-2 text-xs shadow-xl"
          style={{ left: tooltipLeft, top: 0 }}
        >
          <p className="text-muted m-0 mb-0.5">{hovered.label}</p>
          <p className="m-0 font-semibold text-text">{tooltipValue(hovered)}</p>
        </div>
      )}
    </div>
  );
}
