// Pulls everything the landing page says and shows out of the repo, so the
// site can never drift from the store listing. Nothing is parsed out of
// prose: the YAML holds typed pieces and this passes them through.
//   store/listing.yaml           -> src/generated/content.json
//   templates/library.yaml       -> content.json (library, the /routines page)
//   changes/<version>.md         -> content.json (changelog)
//   store/screenshots/raw/*.png  -> public/generated/screens/
//   marketing/schlift-square-512 -> public/generated/icon-512.png (apple-touch-icon)
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

// The change log: every release and everything that changed in it, newest
// first (changes/<version>.md: its date, then one `- ` line per change; see
// scripts/changes.py). next.md, what hasn't shipped, is not shown.
const changesDir = resolve(repo, "changes");
const byVersion = (a, b) => {
  const pa = a.split(".").map(Number),
    pb = b.split(".").map(Number);
  for (let i = 0; i < 3; i++) if (pa[i] !== pb[i]) return pb[i] - pa[i];
  return 0;
};
const changelog = readdirSync(changesDir)
  .filter((f) => /^\d+\.\d+\.\d+\.md$/.test(f))
  .map((f) => f.replace(/\.md$/, ""))
  .sort(byVersion)
  .map((version) => {
    const [date, ...rest] = readFileSync(resolve(changesDir, `${version}.md`), "utf8")
      .trim()
      .split("\n");
    return {
      version,
      date: date.trim(),
      changes: rest.filter((l) => l.startsWith("- ")).map((l) => l.slice(2).trim()),
    };
  });

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
        ? { picture: "", text: i }
        : { picture: String(i.picture ?? ""), text: String(i.text ?? "") },
    ),
  },
  website: listing.website ?? {},
  screenshots: (listing.screenshots ?? []).map((s) => ({
    src: `/generated/screens/${s.file}`,
    title: s.title,
    subtitle: s.subtitle ?? "",
    device: s.device ?? "phone",
  })),
  changelog,
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
// 100 grid: the end of a loaded bar, plates stepping up toward the middle,
// each drawn under the heavier one after it. Opaque, so it reads the same on
// light and dark tabs.
const favicon = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
<rect width="100" height="100" fill="#DBDAD2"/>
<rect x="14" y="47" width="52" height="6" rx="1" fill="#111111"/><rect x="60" y="48" width="40" height="4" fill="#111111"/>
<rect x="22" y="41" width="5" height="18" rx="1.5" fill="#111111"/><rect x="26.7" y="35" width="7.3" height="30" rx="1.5" fill="#111111"/>
<rect x="33.7" y="23" width="9.3" height="54" rx="1.5" fill="#FF4F00"/>
<rect x="42.7" y="15" width="10.3" height="70" rx="1.5" fill="#111111"/><rect x="52.7" y="15" width="10.3" height="70" rx="1.5" fill="#111111"/>
</svg>
`;
writeFileSync(resolve(gen, "favicon.svg"), favicon);
copyFileSync(resolve(repo, "marketing/feature_graphic.png"), resolve(gen, "og.png"));
console.log(
  `synced listing (${content.screenshots.length} slides, ${changelog.length} releases, latest ${changelog[0]?.version ?? "none"}, ${library.templates.length} library templates) into web/src/generated + web/public/generated`,
);
