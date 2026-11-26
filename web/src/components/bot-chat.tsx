import { useEffect, useState } from "react";
import { Wrench } from "lucide-react";
import { useReveal } from "@/lib/useReveal";
import type { BotMessage } from "@/content";

// The home page's mock bot chat (store/listing.yaml → bot_demo): a person
// asks for a programme and the bot builds it with Schlift's real tools.
// Once it scrolls into view the lines arrive one by one, as if it were
// happening; with reduced motion they are all there at once.

/** How long each kind of line waits before it appears, ms. */
const PAUSE: Record<BotMessage["kind"], number> = { you: 500, tool: 650, bot: 1100 };

function Thinking() {
  return (
    <div className="flex gap-1 px-1 py-2" aria-hidden>
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="w-1.5 h-1.5 rounded-full bg-muted/50 animate-bounce"
          style={{ animationDelay: `${i * 150}ms` }}
        />
      ))}
    </div>
  );
}

function Line({ message }: { message: BotMessage }) {
  if (message.kind === "you") {
    return (
      <div className="flex justify-end animate-reveal-up motion-reduce:animate-none">
        <p className="m-0 max-w-[85%] break-words rounded-2xl rounded-br-sm bg-text text-background px-4 py-2.5 text-[0.95rem] leading-relaxed">
          {message.text}
        </p>
      </div>
    );
  }
  if (message.kind === "tool") {
    return (
      <div className="flex min-w-0 items-center gap-2 text-xs text-muted animate-reveal-up motion-reduce:animate-none">
        <span className="shrink-0 inline-flex items-center gap-1.5 rounded-md border border-border bg-background px-2 py-1 font-mono text-[0.7rem] text-text">
          <Wrench size={11} className="text-primary" />
          {message.tool}
        </span>
        <span className="min-w-0 truncate">{message.text}</span>
      </div>
    );
  }
  return (
    <p className="m-0 max-w-[92%] break-words text-[0.95rem] leading-relaxed text-text animate-reveal-up motion-reduce:animate-none">
      {message.text}
    </p>
  );
}

export function BotChat({ title, messages }: { title: string; messages: BotMessage[] }) {
  // A sliver in view is enough: on a phone the window is taller than the
  // screen, and a bigger share might never be on it at once.
  const { ref, visible } = useReveal(0.1);
  const reduced =
    typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const [shown, setShown] = useState(reduced ? messages.length : 0);

  useEffect(() => {
    if (!visible || shown >= messages.length) return;
    const timer = window.setTimeout(() => setShown((n) => n + 1), PAUSE[messages[shown].kind]);
    return () => window.clearTimeout(timer);
  }, [visible, shown, messages]);

  const next = messages[shown];
  return (
    <div
      ref={ref}
      className="border border-border rounded-2xl bg-surface overflow-hidden shadow-[0_24px_64px_rgba(17,17,17,0.14)]"
    >
      <div className="flex items-center gap-1.5 px-3.5 py-2.5 border-b border-border">
        {[0, 1, 2].map((dot) => (
          <span key={dot} className="w-2.5 h-2.5 rounded-full bg-border" />
        ))}
        <span className="ml-3 font-mono text-[0.75rem] text-muted">{title}</span>
        <span className="ml-auto inline-flex items-center gap-1.5 text-[0.7rem] text-muted">
          <span className="w-1.5 h-1.5 rounded-full bg-ok" />
          schlift
        </span>
      </div>
      {/* Every line is laid out from the start (invisible until its turn) so
          the window doesn't grow and push the page around as it plays. */}
      {/* One column the window's width, not its longest line's: on a phone
          the lines wrap instead of running off the side. */}
      <div className="grid grid-cols-[minmax(0,1fr)] p-4 md:p-6">
        <div
          className="col-start-1 row-start-1 min-w-0 flex flex-col gap-3.5 invisible"
          aria-hidden
        >
          {messages.map((m, i) => (
            <Line key={i} message={m} />
          ))}
        </div>
        <div className="col-start-1 row-start-1 min-w-0 flex flex-col gap-3.5">
          {messages.slice(0, shown).map((m, i) => (
            <Line key={i} message={m} />
          ))}
          {visible && next && next.kind !== "you" && <Thinking />}
        </div>
      </div>
    </div>
  );
}
