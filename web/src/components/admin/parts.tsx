import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

export function Card({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <section className="border border-border rounded-xl bg-surface p-4 sm:p-5 min-w-0">
      <h3 className="font-display text-base font-bold tracking-tight m-0">{title}</h3>
      {subtitle && <p className="text-xs text-muted mt-1 mb-0">{subtitle}</p>}
      <div className="mt-4">{children}</div>
    </section>
  );
}

export function DataTable({
  head,
  rows,
  numeric = [],
  wrap = [],
  onRowClick,
  activeRow,
  empty = "Nothing recorded in this window yet.",
  maxHeight,
}: {
  head: string[];
  rows: ReactNode[][];
  numeric?: number[];
  /** Columns allowed to wrap; the rest stay on one line. */
  wrap?: number[];
  onRowClick?: (index: number) => void;
  activeRow?: number;
  empty?: string;
  /** A long table scrolls inside this height (a CSS length) under its head. */
  maxHeight?: string;
}) {
  if (rows.length === 0) return <p className="text-sm text-muted m-0">{empty}</p>;
  return (
    <div className="overflow-auto -mx-1" style={maxHeight ? { maxHeight } : undefined}>
      <table className="w-full text-sm border-collapse">
        <thead>
          <tr>
            {head.map((h, i) => (
              <th
                key={h || i}
                className={cn(
                  "px-2 py-1.5 text-xs uppercase tracking-wider text-muted font-medium border-b border-border whitespace-nowrap",
                  maxHeight && "sticky top-0 bg-surface",
                  numeric.includes(i) ? "text-right" : "text-left",
                )}
              >
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, r) => (
            <tr
              key={r}
              onClick={onRowClick ? () => onRowClick(r) : undefined}
              className={cn(
                "border-b border-border/50 last:border-0",
                onRowClick && "cursor-pointer hover:bg-background",
                activeRow === r && "bg-background",
              )}
            >
              {row.map((cell, c) => (
                <td
                  key={c}
                  className={cn(
                    "px-2 py-1.5",
                    wrap.includes(c) ? "whitespace-normal text-muted" : "whitespace-nowrap",
                    numeric.includes(c)
                      ? "text-right [font-variant-numeric:tabular-nums]"
                      : "text-left",
                  )}
                >
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
