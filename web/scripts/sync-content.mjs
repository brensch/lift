// Pulls everything the landing page says and shows out of the repo, so the
// site can never drift from the store listing. Nothing is parsed out of
// prose: the YAML holds typed pieces and this passes them through.
//   store/listing.yaml           -> src/generated/content.json
//   templates/library.yaml       -> content.json (library, the /routines page)
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

// The template library, as the backend embeds it. Exercises stay as the
// enum names written in the YAML; the page maps them to display names.
const libraryYaml = parse(readFileSync(resolve(repo, "templates/library.yaml"), "utf8"));
const library = {
  groups: (libraryYaml.groups ?? []).map((g) => ({ key: String(g.key), label: String(g.label) })),
  templates: (libraryYaml.templates ?? []).map((t) => ({
    id: String(t.id),
    name: String(t.name),
    group: String(t.group),
    blurb: String(t.blurb ?? ""),
    isDefault: t.default === true,
    exercises: (t.exercises ?? []).map(String),
  })),
};

// Latest release notes by version number.
const notesDir = resolve(repo, "release-notes");
const versions = readdirSync(notesDir)
  .filter((f) => /^\d+\.\d+\.\d+\.md$/.test(f))
  .map((f) => f.replace(/\.md$/, ""))
  .sort((a, b) => {
    const pa = a.split(".").map(Number),
      pb = b.split(".").map(Number);
    for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pb[i] - pa[i];
    return 0;
  });
const latest = versions[0];
const whatsNew = latest
  ? {
      version: latest,
      lines: readFileSync(resolve(notesDir, `${latest}.md`), "utf8")
        .trim()
        .split("\n")
        .map((l) => l.trim())
        .filter(Boolean),
    }
  : null;

const content = {
  name: listing.name,
  tagline: listing.tagline,
  promotionalText: listing.promotional_text,
  // Typed pieces, straight from the YAML. The stores get them composed into
  // one description (scripts/check_store_text.py); the site gets them as is.
  about: String(listing.about ?? "")
    .trim()
    .split(/\n\s*\n/)
    .map((p) => p.trim())
    .filter(Boolean),
  testimonialsHeading: listing.testimonials_heading ?? "",
  testimonials: (listing.testimonials ?? []).map((t) => ({
    quote: String(t.quote),
    name: String(t.name),
  })),
  otherFeatures: {
    heading: listing.other_features?.heading ?? "",
    items: (listing.other_features?.items ?? []).map((i) =>
      typeof i === "string"
        ? { emoji: "", text: i }
        : { emoji: String(i.emoji ?? ""), text: String(i.text ?? "") },
    ),
  },
  website: listing.website ?? {},
  screenshots: (listing.screenshots ?? []).map((s) => ({
    src: `/generated/screens/${s.file}`,
    title: s.title,
    subtitle: s.subtitle ?? "",
  })),
  whatsNew,
  library,
};

mkdirSync(resolve(web, "src/generated"), { recursive: true });
writeFileSync(resolve(web, "src/generated/content.json"), JSON.stringify(content, null, 2) + "\n");

const gen = resolve(web, "public/generated");
mkdirSync(resolve(gen, "screens"), { recursive: true });
for (const s of listing.screenshots ?? []) {
  copyFileSync(resolve(repo, "store/screenshots/raw", s.file), resolve(gen, "screens", s.file));
}
copyFileSync(resolve(repo, "marketing/schlift-square-512.png"), resolve(gen, "icon-512.png"));

// Tab favicon: the app icon (scripts/render_brand.py), same geometry on its
// 100 grid. Opaque, so it reads the same on light and dark tabs.
const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<rect width="100" height="46" fill="#EDECE5"/>
<rect y="46" width="64" height="22" fill="#FF4F00"/><rect x="64" y="46" width="36" height="22" fill="#E9A27E"/>
<rect y="68" width="100" height="32" fill="#DBDAD2"/>
<rect y="45.2" width="100" height="0.8" fill="#9C9B93"/><rect y="67.2" width="100" height="0.8" fill="#9C9B93"/>
<circle cx="20" cy="27" r="7.5" fill="#111111"/><circle cx="40" cy="27" r="7.5" fill="#111111"/><circle cx="60" cy="27" r="7.5" fill="#111111"/>
<circle cx="80" cy="27" r="6.6" fill="none" stroke="#FF4F00" stroke-width="1.8"/>
</svg>
`;
writeFileSync(resolve(gen, "favicon.svg"), favicon);
copyFileSync(resolve(repo, "marketing/feature_graphic.png"), resolve(gen, "og.png"));
console.log(
  `synced listing (${content.screenshots.length} slides, notes ${latest ?? "none"}, ${library.templates.length} library templates) into web/src/generated + web/public/generated`,
);
