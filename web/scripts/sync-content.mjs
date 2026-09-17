// Pulls everything the landing page says and shows out of the repo, so the
// site can never drift from the store listing:
//   store/listing.yaml           -> src/generated/content.json
//   release-notes/<latest>.md    -> content.json (whatsNew)
//   store/screenshots/raw/*.png  -> public/generated/screens/
//   marketing/schlift-square-512 -> public/generated/icon-512.png (favicon)
//   marketing/feature_graphic    -> public/generated/og.png
// Runs before `vite dev` and `vite build` (see package.json). Generated
// paths are gitignored.
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, readdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { parse } from "yaml";

const here = dirname(fileURLToPath(import.meta.url));
const repo = resolve(here, "..", "..");
const web = resolve(here, "..");

const listing = parse(readFileSync(resolve(repo, "store/listing.yaml"), "utf8"));

// The description is plain store text. Split it into what it is: paragraphs,
// a testimonials block ("quote" then "- name"), and a bullet list with an
// intro line. Nothing is rewritten; only grouped.
function parseDescription(text) {
  const blocks = text.trim().split(/\n\s*\n/).map((b) => b.trim());
  const out = { paragraphs: [], testimonials: [], features: null };
  for (const block of blocks) {
    const lines = block.split("\n").map((l) => l.trim());
    if (/^testimonials:$/i.test(block)) continue;
    if (lines[0].startsWith('"') && lines.length >= 2 && lines[lines.length - 1].startsWith("- ")) {
      out.testimonials.push({
        quote: lines.slice(0, -1).join(" ").replace(/^"|"$/g, ""),
        name: lines[lines.length - 1].replace(/^-\s*/, ""),
      });
      continue;
    }
    const bullets = lines.filter((l) => l.startsWith("- "));
    if (bullets.length >= 2) {
      out.features = {
        intro: lines.filter((l) => !l.startsWith("- ")).join(" "),
        items: bullets.map((l) => l.replace(/^-\s*/, "")),
      };
      continue;
    }
    out.paragraphs.push(lines.join(" "));
  }
  return out;
}

// Latest release notes by version number.
const notesDir = resolve(repo, "release-notes");
const versions = readdirSync(notesDir)
  .filter((f) => /^\d+\.\d+\.\d+\.md$/.test(f))
  .map((f) => f.replace(/\.md$/, ""))
  .sort((a, b) => {
    const pa = a.split(".").map(Number), pb = b.split(".").map(Number);
    for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pb[i] - pa[i];
    return 0;
  });
const latest = versions[0];
const whatsNew = latest
  ? { version: latest, lines: readFileSync(resolve(notesDir, `${latest}.md`), "utf8").trim().split("\n").map((l) => l.trim()).filter(Boolean) }
  : null;

const content = {
  name: listing.name,
  tagline: listing.tagline,
  promotionalText: listing.promotional_text,
  about: parseDescription(listing.description),
  website: listing.website ?? {},
  screenshots: (listing.screenshots ?? []).map((s) => ({
    src: `/generated/screens/${s.file}`,
    title: s.title,
    subtitle: s.subtitle ?? "",
  })),
  whatsNew,
};

mkdirSync(resolve(web, "src/generated"), { recursive: true });
writeFileSync(resolve(web, "src/generated/content.json"), JSON.stringify(content, null, 2) + "\n");

const gen = resolve(web, "public/generated");
mkdirSync(resolve(gen, "screens"), { recursive: true });
for (const s of listing.screenshots ?? []) {
  copyFileSync(resolve(repo, "store/screenshots/raw", s.file), resolve(gen, "screens", s.file));
}
copyFileSync(resolve(repo, "marketing/schlift-square-512.png"), resolve(gen, "icon-512.png"));
copyFileSync(resolve(repo, "marketing/feature_graphic.png"), resolve(gen, "og.png"));
console.log(`synced listing (${content.screenshots.length} slides, notes ${latest ?? "none"}) into web/src/generated + web/public/generated`);
