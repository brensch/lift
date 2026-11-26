import { useState } from "react";
import { Check, Copy, ExternalLink } from "lucide-react";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { site } from "@/content";

// How to connect a bot (an MCP client) to Schlift: the address to paste,
// where each bot keeps its connectors, and what happens next. The OAuth
// side is src/mcp; the consent page it sends people to is /connect. Every
// string is store/listing.yaml's `website:`.

/** The MCP endpoint, on whichever host served this page (dev or prod). */
const MCP_URL = `${window.location.origin}/api/mcp`;
const CLAUDE_CONNECTORS = "https://claude.ai/settings/connectors";

function CopyBox({ text, mono = true }: { text: string; mono?: boolean }) {
  const [copied, setCopied] = useState(false);
  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 2000);
    } catch {
      // No clipboard (an old browser, or not https): the text is there to select.
    }
  }
  return (
    <div className="mt-3 flex items-stretch gap-2">
      <div
        className={
          mono
            ? "flex-1 min-w-0 rounded-md border border-border bg-background px-3 py-2.5 font-mono text-sm text-text break-all select-all"
            : "flex-1 min-w-0 rounded-md border border-border bg-background px-3 py-2.5 text-sm text-text leading-relaxed select-all"
        }
      >
        {text}
      </div>
      <Button onClick={copy} className="shrink-0 self-start" aria-live="polite">
        {copied ? (
          <Check size={16} className="mr-1.5 text-ok" />
        ) : (
          <Copy size={16} className="mr-1.5" />
        )}
        {copied ? site("bot_copied") : site("bot_copy")}
      </Button>
    </div>
  );
}

function Step({ n, title, children }: { n: number; title: string; children: React.ReactNode }) {
  return (
    <li className="grid grid-cols-[2.25rem_1fr] gap-4 py-7 border-t border-border first:border-t-0">
      <span className="w-9 h-9 rounded-full bg-text text-background font-mono font-bold flex items-center justify-center">
        {n}
      </span>
      <div className="min-w-0">
        <h2 className="font-display text-xl font-bold tracking-tight m-0 mt-1">{title}</h2>
        {children}
      </div>
    </li>
  );
}

export function BotPage() {
  return (
    <div className="max-w-2xl mx-auto px-5 py-16 md:py-24">
      <h1 className="font-display text-4xl md:text-5xl font-extrabold tracking-tight m-0">
        <WobblyText text={site("bot_page_title")} seed={73} />
      </h1>
      <p className="mt-5 text-lg text-muted leading-relaxed">{site("bot_page_text")}</p>

      <ol className="list-none p-0 m-0 mt-10 border border-border rounded-2xl bg-surface px-6 md:px-8">
        <Step n={1} title={site("bot_step_1_title")}>
          <p className="m-0 mt-2 text-muted">{site("bot_step_1_text")}</p>
          <CopyBox text={MCP_URL} />
        </Step>
        <Step n={2} title={site("bot_step_2_title")}>
          <ul className="m-0 mt-2 pl-5 space-y-2 text-muted leading-relaxed">
            <li>{site("bot_step_2_claude")}</li>
            <li>{site("bot_step_2_chatgpt")}</li>
            <li>{site("bot_step_2_other")}</li>
          </ul>
          <a
            href={CLAUDE_CONNECTORS}
            target="_blank"
            rel="noreferrer"
            className="no-underline inline-block mt-4"
          >
            <Button variant="primary" className="group">
              {site("bot_open_claude")}
              <ExternalLink size={15} className="ml-2" />
            </Button>
          </a>
        </Step>
        <Step n={3} title={site("bot_step_3_title")}>
          <p className="m-0 mt-2 text-muted leading-relaxed">{site("bot_step_3_text")}</p>
        </Step>
        <Step n={4} title={site("bot_step_4_title")}>
          <p className="m-0 mt-2 text-muted">{site("bot_step_4_text")}</p>
          <CopyBox text={site("bot_example_prompt")} mono={false} />
        </Step>
        <Step n={5} title={site("bot_step_5_title")}>
          <p className="m-0 mt-2 text-muted leading-relaxed">{site("bot_step_5_text")}</p>
        </Step>
      </ol>
    </div>
  );
}
