import { useState } from "react";
import { formatDuration } from "@/lib/format";
import { useMeasuredWidth } from "./chart-utils";

export interface TimeBarRow {
  label: string; // e.g. "Jul 30"
  title: string; // tooltip title, e.g. "Workout A — Jul 30"
  segments: { label: string; color: string; seconds: number }[];
}

const LABEL_W = 52;
const VALUE_W = 46;
const BAR_H = 16;
const ROW_GAP = 12;
const SEG_GAP = 2; // surface gap between touching fills

/**
 * Horizontal stacked bars — one row per workout, segments separated by 2px
 * surface gaps, rounded only at the data end. The whole row is the hit
 * target; the tooltip lists every segment.
 */
export function TimeBars({ rows }: { rows: TimeBarRow[] }) {
  const { ref, width } = useMeasuredWidth<HTMLDivElement>();
  const [hover, setHover] = useState<number | null>(null);

  const height = rows.length * (BAR_H + ROW_GAP) + 4;

  if (width === 0) return <div ref={ref} style={{ height }} />;
  if (rows.length === 0) {
    return (
      <div
        ref={ref}
        style={{ height: 200 }}
        className="flex items-center justify-center text-sm text-muted"
      >
        No sessions yet
      </div>
    );
  }

  const barMax = Math.max(width - LABEL_W - VALUE_W - 12, 40);
  const maxTotal = Math.max(
    ...rows.map((r) => r.segments.reduce((a, s) => a + s.seconds, 0)),
    1
  );

  const hovered = hover !== null ? rows[hover] : null;
  const tooltipTop = hover !== null ? hover * (BAR_H + ROW_GAP) + BAR_H + 6 : 0;

  return (
    <div ref={ref} className="relative" style={{ height }}>
      <svg width={width} height={height} className="block">
        {rows.map((row, ri) => {
          const y = ri * (BAR_H + ROW_GAP) + 2;
          const total = row.segments.reduce((a, s) => a + s.seconds, 0);
          const scale = (barMax * total) / maxTotal / (total || 1);
          const visible = row.segments.filter((s) => s.seconds > 0);
          let x = LABEL_W;
          return (
            <g
              key={ri}
              opacity={hover === null || hover === ri ? 1 : 0.5}
              style={{ transition: "opacity 120ms" }}
            >
              <text
                x={LABEL_W - 8}
                y={y + BAR_H / 2 + 3.5}
                textAnchor="end"
                className="fill-muted"
                style={{ font: "11px var(--font-sans)", fontVariantNumeric: "tabular-nums" }}
              >
                {row.label}
              </text>
              {visible.map((seg, si) => {
                const w = Math.max(seg.seconds * scale - (si < visible.length - 1 ? SEG_GAP : 0), 1.5);
                const isLast = si === visible.length - 1;
                const r = isLast ? 4 : 0;
                const el = (
                  <path
                    key={si}
                    d={
                      isLast
                        ? `M${x},${y}
                           L${x + w - r},${y}
                           Q${x + w},${y} ${x + w},${y + r}
                           L${x + w},${y + BAR_H - r}
                           Q${x + w},${y + BAR_H} ${x + w - r},${y + BAR_H}
                           L${x},${y + BAR_H} Z`
                        : `M${x},${y} L${x + w},${y} L${x + w},${y + BAR_H} L${x},${y + BAR_H} Z`
                    }
                    fill={seg.color}
                  />
                );
                x += seg.seconds * scale + (si < visible.length - 1 ? SEG_GAP : 0);
                return el;
              })}
              <text
                x={x + 8}
                y={y + BAR_H / 2 + 3.5}
                className="fill-muted"
                style={{ font: "11px var(--font-sans)", fontVariantNumeric: "tabular-nums" }}
              >
                {formatDuration(total)}
              </text>
              {/* Whole-row hit target */}
              <rect
                x={0}
                y={y - ROW_GAP / 2}
                width={width}
                height={BAR_H + ROW_GAP}
                fill="transparent"
                onPointerEnter={() => setHover(ri)}
                onPointerLeave={() => setHover(null)}
              />
            </g>
          );
        })}
      </svg>

      {hovered && (
        <div
          className="absolute pointer-events-none z-10 border border-border rounded-lg bg-background/95 backdrop-blur-sm px-3 py-2 text-xs shadow-xl"
          style={{
            left: Math.min(LABEL_W, width - 170),
            top: Math.min(tooltipTop, height - 90),
          }}
        >
          <p className="text-muted m-0 mb-1">{hovered.title}</p>
          {hovered.segments.map((s) => (
            <p key={s.label} className="m-0 flex items-center gap-1.5 leading-5">
              <span
                className="inline-block w-2.5 h-2.5 rounded-[3px]"
                style={{ background: s.color }}
              />
              <span className="font-semibold text-text">
                {formatDuration(s.seconds)}
              </span>
              <span className="text-muted">{s.label}</span>
            </p>
          ))}
        </div>
      )}
    </div>
  );
}
