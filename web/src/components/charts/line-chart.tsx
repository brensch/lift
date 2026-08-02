import { useMemo, useState } from "react";
import {
  GRID,
  SURFACE,
  niceTicks,
  scaleLinear,
  timeTicks,
  useMeasuredWidth,
} from "./chart-utils";

export interface LineSeries {
  label: string;
  color: string;
  /** 2px context line instead of the emphasis treatment */
  context?: boolean;
  points: { x: number; y: number }[]; // x = unix seconds, ascending
}

interface TooltipRow {
  label: string;
  color: string;
  value: string;
}

const PAD = { top: 12, right: 16, bottom: 26, left: 44 };
const HEIGHT = 260;

/**
 * Time-series line chart: hairline grid, 2px lines, crosshair that snaps to
 * the nearest session, one tooltip listing every series, end-dot with a
 * surface ring and a direct label on the emphasis series.
 */
export function LineChart({
  series,
  yFormat,
  tooltipExtra,
}: {
  series: LineSeries[];
  yFormat: (v: number) => string;
  /** Extra tooltip line for a given x (e.g. "5 reps @ 225 lb") */
  tooltipExtra?: (x: number) => string | null;
}) {
  const { ref, width } = useMeasuredWidth<HTMLDivElement>();
  const [hoverX, setHoverX] = useState<number | null>(null);

  const allPoints = useMemo(() => series.flatMap((s) => s.points), [series]);
  const xValues = useMemo(
    () => [...new Set(allPoints.map((p) => p.x))].sort((a, b) => a - b),
    [allPoints]
  );

  const plotW = Math.max(width - PAD.left - PAD.right, 0);
  const plotH = HEIGHT - PAD.top - PAD.bottom;

  const { xScale, yScale, yTicks, xTickList } = useMemo(() => {
    const xMin = xValues[0] ?? 0;
    const xMax = xValues[xValues.length - 1] ?? 1;
    const ys = allPoints.map((p) => p.y);
    const yMin = Math.min(...ys);
    const yMax = Math.max(...ys);
    const yPad = (yMax - yMin) * 0.12 || yMax * 0.1 || 1;
    const ticks = niceTicks(Math.max(0, yMin - yPad), yMax + yPad, 4);
    const domainLo = Math.min(ticks[0] ?? yMin, yMin - yPad * 0.5);
    const domainHi = Math.max(ticks[ticks.length - 1] ?? yMax, yMax + yPad * 0.5);
    return {
      xScale: scaleLinear(xMin, xMax, PAD.left, PAD.left + plotW),
      yScale: scaleLinear(domainLo, domainHi, PAD.top + plotH, PAD.top),
      yTicks: ticks,
      xTickList: timeTicks(xMin, xMax, Math.max(2, Math.floor(plotW / 90))),
    };
  }, [allPoints, xValues, plotW, plotH]);

  if (width === 0) return <div ref={ref} style={{ height: HEIGHT }} />;
  if (xValues.length === 0) {
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

  const hover =
    hoverX !== null
      ? {
          x: hoverX,
          px: xScale(hoverX),
          rows: series
            .map((s) => {
              const pt = s.points.find((p) => p.x === hoverX);
              return pt
                ? { label: s.label, color: s.color, value: yFormat(pt.y) }
                : null;
            })
            .filter((r): r is TooltipRow => r !== null),
        }
      : null;

  function onPointerMove(e: React.PointerEvent<SVGRectElement>) {
    const rect = e.currentTarget.getBoundingClientRect();
    const px = e.clientX - rect.left + PAD.left;
    let best = xValues[0];
    let bestD = Infinity;
    for (const x of xValues) {
      const d = Math.abs(xScale(x) - px);
      if (d < bestD) {
        bestD = d;
        best = x;
      }
    }
    setHoverX(best);
  }

  const tooltipLeft = hover
    ? Math.min(Math.max(hover.px - 70, 4), width - 150)
    : 0;

  return (
    <div ref={ref} className="relative" style={{ height: HEIGHT }}>
      <svg width={width} height={HEIGHT} className="block">
        {/* Grid — solid hairlines, one step off the surface */}
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
        {/* Y tick labels */}
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
        {/* X tick labels */}
        {xTickList.map((t) => (
          <text
            key={t.value}
            x={xScale(t.value)}
            y={HEIGHT - 8}
            textAnchor="middle"
            className="fill-muted"
            style={{ font: "11px var(--font-sans)" }}
          >
            {t.label}
          </text>
        ))}

        {/* Crosshair */}
        {hover && (
          <line
            x1={hover.px}
            x2={hover.px}
            y1={PAD.top}
            y2={PAD.top + plotH}
            stroke={GRID}
            strokeWidth={1}
          />
        )}

        {/* Lines — context series under the emphasis series */}
        {[...series]
          .sort((a, b) => Number(a.context !== true) - Number(b.context !== true))
          .map((s) => {
            const d = s.points
              .map((p, i) => `${i === 0 ? "M" : "L"}${xScale(p.x)},${yScale(p.y)}`)
              .join("");
            const last = s.points[s.points.length - 1];
            return (
              <g key={s.label}>
                <path
                  d={d}
                  fill="none"
                  stroke={s.color}
                  strokeWidth={2}
                  strokeLinejoin="round"
                  strokeLinecap="round"
                />
                {/* End dot with surface ring; direct label on emphasis only */}
                {last && !s.context && (
                  <>
                    <circle
                      cx={xScale(last.x)}
                      cy={yScale(last.y)}
                      r={6}
                      fill={SURFACE}
                    />
                    <circle
                      cx={xScale(last.x)}
                      cy={yScale(last.y)}
                      r={4}
                      fill={s.color}
                    />
                    <text
                      x={xScale(last.x) - 10}
                      y={yScale(last.y) - 9}
                      textAnchor="end"
                      className="fill-text"
                      style={{ font: "600 12px var(--font-sans)" }}
                    >
                      {yFormat(last.y)}
                    </text>
                  </>
                )}
                {/* Hover markers on both series */}
                {hover &&
                  s.points
                    .filter((p) => p.x === hover.x)
                    .map((p) => (
                      <g key={`h-${s.label}`}>
                        <circle cx={xScale(p.x)} cy={yScale(p.y)} r={6} fill={SURFACE} />
                        <circle cx={xScale(p.x)} cy={yScale(p.y)} r={4} fill={s.color} />
                      </g>
                    ))}
              </g>
            );
          })}

        {/* Hit layer — the whole plot, so nobody aims at a 2px line */}
        <rect
          x={PAD.left}
          y={PAD.top}
          width={plotW}
          height={plotH}
          fill="transparent"
          onPointerMove={onPointerMove}
          onPointerLeave={() => setHoverX(null)}
        />
      </svg>

      {hover && hover.rows.length > 0 && (
        <div
          className="absolute pointer-events-none border border-border rounded-lg bg-background/95 backdrop-blur-sm px-3 py-2 text-xs shadow-xl"
          style={{ left: tooltipLeft, top: 0 }}
        >
          <p className="text-muted m-0 mb-1">
            {new Date(hover.x * 1000).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
            })}
          </p>
          {hover.rows.map((r) => (
            <p key={r.label} className="m-0 flex items-center gap-1.5 leading-5">
              <span
                className="inline-block w-3 h-0.5 rounded-full"
                style={{ background: r.color }}
              />
              <span className="font-semibold text-text">{r.value}</span>
              <span className="text-muted">{r.label}</span>
            </p>
          ))}
          {tooltipExtra && tooltipExtra(hover.x) && (
            <p className="m-0 mt-1 text-muted">{tooltipExtra(hover.x)}</p>
          )}
        </div>
      )}
    </div>
  );
}
