import { useEffect, useRef } from "react";

function seededRandom(seed: number) {
  let state = seed >>> 0;
  return function next() {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

export function WobblyText({
  text,
  seed = 42,
  className = "",
}: {
  text: string;
  seed?: number;
  className?: string;
}) {
  const ref = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const rng = seededRandom(seed);
    el.textContent = "";
    for (const ch of text) {
      const span = document.createElement("span");
      span.style.display = "inline-block";
      span.style.animation = `wobbly-move ${(10 + rng() * 8).toFixed(2)}s ease-in-out infinite`;
      span.style.animationDelay = `${(rng() * -18).toFixed(2)}s`;
      span.textContent = ch === " " ? "\u00A0" : ch;
      el.appendChild(span);
    }
  }, [text, seed]);

  return <span ref={ref} className={className} />;
}
