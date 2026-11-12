// The little pictures beside the "it also has" features on the home page:
// one contrived scene each, drawn in the site's own colours so they follow
// the theme. `picture` in store/listing.yaml names which one an item gets.

const INK = "var(--color-text)";
const MUTED = "var(--color-muted)";
const LINE = "var(--color-border)";
const PAPER = "var(--color-surface)";
const HOT = "var(--color-primary)";
const MONO = "var(--font-mono, ui-monospace, monospace)";

/** Two people in one session: one mid-set, one talking. */
function Multiplayer() {
  const row = (y: number, name: string, state: string, lifting: boolean) => (
    <g transform={`translate(22 ${y})`}>
      <rect width="156" height="58" rx="6" fill={PAPER} stroke={LINE} />
      <circle cx="29" cy="29" r="15" fill={lifting ? HOT : "none"} stroke={lifting ? HOT : INK} />
      <text x="54" y="26" fontFamily={MONO} fontSize="11" fontWeight="700" fill={INK}>
        {name}
      </text>
      <rect
        x="54"
        y="33"
        width={state.length * 6.4 + 12}
        height="15"
        rx="3"
        fill={lifting ? HOT : "none"}
        stroke={lifting ? HOT : MUTED}
      />
      <text
        x="60"
        y="44"
        fontFamily={MONO}
        fontSize="9"
        fontWeight="700"
        letterSpacing="0.6"
        fill={lifting ? "var(--color-on-primary)" : MUTED}
      >
        {state}
      </text>
    </g>
  );
  return (
    <>
      {row(36, "YOU", "LIFTING", true)}
      {row(106, "KENNETH", "YAPPING 4:12", false)}
    </>
  );
}

/** A lift going up over the months. */
function History() {
  const points: [number, number][] = [
    [26, 150],
    [52, 138],
    [78, 142],
    [104, 112],
    [130, 96],
    [156, 70],
    [178, 48],
  ];
  const path = points.map(([x, y], i) => `${i ? "L" : "M"}${x} ${y}`).join(" ");
  return (
    <>
      {[60, 100, 140].map((y) => (
        <line key={y} x1="20" x2="184" y1={y} y2={y} stroke={LINE} strokeDasharray="2 5" />
      ))}
      <line x1="20" x2="184" y1="168" y2="168" stroke={INK} />
      <path d={`${path} L178 168 L26 168 Z`} fill={HOT} opacity="0.12" />
      <path d={path} fill="none" stroke={HOT} strokeWidth="3" strokeLinejoin="round" />
      {points.slice(0, -1).map(([x, y]) => (
        <circle key={x} cx={x} cy={y} r="3" fill={PAPER} stroke={HOT} strokeWidth="2" />
      ))}
      <circle cx="178" cy="48" r="6" fill={HOT} />
      <text x="20" y="34" fontFamily={MONO} fontSize="20" fontWeight="700" fill={INK}>
        225
        <tspan fontSize="10" fill={MUTED} dx="4">
          LB
        </tspan>
      </text>
    </>
  );
}

/** A shelf of saved workouts, the newest one just kept. */
function Saved() {
  const card = (y: number, title: string, lifts: number, kept: boolean) => (
    <g transform={`translate(24 ${y})`}>
      <rect width="152" height="44" rx="6" fill={PAPER} stroke={kept ? HOT : LINE} />
      <text x="12" y="19" fontFamily={MONO} fontSize="10" fontWeight="700" fill={INK}>
        {title}
      </text>
      {Array.from({ length: lifts }, (_, i) => (
        <rect key={i} x={12 + i * 20} y="27" width="15" height="6" rx="3" fill={LINE} />
      ))}
      {kept && <path d="M128 10 h12 v22 l-6 -5 l-6 5 Z" fill={HOT} />}
    </g>
  );
  return (
    <>
      {card(28, "THAT SICK ONE", 5, true)}
      {card(80, "LEG DAY", 4, false)}
      {card(132, "BUTT AGAIN", 3, false)}
    </>
  );
}

/** A watch showing the pulse. */
function HeartRate() {
  return (
    <>
      {/* The strap runs off the top and bottom of whatever box this is in. */}
      <rect x="74" y="-400" width="52" height="1000" fill={LINE} />
      <circle cx="100" cy="100" r="66" fill={INK} />
      <circle cx="100" cy="100" r="58" fill="none" stroke={MUTED} strokeWidth="1" />
      <path
        d="M52 108 h20 l7 -26 l10 46 l8 -32 l6 12 h45"
        fill="none"
        stroke={HOT}
        strokeWidth="3"
        strokeLinejoin="round"
        strokeLinecap="round"
      />
      <text
        x="100"
        y="78"
        textAnchor="middle"
        fontFamily={MONO}
        fontSize="24"
        fontWeight="700"
        fill={PAPER}
      >
        142
      </text>
      <text
        x="100"
        y="146"
        textAnchor="middle"
        fontFamily={MONO}
        fontSize="9"
        letterSpacing="1.5"
        fill={PAPER}
        opacity="0.7"
      >
        BPM
      </text>
    </>
  );
}

const PICTURES: Record<string, () => React.ReactNode> = {
  multiplayer: Multiplayer,
  history: History,
  saved: Saved,
  heart_rate: HeartRate,
};

/** The drawing, whole and centred in its box, as large as fits. */
export function FeatureArt({ picture }: { picture: string }) {
  const Picture = PICTURES[picture];
  if (!Picture) return null;
  return (
    <svg
      viewBox="0 0 200 200"
      preserveAspectRatio="xMidYMid meet"
      overflow="visible"
      aria-hidden="true"
      className="absolute inset-0 w-full h-full block"
    >
      <Picture />
    </svg>
  );
}
