import { useMemo } from "react";
import { SURFACE, scaleLinear, useMeasuredWidth } from "./chart-utils";

/**
 * A bare trend line for a stat tile or a small multiple: no axes, no grid,
 * an end dot with a surface ring. The number beside it carries the value;
 * this only shows the shape.
 */
export function Sparkline({
  points,
  color,
  height = 44,
}: {
  points: { x: number; y: number }[]; // ascending x
  color: string;
  height?: number;
}) {
  const { ref, width } = useMeasuredWidth<HTMLDivElement>();
  const pad = 6;

  const d = useMemo(() => {
    if (points.length < 2 || width === 0) return "";
    const xs = points.map((p) => p.x);
    const ys = points.map((p) => p.y);
    const xScale = scaleLinear(Math.min(...xs), Math.max(...xs), pad, width - pad);
    const yMin = Math.min(...ys);
    const yMax = Math.max(...ys);
    const yScale = scaleLinear(yMin, yMax === yMin ? yMin + 1 : yMax, height - pad, pad);
    return points
      .map((p, i) => `${i === 0 ? "M" : "L"}${xScale(p.x).toFixed(1)},${yScale(p.y).toFixed(1)}`)
      .join("");
  }, [points, width, height]);

  const last = points[points.length - 1];
  const xs = points.map((p) => p.x);
  const ys = points.map((p) => p.y);
  const endX = last && width ? scaleLinear(Math.min(...xs), Math.max(...xs), pad, width - pad)(last.x) : 0;
  const yMin = Math.min(...ys);
  const yMax = Math.max(...ys);
  const endY = last ? scaleLinear(yMin, yMax === yMin ? yMin + 1 : yMax, height - pad, pad)(last.y) : 0;

  return (
    <div ref={ref} style={{ height }} className="w-full">
      {width > 0 && points.length >= 2 && (
        <svg width={width} height={height} className="block" aria-hidden="true">
          <path d={d} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
          <circle cx={endX} cy={endY} r={5} fill={SURFACE} />
          <circle cx={endX} cy={endY} r={3} fill={color} />
        </svg>
      )}
    </div>
  );
}
