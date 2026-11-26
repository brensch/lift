import { useState } from "react";
import { Check, Copy, ExternalLink } from "lucide-react";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { FlatHeading, FlatSection } from "@/components/flat";
import { site } from "@/content";

// How to connect a bot (an MCP client) to Schlift, as the app's setup page
// says it (app/lib/widgets/connect_ai.dart): the connector's address to
// copy, buttons to where Claude and ChatGPT add one, and what to tell it.
// The OAuth side is src/mcp; the consent page it sends people to is
// /connect. Every string is store/listing.yaml's `website:`.

/** The MCP endpoint, on whichever host served this page (dev or prod). */
const MCP_URL = `${window.location.origin}/api/mcp`;
const CLAUDE_CONNECTORS = "https://claude.ai/settings/connectors";
const CHATGPT_CONNECTORS = "https://chatgpt.com/#settings/Connectors";

/** The address as a full-width row, with a button that copies it. */
function CopyRow({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  async function copy() {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
    } catch {
      // No clipboard (an old browser, or not https): the text is there to select.
    }
  }
  return (
    <div className="border-b border-border">
      <div className="max-w-xl mx-auto px-5 py-2.5 flex items-center justify-between gap-3">
        <span className="font-mono text-sm text-text break-all select-all min-w-0">{text}</span>
        <Button variant="ghost" onClick={copy} className="shrink-0" aria-live="polite">
          {copied ? (
            <Check size={16} className="mr-1.5 text-ok" />
          ) : (
            <Copy size={16} className="mr-1.5" />
          )}
          {copied ? site("bot_copied") : site("bot_copy")}
        </Button>
      </div>
    </div>
  );
}

function Open({ href, label }: { href: string; label: string }) {
  return (
    <a href={href} target="_blank" rel="noreferrer" className="no-underline flex-1">
      <Button className="w-full">
        <ExternalLink size={15} className="mr-2" />
        {label}
      </Button>
    </a>
  );
}

export function BotPage() {
  return (
    <div className="pb-16">
      <FlatSection className="pt-10 pb-6 space-y-3">
        <h1 className="font-display text-3xl md:text-4xl font-extrabold tracking-tight m-0">
          <WobblyText text={site("bot_page_title")} seed={73} />
        </h1>
        <p className="m-0 text-lg text-muted leading-snug">{site("bot_page_text")}</p>
      </FlatSection>

      <FlatHeading>1&nbsp;&nbsp;{site("bot_step_1_title")}</FlatHeading>
      <CopyRow text={MCP_URL} />
      <FlatSection className="space-y-3">
        <div className="flex gap-3">
          <Open href={CLAUDE_CONNECTORS} label={site("bot_open_claude")} />
          <Open href={CHATGPT_CONNECTORS} label={site("bot_open_chatgpt")} />
        </div>
        <p className="m-0 text-xs text-muted">{site("bot_any_ai")}</p>
      </FlatSection>

      <FlatHeading>2&nbsp;&nbsp;{site("bot_step_2_title")}</FlatHeading>
      <FlatSection>
        <p className="m-0 text-lg leading-snug">{site("bot_step_2_text")}</p>
      </FlatSection>
      <div className="max-w-xl mx-auto px-5 pt-3">
        <p className="m-0 text-sm text-muted">{site("bot_waiting")}</p>
      </div>
    </div>
  );
}
