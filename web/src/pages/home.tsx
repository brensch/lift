import { Link } from "react-router-dom";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import { ArrowRight, ChevronDown } from "lucide-react";
import { useReveal } from "@/lib/useReveal";
import { formatReleaseDate } from "@/lib/format";
import { cn } from "@/lib/utils";
import { CONTENT, site } from "@/content";
import { FeatureArt } from "@/components/feature-art";
import { MuscleTracker } from "@/components/muscle-tracker";

// The page has no copy of its own: every string is store/listing.yaml (see
// src/content.ts). Layout only.

/** How many of the latest release's changes the home page shows. */
const WHATS_NEW_SHOWN = 6;

const APP_STORE = {
  url: "https://apps.apple.com/us/app/schlift/id6761754276",
  label: site("app_store_button"),
};
const PLAY_STORE = {
  url: "https://play.google.com/store/apps/details?id=com.brensch.schlift",
  label: site("play_store_button"),
};

const ua = typeof navigator !== "undefined" ? navigator.userAgent : "";
const isIOS =
  /iPhone|iPad|iPod/i.test(ua) ||
  // iPadOS 13+ reports as a Mac, so disambiguate with touch support.
  (typeof navigator !== "undefined" &&
    navigator.platform === "MacIntel" &&
    navigator.maxTouchPoints > 1);
const isAndroid = /Android/i.test(ua);

// Show the user's store if we can tell what they're on; otherwise show both.
const stores = isIOS ? [APP_STORE] : isAndroid ? [PLAY_STORE] : [APP_STORE, PLAY_STORE];

function Reveal({
  children,
  className,
  delay = 0,
}: {
  children: React.ReactNode;
  className?: string;
  delay?: number;
}) {
  const { ref, visible } = useReveal();
  return (
    <div
      ref={ref}
      className={cn(
        visible ? "animate-reveal-up motion-reduce:animate-none" : "opacity-0 translate-y-12",
        className,
      )}
      style={visible ? { animationDelay: `${delay}ms` } : undefined}
    >
      {children}
    </div>
  );
}

function StoreButtons({ size = "lg" }: { size?: "lg" | "default" }) {
  return (
    <div className="flex gap-3 flex-wrap justify-center">
      {stores.map((store) => (
        <a key={store.url} href={store.url} className="no-underline">
          <Button variant="primary" size={size} className="group">
            {store.label}
            <ArrowRight
              size={16}
              className="ml-2 transition-transform group-hover:translate-x-0.5"
            />
          </Button>
        </a>
      ))}
    </div>
  );
}

function Eyebrow({ children }: { children: React.ReactNode }) {
  return <p className="text-xs uppercase tracking-[0.2em] text-muted/60 mb-3">{children}</p>;
}

