import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

// The app's flat building blocks (app/lib/widgets/common/flat.dart) for the
// website: full-width sections split by hairlines, each heading on a darker
// band, the content in a centred column so it reads on a phone and a desk.

/** The centred column every flat section's content sits in. */
function Column({ className, children }: { className?: string; children: ReactNode }) {
  return <div className={cn("max-w-xl mx-auto px-5", className)}>{children}</div>;
}

/** A section heading on the darker band, full width, as the app's are. */
export function FlatHeading({ children }: { children: ReactNode }) {
  return (
    // A pixel up, over the hairline that ends the row above, so the two read
    // as one line rather than a doubled one (as the app does).
    <div className="relative -mt-px bg-band border-y border-border">
      <Column className="py-2.5 text-base font-medium text-muted">{children}</Column>
    </div>
  );
}

/** One full-width block, a hairline under it. */
export function FlatSection({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <div className="border-b border-border">
      <Column className={cn("py-5", className)}>{children}</Column>
    </div>
  );
}

/** A full-width row: a label over a quieter line, whatever goes on the right. */
export function FlatRow({
  label,
  sub,
  right,
}: {
  label: ReactNode;
  sub?: ReactNode;
  right?: ReactNode;
}) {
  return (
    <div className="border-b border-border">
      <Column className="py-3.5 flex items-center justify-between gap-4">
        <div className="min-w-0">
          <div className="font-semibold text-text">{label}</div>
          {sub && <div className="text-sm text-muted mt-0.5">{sub}</div>}
        </div>
        {right}
      </Column>
    </div>
  );
}
