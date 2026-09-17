// Pulls everything the landing page says and shows out of the repo, so the
// site can never drift from the store listing. Nothing is parsed out of
// prose: the YAML holds typed pieces and this passes them through.
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
  // Typed pieces, straight from the YAML. The stores get them composed into
  // one description (scripts/check_store_text.py); the site gets them as is.
  about: String(listing.about ?? "").trim().split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean),
  testimonialsHeading: listing.testimonials_heading ?? "",
  testimonials: (listing.testimonials ?? []).map((t) => ({ quote: String(t.quote), name: String(t.name) })),
  otherFeatures: listing.other_features ?? { heading: "", items: [] },
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
