import { useEffect, useRef, useState } from "react";
import { Calendar, Check, ChevronDown } from "lucide-react";
import { RANGES, type RangeKey, type RangeState } from "@/lib/range";
import { cn } from "@/lib/utils";

function toInput(s: number): string {
  const d = new Date(s * 1000);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
function fromInput(v: string): number | null {
  if (!v) return null;
  const [y, m, d] = v.split("-").map(Number);
  return Math.floor(new Date(y, m - 1, d).getTime() / 1000);
}
function short(s: number): string {
  return new Date(s * 1000).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "2-digit",
  });
}

/**
 * The date-range control: presets as rows with a check on the selection, and
 * a custom from/to behind a hairline at the bottom. One control, scoping
 * everything below it.
 */
export function RangePicker({
  value,
  onChange,
  nowS,
  sinceS,
}: {
  value: RangeState;
  onChange: (v: RangeState) => void;
  nowS: number;
  sinceS: number;
}) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);
  const [from, setFrom] = useState(
    toInput(value.preset === "custom" ? value.fromS : nowS - 90 * 86_400),
  );
  const [to, setTo] = useState(toInput(value.preset === "custom" ? value.toS : nowS));

  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("pointerdown", onDown);
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("pointerdown", onDown);
      window.removeEventListener("keydown", onKey);
    };
  }, [open]);

  const label =
    value.preset === "custom"
      ? `${short(value.fromS)} – ${short(value.toS)}`
      : `Last ${RANGES.find((r) => r.key === value.preset)!.label}`.replace("Last All", "All time");

  function applyCustom() {
    const f = fromInput(from);
    const t = fromInput(to);
    if (f === null || t === null) return;
    const [a, b] = f <= t ? [f, t] : [t, f];
    onChange({ preset: "custom", fromS: Math.max(a, sinceS - 86_400), toS: Math.min(b, nowS) });
    setOpen(false);
  }

  return (
    <div ref={rootRef} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="listbox"
        aria-expanded={open}
        className="h-9 inline-flex items-center gap-2 pl-3 pr-2.5 rounded-lg border border-border bg-surface text-sm font-semibold text-text hover:border-muted transition-colors cursor-pointer"
      >
        <Calendar size={14} className="text-muted" />
        {label}
        <ChevronDown
          size={14}
          className={cn("text-muted transition-transform", open && "rotate-180")}
        />
      </button>

      {open && (
        <div
          role="listbox"
          className="absolute right-0 z-40 mt-2 w-64 border border-border rounded-xl bg-background/95 backdrop-blur-sm shadow-2xl p-1.5"
        >
          {RANGES.map((r) => {
            const active = value.preset === r.key;
            return (
              <button
                key={r.key}
                role="option"
                aria-selected={active}
                onClick={() => {
                  onChange({ preset: r.key as RangeKey });
                  setOpen(false);
                }}
                className={cn(
                  "w-full flex items-center justify-between px-3 py-2 rounded-lg text-sm cursor-pointer transition-colors",
                  active
                    ? "text-text font-semibold"
                    : "text-muted hover:bg-white/[0.04] hover:text-text",
                )}
              >
                <span>
                  {r.key === "all"
                    ? "All time"
                    : `Last ${r.label === "1M" ? "month" : r.label === "3M" ? "3 months" : r.label === "6M" ? "6 months" : "year"}`}
                </span>
                {active && <Check size={16} strokeWidth={3} />}
              </button>
            );
          })}
          <div className="border-t border-border/60 mt-1.5 pt-2 px-1.5 pb-1">
            <p className="text-[11px] uppercase tracking-wider text-muted m-0 mb-1.5">Custom</p>
            <div className="flex items-center gap-1.5">
              <input
                id="range-from"
                type="date"
                value={from}
                min={toInput(sinceS)}
                max={toInput(nowS)}
                onChange={(e) => setFrom(e.target.value)}
                className="flex-1 min-w-0 h-8 px-2 rounded-md bg-surface border border-border text-xs text-text [color-scheme:dark]"
              />
              <span className="text-muted text-xs">to</span>
              <input
                id="range-to"
                type="date"
                value={to}
                min={toInput(sinceS)}
                max={toInput(nowS)}
                onChange={(e) => setTo(e.target.value)}
                className="flex-1 min-w-0 h-8 px-2 rounded-md bg-surface border border-border text-xs text-text [color-scheme:dark]"
              />
            </div>
            <button
              onClick={applyCustom}
              className="mt-2 w-full h-8 rounded-md bg-primary text-on-primary text-xs font-semibold cursor-pointer"
            >
              Apply
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
