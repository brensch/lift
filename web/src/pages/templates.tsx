import { WobblyText } from "@/components/wobbly-text";
import { CONTENT } from "@/content";
import type { LibraryTemplate } from "@/content";
import { Exercise } from "@/gen/workout/v1/workout_pb";
import { exerciseName } from "@/lib/exercises";

// Rendered from templates/library.yaml at build time (see
// scripts/sync-content.mjs). Nothing here is fetched from the backend.

/** Enum name as written in the YAML → display name. Unknown keys (an
 *  exercise added to the YAML before the web protos were regenerated) fall
 *  back to title-casing the string so the page never shows "Unknown". */
function displayName(key: string): string {
  const value = Exercise[key as keyof typeof Exercise];
  if (typeof value === "number" && value !== Exercise.UNSPECIFIED) {
    return exerciseName(value);
  }
  return key
    .toLowerCase()
    .split("_")
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(" ");
}

export function TemplatesPage() {
  const { groups, templates } = CONTENT.library;

  return (
    <div className="max-w-3xl mx-auto px-5 py-12">
      <div className="border border-border rounded-xl bg-surface p-6 md:p-10">
        <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
          <WobblyText text="TEMPLATES" seed={91} />
        </h1>
        <p className="mt-6 text-muted leading-relaxed">
          Every template in the app. Tick the ones you want when you sign up,
          add more any time from the Add chip. They're yours to edit once
          added.
        </p>

        {groups.map((group) => {
          const rows = templates.filter((t) => t.group === group.key);
          if (rows.length === 0) return null;
          return (
            <section key={group.key} className="mt-10">
              <h2 className="font-display text-lg font-bold tracking-tight m-0 mb-3">
                {group.label}
              </h2>
              <ul className="list-none p-0 m-0 divide-y divide-border">
                {rows.map((t) => (
                  <TemplateRow key={t.id} template={t} />
                ))}
              </ul>
            </section>
          );
        })}
      </div>
    </div>
  );
}

function TemplateRow({ template }: { template: LibraryTemplate }) {
  return (
    <li className="py-4 grid gap-1 sm:grid-cols-[minmax(0,11rem)_1fr] sm:gap-x-6">
      <div className="min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="font-semibold text-text">{template.name}</span>
          {template.isDefault && (
            <span className="inline-block rounded-md border border-ok/40 bg-ok/10 px-1.5 py-0.5 text-[0.65rem] font-semibold uppercase tracking-wider text-ok">
              Default
            </span>
          )}
        </div>
        {template.blurb && (
          <p className="m-0 mt-0.5 text-sm text-muted leading-snug">
            {template.blurb}
          </p>
        )}
      </div>
      {/* content-start/items-start: the grid stretches this cell to the height
          of the blurb beside it, and a wrapping flex row would otherwise
          stretch its chips to fill that. */}
      <ol className="m-0 mt-2 sm:mt-0 p-0 list-none flex flex-wrap content-start items-start gap-1.5 text-[0.85rem] text-muted">
        {template.exercises.map((e, i) => (
          <li
            key={`${e}-${i}`}
            className="rounded-md border border-border bg-background/60 px-2 py-0.5 whitespace-nowrap"
          >
            {displayName(e)}
          </li>
        ))}
      </ol>
    </li>
  );
}