export function HomePage() {
  const { about, testimonials, otherFeatures, screenshots, changelog } = CONTENT;
  const latest = changelog[0];

  return (
    <div className="flex flex-col overflow-hidden">
      {/* Hero */}
      <section className="relative flex flex-col items-center justify-center text-center px-5 min-h-[calc(100vh-4rem)]">
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="absolute -top-[30%] -left-[10%] w-[60vw] h-[60vw] rounded-full bg-ok/[0.05] blur-[120px]" />
          <div className="absolute -bottom-[20%] -right-[10%] w-[50vw] h-[50vw] rounded-full bg-primary/[0.04] blur-[120px]" />
        </div>

        <div className="relative z-10 flex flex-col items-center">
          <div className="opacity-0" style={{ animation: "fade-in 0.8s ease-out 0.1s forwards" }}>
            <h1 className="font-mono text-[clamp(3.5rem,11vw,8rem)] font-bold tracking-[-0.02em] leading-[0.85] m-0">
              <WobblyText text={CONTENT.name.toUpperCase()} seed={42} />
            </h1>
          </div>

          <p
            className="mt-7 font-display text-2xl md:text-3xl font-bold tracking-tight m-0 opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.3s forwards" }}
          >
            {CONTENT.tagline}
          </p>

          <p
            className="mt-4 text-lg md:text-xl text-muted max-w-md leading-relaxed opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.45s forwards" }}
          >
            {CONTENT.promotionalText}
          </p>

          <div
            className="mt-10 opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.6s forwards" }}
          >
            <StoreButtons />
          </div>

          <p
            className="mt-4 text-xs tracking-wide uppercase text-muted/50 opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.8s forwards" }}
          >
            {site("under_buttons")}
          </p>
        </div>

        <div
          className="absolute bottom-8 opacity-0"
          style={{ animation: "fade-in 1s ease-out 1.2s forwards" }}
        >
          <ChevronDown size={20} className="text-muted/30 animate-bounce" />
        </div>
      </section>

      {/* Screenshots — the store slides, same captions */}
      {screenshots.length > 0 && (
        <section className="border-y border-border/50 bg-surface/30 py-20">
          <div className="max-w-5xl mx-auto px-5">
            <Reveal>
              <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0 mb-10">
                {site("screenshots_heading")}
              </h2>
            </Reveal>
          </div>
          <Reveal delay={100}>
            <div
              className="flex gap-6 overflow-x-auto snap-x snap-mandatory pb-4"
              style={{
                scrollbarWidth: "none",
                // Line the first slide up with the heading's left edge (the
                // 64rem content column) and let the rest run off to the right.
                paddingInline: "max(1.25rem, calc((100vw - 64rem) / 2 + 1.25rem))",
                scrollPaddingInline: "max(1.25rem, calc((100vw - 64rem) / 2 + 1.25rem))",
              }}
            >
              {screenshots.map((s) => (
                <figure
                  key={s.src}
                  className="snap-start shrink-0 w-[260px] sm:w-[300px] m-0 flex flex-col"
                >
                  {s.device === "watch" ? (
                    // A round Wear OS capture: no phone frame, centred in
                    // the height the phone slides take.
                    <div className="flex-1 flex items-center">
                      <img
                        src={s.src}
                        alt={s.title}
                        loading="lazy"
                        className="block w-full h-auto rounded-full shadow-[0_24px_64px_rgba(17,17,17,0.18)]"
                      />
                    </div>
                  ) : (
                    <div className="rounded-[2rem] border border-border bg-surface p-2 shadow-[0_24px_64px_rgba(17,17,17,0.18)]">
                      <img
                        src={s.src}
                        alt={s.title}
                        loading="lazy"
                        className="block w-full h-auto rounded-[1.6rem]"
                      />
                    </div>
                  )}
                  <figcaption className="mt-5">
                    <h3 className="font-display font-bold text-lg tracking-tight m-0">{s.title}</h3>
                    {s.subtitle && (
                      <p className="text-sm text-muted leading-relaxed mt-1 mb-0">{s.subtitle}</p>
                    )}
                  </figcaption>
                </figure>
              ))}
            </div>
          </Reveal>
        </section>
      )}

      {/* About — the opening of the store description, beside the real thing */}
      <section className="max-w-5xl mx-auto px-5 py-24 w-full grid grid-cols-1 md:grid-cols-[1fr_22rem] gap-12 items-center">
        <Reveal>
          {about.map((p, i) => (
            <p
              key={i}
              className={cn(
                "leading-relaxed m-0",
                i === 0
                  ? "font-display text-2xl md:text-3xl font-bold tracking-tight"
                  : "mt-6 text-lg text-muted",
              )}
            >
              {p}
            </p>
          ))}
        </Reveal>
        <Reveal delay={120} className="w-full max-w-sm mx-auto">
          <MuscleTracker />
        </Reveal>
      </section>

      {/* Testimonials */}
      {testimonials.length > 0 && (
        <section className="border-t border-border/50 bg-surface/30 py-24 px-5">
          <div className="max-w-5xl mx-auto">
            <Reveal>
              <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0 mb-10">
                {CONTENT.testimonialsHeading}
              </h2>
            </Reveal>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
              {testimonials.map((t, i) => (
                <Reveal key={t.name} delay={i * 100}>
                  <blockquote className="m-0 h-full border border-border rounded-2xl bg-surface p-7 flex flex-col">
                    <p className="font-display text-xl font-bold tracking-tight leading-snug m-0 flex-1">
                      “{t.quote}”
                    </p>
                    <footer className="mt-6 text-sm text-muted">— {t.name}</footer>
                  </blockquote>
                </Reveal>
              ))}
            </div>
          </div>
        </section>
      )}

      {/* Other features — its own section */}
      {otherFeatures.items.length > 0 && (
        <section className="border-t border-border/50 py-24 px-5">
          <div className="max-w-5xl mx-auto">
            <Reveal>
              <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0 mb-10 max-w-2xl">
                {otherFeatures.heading}
              </h2>
            </Reveal>
            {/* A box each: the picture edge to edge on the left, a rule, the words. */}
            <ul className="list-none p-0 m-0 grid grid-cols-1 md:grid-cols-2 gap-5">
              {otherFeatures.items.map((item, i) => (
                <li key={i} className="min-w-0">
                  <Reveal
                    delay={i * 80}
                    className="h-full min-h-44 flex border border-border rounded-2xl bg-surface overflow-hidden"
                  >
                    {item.picture && (
                      <div className="relative shrink-0 w-[38%] max-w-52 bg-background border-r border-border overflow-hidden">
                        <FeatureArt picture={item.picture} />
                      </div>
                    )}
                    <p className="m-0 p-6 self-center leading-relaxed">{item.text}</p>
                  </Reveal>
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}

      {/* Companion dashboard */}
      <section className="border-t border-border/50 py-24 px-5">
        <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-2 gap-12 items-center">
          <Reveal>
            <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0">
              {site("companion_heading")}
            </h2>
            <p className="mt-5 text-muted leading-relaxed max-w-md">{site("companion_text")}</p>
            <div className="mt-7 flex gap-3 flex-wrap">
              <Link to="/demo" className="no-underline">
                <Button variant="primary" className="group">
                  {site("companion_demo_button")}
                  <ArrowRight
                    size={16}
                    className="ml-2 transition-transform group-hover:translate-x-0.5"
                  />
                </Button>
              </Link>
              <Link to="/login" className="no-underline">
                <Button>{site("companion_signin_button")}</Button>
              </Link>
            </div>
          </Reveal>

          <Reveal delay={120}>
            {/* The dashboard itself, small, in a browser window: a capture
                of /demo (make web-preview). */}
            <Link
              to="/demo"
              aria-label={site("companion_demo_button")}
              className="group block border border-border rounded-2xl bg-surface overflow-hidden no-underline transition-transform hover:-translate-y-1"
            >
              <div className="flex items-center gap-1.5 px-3.5 py-2.5 border-b border-border">
                {[0, 1, 2].map((dot) => (
                  <span key={dot} className="w-2.5 h-2.5 rounded-full bg-border" />
                ))}
                <span className="ml-3 flex-1 rounded-md bg-background px-3 py-1 font-mono text-[0.7rem] text-muted truncate">
                  schlift.com/dashboard
                </span>
              </div>
              <img
                src="/dashboard-preview.png"
                alt=""
                width={1920}
                height={1290}
                loading="lazy"
                className="block w-full h-auto"
              />
            </Link>
          </Reveal>
        </div>
      </section>

      {/* What's new — the latest release, from the change log */}
      {latest && (
        <section className="border-t border-border/50 bg-surface/30 py-20 px-5">
          <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-5 gap-10">
            <Reveal className="md:col-span-2">
              <Eyebrow>{site("whats_new_heading")}</Eyebrow>
              <h2 className="font-display text-3xl font-bold tracking-tight m-0">
                {latest.version}
              </h2>
              <p className="mt-2 text-sm text-muted">{formatReleaseDate(latest.date)}</p>
            </Reveal>
            <Reveal delay={100} className="md:col-span-3">
              <ul className="list-none p-0 m-0 space-y-3">
                {latest.changes.slice(0, WHATS_NEW_SHOWN).map((line, i) => (
                  <li key={i} className="text-muted leading-relaxed">
                    {line}
                  </li>
                ))}
              </ul>
              <Link
                to="/changes"
                className="group mt-6 inline-flex items-center text-sm font-semibold text-text no-underline hover:underline"
              >
                {site("whats_new_all_button")}
                <ArrowRight
                  size={14}
                  className="ml-1.5 transition-transform group-hover:translate-x-0.5"
                />
              </Link>
            </Reveal>
          </div>
        </section>
      )}

      {/* Final CTA */}
      <section className="relative py-28 px-5 text-center overflow-hidden">
        <div className="pointer-events-none absolute inset-0">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[60vw] h-[30vw] rounded-full bg-ok/[0.06] blur-[100px]" />
        </div>
        <Reveal className="relative z-10">
          <h2 className="font-display text-4xl md:text-5xl font-bold tracking-tight m-0">
            {site("cta_heading")}
          </h2>
          <p className="mt-4 text-muted max-w-sm mx-auto leading-relaxed">{site("cta_text")}</p>
          <div className="mt-8">
            <StoreButtons />
          </div>
        </Reveal>
      </section>
    </div>
  );
}
