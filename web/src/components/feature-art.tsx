// The little pictures beside the "it also has" features on the home page:
// one contrived scene each, drawn in the site's own colours so they follow
// the theme. `picture` in store/listing.yaml names which one an item gets.

const INK = "var(--color-text)";
const MUTED = "var(--color-muted)";
const LINE = "var(--color-border)";
const PAPER = "var(--color-surface)";
const HOT = "var(--color-primary)";
// Lifting, as the app colours it: a set under way.
const GO = "var(--color-ok)";
const MONO = "var(--font-mono, ui-monospace, monospace)";

/** Two people in one session: one mid-set, one talking. */
function Multiplayer() {
  const row = (y: number, name: string, state: string, lifting: boolean) => (
    <g transform={`translate(22 ${y})`}>
      <rect width="156" height="58" rx="6" fill={PAPER} stroke={LINE} />
      <circle cx="29" cy="29" r="15" fill={lifting ? GO : "none"} stroke={lifting ? GO : INK} />
      <text x="54" y="26" fontFamily={MONO} fontSize="11" fontWeight="700" fill={INK}>
        {name}
      </text>
      <rect
        x="54"
        y="33"
        width={state.length * 6.4 + 12}
        height="15"
        rx="3"
        fill={lifting ? GO : "none"}
        stroke={lifting ? GO : MUTED}
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
      <text x="20" y="28" fontFamily={MONO} fontSize="14" fontWeight="700" fill={INK}>
        225LB BENCH
      </text>
      <text x="20" y="43" fontFamily={MONO} fontSize="10" fill={MUTED}>
        sick bro
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
      {kept && <path d="M130 21 h10 v16 l-5 -4 l-5 4 Z" fill={HOT} />}
    </g>
  );
  return (
    <>
      {card(28, "CHEST - OF COURSE", 5, true)}
      {card(80, "LEG DAY (JK)", 4, false)}
      {card(132, "BUTT AGAIN", 3, false)}
    </>
  );
}

/** The watch app mid-set, as it looks on the wrist, pulse in the corner. */
function HeartRate() {
  const sets = [71, 90.4, 109.8, 129.2];
  return (
    <g transform="translate(100 100) scale(1.3) translate(-100 -100)">
      {/* The strap runs off the top and bottom of whatever box this is in. */}
      <rect x="70" y="-400" width="60" height="1000" fill={LINE} />
      <clipPath id="feature-watch-face">
        <circle cx="100" cy="100" r="70" />
      </clipPath>
      <g clipPath="url(#feature-watch-face)">
        <rect x="30" y="30" width="140" height="140" fill="var(--color-background)" />
        {/* The sets: done, the one being lifted, two to go. */}
        {sets.map((x, i) => (
          <g key={x}>
            <circle
              cx={x}
              cy="56.5"
              r="7.6"
              fill={i === 0 ? INK : i === 1 ? GO : "none"}
              stroke={i < 2 ? "none" : MUTED}
            />
            <text
              x={x}
              y="59"
              textAnchor="middle"
              fontFamily={MONO}
              fontSize="7"
              fontWeight="700"
              fill={i === 0 ? PAPER : i === 1 ? INK : MUTED}
            >
              8
            </text>
          </g>
        ))}
        <rect x="30" y="69.4" width="140" height="26" fill={GO} />
        <text x="44" y="86" fontFamily={MONO} fontSize="8.5" fontWeight="700" fill={INK}>
          LIFTING
        </text>
        <text
          x="159"
          y="88"
          textAnchor="end"
          fontFamily={MONO}
          fontSize="14"
          fontWeight="700"
          fill={INK}
        >
          0:22
        </text>
        <rect x="30" y="95.4" width="140" height="62" fill={PAPER} />
        <text x="39.5" y="105.5" fontSize="6" fill={MUTED}>
          Bench Press · Set 2 of 4
        </text>
        <line x1="30" x2="170" y1="110" y2="110" stroke={LINE} />
        <text x="46" y="134" fontFamily={MONO} fontSize="21" fontWeight="700" fill={INK}>
          135
        </text>
        <text x="87" y="134" fontFamily={MONO} fontSize="6" fontWeight="700" fill={INK}>
          lb
        </text>
        <text x="122" y="129" textAnchor="middle" fontFamily={MONO} fontSize="7" fill={INK}>
          ×
        </text>
        <circle cx="141" cy="126.5" r="13" fill={GO} />
        <text
          x="141"
          y="130.5"
          textAnchor="middle"
          fontFamily={MONO}
          fontSize="11"
          fontWeight="700"
          fill={INK}
        >
          8
        </text>
        <rect x="30" y="141.5" width="140" height="16" fill="var(--color-background)" />
        <line x1="30" x2="170" y1="141.5" y2="141.5" stroke={LINE} />
        <line x1="30" x2="170" y1="157.5" y2="157.5" stroke={LINE} />
        <line x1="85.4" x2="85.4" y1="141.5" y2="157.5" stroke={LINE} />
        <line x1="114.1" x2="114.1" y1="141.5" y2="157.5" stroke={LINE} />
        <text
          x="82"
          y="152"
          textAnchor="end"
          fontFamily={MONO}
          fontSize="6.5"
          fontWeight="700"
          fill={HOT}
        >
          ♥141
        </text>
        <text x="99.8" y="152" textAnchor="middle" fontFamily={MONO} fontSize="6.5" fill={INK}>
          27:01
        </text>
        <text x="128" y="152" textAnchor="middle" fontFamily={MONO} fontSize="6.5" fill={INK}>
          13:43
        </text>
      </g>
      <circle cx="100" cy="100" r="70" fill="none" stroke={INK} strokeWidth="3" />
    </g>
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
