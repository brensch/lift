// The app's muscle tracker, redrawn with a contrived week: sets done per
// muscle in the last seven days against the 10–20 band. It follows the
// app's own row (app/lib/screens/home/home_screen.dart, _VolumeRow): the bar
// and the number go green inside the band, and the muscles the suggested
// workout trains are named in orange.

const TRACK_MAX = 24;
const LOW = 10;
const HIGH = 20;

/** [muscle, sets this week, trained by the suggested workout] */
const WEEK: [string, number, boolean][] = [
  ["Chest", 3, true],
  ["Back", 12, false],
  ["Delts", 10.5, false],
  ["Biceps", 4.5, false],
  ["Triceps", 7.5, false],
  ["Quads", 6, true],
  ["Hams", 13.5, false],
  ["Glutes", 18, false],
  ["Calves", 0, false],
  ["Core", 1.5, true],
];

const share = (sets: number) => `${(Math.min(sets, TRACK_MAX) / TRACK_MAX) * 100}%`;

export function MuscleTracker() {
  return (
    <div
      role="img"
      aria-label="The app's muscle tracker: sets done this week for each muscle group, with back, delts, hams and glutes in the green target range and chest, quads and core picked out as what to train next."
      className="border border-border rounded-2xl bg-surface px-6 py-5 flex flex-col gap-3.5 select-none"
    >
      {WEEK.map(([muscle, sets, targeted]) => {
        const inBand = sets >= LOW && sets <= HIGH;
        return (
          <div key={muscle} className="flex items-center gap-3">
            <span
              className="w-20 shrink-0 font-bold text-lg leading-none"
              style={{ color: targeted ? "var(--color-primary)" : "var(--color-text)" }}
            >
              {muscle}
            </span>
            <span className="relative flex-1 h-2 rounded-sm bg-border/40">
              {/* The 10–20 band, and the tick at its floor. */}
              <span
                className="absolute inset-y-0 bg-ok/20"
                style={{ left: share(LOW), width: share(HIGH - LOW) }}
              />
              <span
                className="absolute inset-y-0.5 left-0 rounded-sm"
                style={{
                  width: share(sets),
                  background: inBand ? "var(--color-ok)" : "var(--color-muted)",
                }}
              />
              <span className="absolute inset-y-0 w-0.5 bg-text/30" style={{ left: share(LOW) }} />
            </span>
            <span
              className="w-10 shrink-0 text-right font-extrabold text-lg leading-none [font-variant-numeric:tabular-nums]"
              style={{ color: inBand ? "var(--color-ok)" : "var(--color-muted)" }}
            >
              {sets}
            </span>
          </div>
        );
      })}
    </div>
  );
}
