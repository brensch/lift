// Every word on the landing page comes from store/listing.yaml, via
// scripts/sync-content.mjs → src/generated/content.json. Edit the YAML, not
// the components.
import content from "./generated/content.json";

export type Testimonial = { quote: string; name: string };
export type Screenshot = {
  src: string;
  title: string;
  subtitle: string;
  device: "phone" | "watch";
};
export type Release = {
  version: string;
  /** YYYY-MM-DD. */
  date: string;
  changes: string[];
};
export type LibraryGroup = { key: string; label: string };
export type LibraryTemplate = {
  id: string;
  name: string;
  group: string;
  blurb: string;
  isDefault: boolean;
  /** Exercise enum names without the EXERCISE_ prefix, as written in the YAML. */
  exercises: string[];
};

export type Content = {
  name: string;
  tagline: string;
  promotionalText: string;
  /** Opening paragraphs of the store description. */
  about: string[];
  testimonialsHeading: string;
  testimonials: Testimonial[];
  otherFeatures: { heading: string; items: { picture: string; text: string }[] };
  website: Record<string, string>;
  screenshots: Screenshot[];
  /** Every release, newest first, with everything that changed in it. */
  changelog: Release[];
  /** templates/library.yaml, for the /routines page. */
  library: { groups: LibraryGroup[]; templates: LibraryTemplate[] };
};

export const CONTENT = content as Content;

/** A site-only line from the `website:` section, or the key itself so a
 *  missing line is obvious on the page rather than silently blank. */
export function site(key: string): string {
  return CONTENT.website[key] ?? `[website.${key}]`;
}
