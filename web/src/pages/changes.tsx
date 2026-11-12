import { WobblyText } from "@/components/wobbly-text";
import { CONTENT, site } from "@/content";
import { formatReleaseDate } from "@/lib/format";

/**
 * Every release and everything that changed in it, newest first: the change
 * log (changes/<version>.md), as written by the changes themselves.
 */
export function ChangesPage() {
  return (
    <div className="max-w-3xl mx-auto px-5 py-12">
      <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
        <WobblyText text={site("changes_heading").toUpperCase()} seed={83} />
      </h1>
      <p className="mt-2 text-muted">{site("changes_text")}</p>

      <ol className="list-none p-0 mt-10 mb-0 border-b border-border">
        {CONTENT.changelog.map((release) => (
          <li
            key={release.version}
            id={`v${release.version}`}
            className="border-t border-border py-7 grid grid-cols-1 sm:grid-cols-[9rem_1fr] gap-x-8 gap-y-3"
          >
            <div>
              <h2 className="font-mono text-lg font-bold tracking-tight m-0">{release.version}</h2>
              <p className="mt-1 mb-0 text-sm text-muted">{formatReleaseDate(release.date)}</p>
            </div>
            <ul className="list-none p-0 m-0 space-y-2">
              {release.changes.map((change, i) => (
                <li key={i} className="flex gap-3 leading-relaxed text-[0.95rem]">
                  <span aria-hidden="true" className="shrink-0 text-primary font-mono">
                    +
                  </span>
                  <span className="min-w-0 break-words">{change}</span>
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ol>
    </div>
  );
}
