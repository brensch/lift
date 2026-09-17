// Every word on the landing page comes from store/listing.yaml, via
// scripts/sync-content.mjs → src/generated/content.json. Edit the YAML, not
// the components.
import content from "./generated/content.json";

export type Testimonial = { quote: string; name: string };
export type Screenshot = { src: string; title: string; subtitle: string };

export type Content = {
  name: string;
  tagline: string;
  promotionalText: string;
  /** Opening paragraphs of the store description. */
  about: string[];
  testimonialsHeading: string;
  testimonials: Testimonial[];
  otherFeatures: { heading: string; items: string[] };
  website: Record<string, string>;
  screenshots: Screenshot[];
  whatsNew: { version: string; lines: string[] } | null;
};

export const CONTENT = content as Content;

/** A site-only line from the `website:` section, or the key itself so a
 *  missing line is obvious on the page rather than silently blank. */
export function site(key: string): string {
  return CONTENT.website[key] ?? `[website.${key}]`;
}
