import { useState, type ReactNode } from "react";
import { Table2, ChartLine } from "lucide-react";
import { cn } from "@/lib/utils";

export interface LegendItem {
  label: string;
  color: string;
  shape: "line" | "rect";
}

export interface TableSpec {
  head: string[];
  rows: string[][];
  /** Column indexes that hold numbers — right-aligned, tabular figures. */
  numeric?: number[];
}

/**
 * Card chrome shared by every chart: title row, legend, and a chart ↔ table
 * toggle so every value is reachable without hovering.
 */
export function ChartCard({
  title,
  subtitle,
  legend,
  table,
  children,
}: {
  title: string;
  subtitle?: string;
  legend?: LegendItem[];
  table: TableSpec;
  children: ReactNode;
}) {
  const [showTable, setShowTable] = useState(false);

  return (
    <div className="border border-border rounded-xl bg-surface p-5 sm:p-6">
      <div className="flex items-start justify-between gap-3 mb-4">
        <div>
          <h3 className="font-display font-bold text-base tracking-tight m-0">
            {title}
          </h3>
          {subtitle && <p className="text-sm text-muted mt-0.5 m-0">{subtitle}</p>}
        </div>
        <div className="flex items-center gap-4 shrink-0">
          {legend && legend.length > 1 && !showTable && (
            <div className="hidden sm:flex items-center gap-4">
              {legend.map((item) => (
                <span
                  key={item.label}
                  className="flex items-center gap-1.5 text-xs text-muted"
                >
                  {item.shape === "line" ? (
                    <span
                      className="inline-block w-3.5 h-0.5 rounded-full"
                      style={{ background: item.color }}
                    />
                  ) : (
                    <span
                      className="inline-block w-2.5 h-2.5 rounded-[3px]"
                      style={{ background: item.color }}
                    />
                  )}
                  {item.label}
                </span>
              ))}
            </div>
          )}
          <button
            onClick={() => setShowTable(!showTable)}
            className="p-1.5 rounded-md text-muted hover:text-text hover:bg-surface-hover transition-colors cursor-pointer"
            aria-label={showTable ? "Show chart" : "Show data table"}
            title={showTable ? "Show chart" : "Show data table"}
          >
            {showTable ? <ChartLine size={15} /> : <Table2 size={15} />}
          </button>
        </div>
      </div>

      {/* Mobile legend — below title so it never crowds the toggle */}
      {legend && legend.length > 1 && !showTable && (
        <div className="flex sm:hidden items-center gap-4 mb-3 -mt-1">
          {legend.map((item) => (
            <span
              key={item.label}
              className="flex items-center gap-1.5 text-xs text-muted"
            >
              {item.shape === "line" ? (
                <span
                  className="inline-block w-3.5 h-0.5 rounded-full"
                  style={{ background: item.color }}
                />
              ) : (
                <span
                  className="inline-block w-2.5 h-2.5 rounded-[3px]"
                  style={{ background: item.color }}
                />
              )}
              {item.label}
            </span>
          ))}
        </div>
      )}

      {showTable ? (
        <div className="overflow-auto max-h-72">
          <table className="w-full text-sm border-collapse">
            <thead>
              <tr>
                {table.head.map((h, i) => (
                  <th
                    key={h}
                    className={cn(
                      "text-muted font-medium text-xs uppercase tracking-wider py-2 px-2 border-b border-border sticky top-0 bg-surface",
                      table.numeric?.includes(i) ? "text-right" : "text-left"
                    )}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {table.rows.map((row, ri) => (
                <tr key={ri}>
                  {row.map((cell, ci) => (
                    <td
                      key={ci}
                      className={cn(
                        "py-1.5 px-2 border-b border-border/40 text-text",
                        table.numeric?.includes(ci)
                          ? "text-right [font-variant-numeric:tabular-nums]"
                          : "text-left"
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
      ) : (
        children
      )}
    </div>
  );
}
