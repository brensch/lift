import { useEffect, useRef, useState } from "react";
import { WobblyText } from "@/components/wobbly-text";
import { Button } from "@/components/ui/button";
import {
  Dumbbell,
  Users,
  BarChart3,
  Watch,
  ChevronDown,
  ArrowRight,
  Clock,
  Calendar,
  TrendingUp,
  Target,
  ExternalLink,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { useReveal } from "@/lib/useReveal";
import { cn } from "@/lib/utils";
import { settingsClient } from "@/lib/grpc";
import type { TrainingProgramDefinition } from "@/gen/workout/v1/settings_pb";

const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
const storeUrl = isIOS
  ? "https://apps.apple.com/app/schlift-workout-tracker/id6742123456"
  : "https://play.google.com/store/apps/details?id=com.brensch.schlift";
const storeLabel = isIOS ? "Download on App Store" : "Get it on Google Play";

const features = [
  {
    icon: Dumbbell,
    title: "Smart Programming",
    desc: "Built-in progression schemes — 5x5, GZCLP, Wendler 5/3/1. Weights auto-adjust based on your performance.",
  },
  {
    icon: Users,
    title: "Train Together",
    desc: "Real-time multiplayer sessions. See who's up next, share the rack, keep each other honest.",
  },
  {
    icon: BarChart3,
    title: "Track Everything",
    desc: "Every set, rep, and rest period logged. Watch your numbers climb over weeks and months.",
  },
  {
    icon: Watch,
    title: "Wear OS",
    desc: "Control your workout from your wrist. Start sets, log reps, see what's next — no phone needed.",
  },
];

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
        visible
          ? "animate-reveal-up motion-reduce:animate-none"
          : "opacity-0 translate-y-12",
        className,
      )}
      style={visible ? { animationDelay: `${delay}ms` } : undefined}
    >
      {children}
    </div>
  );
}

function ProgramCard({ program }: { program: TrainingProgramDefinition }) {
  const glance = program.atAGlance;
  return (
    <div className="min-w-[360px] max-w-[420px] flex-shrink-0 border border-border rounded-2xl bg-surface p-8 flex flex-col snap-center">
      <div className="mb-4">
        <h3 className="font-display text-2xl font-bold tracking-tight m-0">
          {program.displayName}
        </h3>
        <p className="text-base text-muted mt-1.5">{program.headline}</p>
      </div>

      <p className="text-base text-muted leading-relaxed mb-6 flex-1">
        {program.summary}
      </p>

      {glance && (
        <div className="grid grid-cols-2 gap-3 mb-6">
          {glance.daysPerWeek && (
            <div className="flex items-center gap-2 text-sm text-muted">
              <Calendar size={15} className="text-muted/60 shrink-0" />
              {glance.daysPerWeek} days/wk
            </div>
          )}
          {glance.averageSessionTime && (
            <div className="flex items-center gap-2 text-sm text-muted">
              <Clock size={15} className="text-muted/60 shrink-0" />
              {glance.averageSessionTime}
            </div>
          )}
          {glance.bestFor && (
            <div className="flex items-center gap-2 text-sm text-muted">
              <Target size={15} className="text-muted/60 shrink-0" />
              {glance.bestFor}
            </div>
          )}
          {glance.progressionStyle && (
            <div className="flex items-center gap-2 text-sm text-muted">
              <TrendingUp size={15} className="text-muted/60 shrink-0" />
              {glance.progressionStyle}
            </div>
          )}
        </div>
      )}

      {program.details.length > 0 && (
        <ul className="space-y-2 mb-6">
          {program.details.slice(0, 3).map((d, i) => (
            <li
              key={i}
              className="text-sm text-muted leading-relaxed flex items-start gap-2"
            >
              <span className="text-muted/40 mt-0.5 shrink-0">-</span>
              {d}
            </li>
          ))}
        </ul>
      )}

      {program.learnMoreLinks.length > 0 && (
        <div className="flex flex-wrap gap-2 mt-auto pt-2 border-t border-border/50">
          {program.learnMoreLinks.map((link, i) => (
            <a
              key={i}
              href={link.url}
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-muted hover:text-text transition-colors no-underline flex items-center gap-1"
            >
              {link.label}
              <ExternalLink size={12} />
            </a>
          ))}
        </div>
      )}
    </div>
  );
}

function ProgramsCarousel({
  programs,
}: {
  programs: TrainingProgramDefinition[];
}) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;

    let frame = 0;

    const updateScrollState = () => {
      frame = 0;
      const nextCanScrollLeft = el.scrollLeft > 4;
      const nextCanScrollRight =
        el.scrollLeft < el.scrollWidth - el.clientWidth - 4;

      setCanScrollLeft((prev) =>
        prev === nextCanScrollLeft ? prev : nextCanScrollLeft,
      );
      setCanScrollRight((prev) =>
        prev === nextCanScrollRight ? prev : nextCanScrollRight,
      );
    };

    const scheduleUpdate = () => {
      if (frame) return;
      frame = requestAnimationFrame(updateScrollState);
    };

    updateScrollState();
    el.addEventListener("scroll", scheduleUpdate, { passive: true });

    const ro = new ResizeObserver(scheduleUpdate);
    ro.observe(el);

    return () => {
      if (frame) cancelAnimationFrame(frame);
      el.removeEventListener("scroll", scheduleUpdate);
      ro.disconnect();
    };
  }, [programs]);

  function scroll(dir: number) {
    scrollRef.current?.scrollBy({ left: dir * 420, behavior: "smooth" });
  }

  return (
    <div className="relative overflow-hidden">
      {/* Scroll buttons */}
      {canScrollLeft && (
        <button
          onClick={() => scroll(-1)}
          className="absolute left-2 top-1/2 -translate-y-1/2 z-10 w-9 h-9 rounded-full bg-surface border border-border flex items-center justify-center text-muted hover:text-text transition-colors shadow-lg"
        >
          <ChevronLeft size={16} />
        </button>
      )}
      {canScrollRight && (
        <button
          onClick={() => scroll(1)}
          className="absolute right-2 top-1/2 -translate-y-1/2 z-10 w-9 h-9 rounded-full bg-surface border border-border flex items-center justify-center text-muted hover:text-text transition-colors shadow-lg"
        >
          <ChevronRight size={16} />
        </button>
      )}

      {/* Edge fades */}
      {canScrollLeft && (
        <div className="pointer-events-none absolute left-0 top-0 bottom-0 w-20 z-[5] bg-gradient-to-r from-surface/30 via-surface/15 to-transparent" />
      )}
      {canScrollRight && (
        <div className="pointer-events-none absolute right-0 top-0 bottom-0 w-20 z-[5] bg-gradient-to-l from-surface/30 via-surface/15 to-transparent" />
      )}

      <div
        ref={scrollRef}
        className="flex gap-5 overflow-x-auto scrollbar-hide snap-x snap-mandatory pb-2"
        style={{
          scrollbarWidth: "none",
          WebkitMaskImage:
            canScrollLeft && canScrollRight
              ? "linear-gradient(to right, transparent 0, black 5rem, black calc(100% - 5rem), transparent 100%)"
              : canScrollLeft
                ? "linear-gradient(to right, transparent 0, black 5rem, black 100%)"
                : canScrollRight
                  ? "linear-gradient(to right, black 0, black calc(100% - 5rem), transparent 100%)"
                  : undefined,
          maskImage:
            canScrollLeft && canScrollRight
              ? "linear-gradient(to right, transparent 0, black 5rem, black calc(100% - 5rem), transparent 100%)"
              : canScrollLeft
                ? "linear-gradient(to right, transparent 0, black 5rem, black 100%)"
                : canScrollRight
                  ? "linear-gradient(to right, black 0, black calc(100% - 5rem), transparent 100%)"
                  : undefined,
        }}
      >
        {programs.map((p) => (
          <ProgramCard key={p.regimeType} program={p} />
        ))}

        {/* "More to come" card */}
        <div className="min-w-[360px] max-w-[420px] flex-shrink-0 border border-dashed border-border/60 rounded-2xl p-8 flex flex-col items-center justify-center text-center snap-center">
          <div className="w-12 h-12 rounded-xl bg-white/[0.04] border border-white/[0.06] flex items-center justify-center mb-5">
            <Dumbbell
              size={20}
              className="text-muted/40"
              strokeWidth={1.5}
            />
          </div>
          <h3 className="font-display font-bold text-xl tracking-tight m-0 text-muted/60">
            More to come
          </h3>
          <p className="text-base text-muted/40 mt-3 leading-relaxed">
            New programs are in development. Got a request? Let us know.
          </p>
        </div>
      </div>
    </div>
  );
}

export function HomePage() {
  const [programs, setPrograms] = useState<TrainingProgramDefinition[]>([]);

  useEffect(() => {
    settingsClient
      .getTrainingProgramCatalog({})
      .then((resp) => setPrograms(resp.programs))
      .catch(() => {
        // Catalog fetch failed — page still works, just no program cards
      });
  }, []);

  return (
    <div className="flex flex-col overflow-hidden">
      {/* Hero — full viewport */}
      <section className="relative flex flex-col items-center justify-center text-center px-5 min-h-[calc(100vh-4rem)]">
        {/* Gradient orbs */}
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="absolute -top-[30%] -left-[10%] w-[60vw] h-[60vw] rounded-full bg-white/[0.02] blur-[100px]" />
          <div className="absolute -bottom-[20%] -right-[10%] w-[50vw] h-[50vw] rounded-full bg-white/[0.015] blur-[120px]" />
        </div>

        <div className="relative z-10 flex flex-col items-center">
          <div
            className="opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.1s forwards" }}
          >
            <h1 className="font-display text-[clamp(4rem,12vw,9rem)] font-black tracking-[-0.06em] leading-[0.85] m-0">
              <WobblyText text="SCHLIFT" seed={42} />
            </h1>
          </div>

          <p
            className="mt-6 text-lg md:text-xl text-muted max-w-md leading-relaxed opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.4s forwards" }}
          >
            Yap with friends, we tell you what weight to lift next. 
          </p>

          <div
            className="mt-10 flex gap-3 flex-wrap justify-center opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.6s forwards" }}
          >
            <a href={storeUrl} className="no-underline">
              <Button variant="primary" size="lg" className="group">
                {storeLabel}
                <ArrowRight
                  size={16}
                  className="ml-2 transition-transform group-hover:translate-x-0.5"
                />
              </Button>
            </a>
          </div>

          <p
            className="mt-4 text-xs tracking-wide uppercase text-muted/50 opacity-0"
            style={{ animation: "fade-in 0.8s ease-out 0.8s forwards" }}
          >
            Free. No ads. No subscription.
          </p>
        </div>

        {/* Scroll hint */}
        <div
          className="absolute bottom-8 opacity-0"
          style={{ animation: "fade-in 1s ease-out 1.2s forwards" }}
        >
          <ChevronDown size={20} className="text-muted/30 animate-bounce" />
        </div>
      </section>

      {/* Programs — horizontal scroll carousel */}
      {programs.length > 0 && (
        <section className="border-y border-border/50 bg-surface/30 py-20 px-5">
          <div className="max-w-5xl mx-auto">
            <Reveal>
              <p className="text-xs uppercase tracking-[0.2em] text-muted/60 mb-3">
                Programs
              </p>
              <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0 mb-12">
                Real progression schemes.
                <br />
                <span className="text-muted">Not just a notepad.</span>
              </h2>
            </Reveal>
            <Reveal delay={100} className="mt-12">
              <ProgramsCarousel programs={programs} />
            </Reveal>
          </div>
        </section>
      )}

      {/* Features — staggered scroll reveal */}
      <section className="max-w-5xl mx-auto px-5 py-24 w-full">
        <Reveal>
          <p className="text-xs uppercase tracking-[0.2em] text-muted/60 mb-3">
            Features
          </p>
          <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0 max-w-md">
            Everything you need.
            <br />
            <span className="text-muted">Nothing you don't.</span>
          </h2>
        </Reveal>

        <div className="mt-14 grid grid-cols-1 sm:grid-cols-2 gap-5">
          {features.map((f, i) => (
            <Reveal key={f.title} delay={i * 100}>
              <div className="group relative border border-border rounded-2xl bg-surface p-7 transition-colors duration-300 hover:border-border/80 hover:bg-surface-hover h-full">
                <div className="flex items-center gap-3 mb-4">
                  <div className="flex items-center justify-center w-10 h-10 rounded-xl bg-white/[0.04] border border-white/[0.06]">
                    <f.icon
                      className="w-5 h-5 text-muted group-hover:text-text transition-colors duration-300"
                      strokeWidth={1.5}
                    />
                  </div>
                  <h3 className="font-display font-bold text-lg tracking-tight m-0">
                    {f.title}
                  </h3>
                </div>
                <p className="text-sm text-muted leading-relaxed m-0">
                  {f.desc}
                </p>
              </div>
            </Reveal>
          ))}
        </div>
      </section>

      {/* How it works */}
      <section className="border-t border-border/50 py-24 px-5">
        <div className="max-w-5xl mx-auto">
          <Reveal>
            <p className="text-xs uppercase tracking-[0.2em] text-muted/60 mb-3">
              How it works
            </p>
            <h2 className="font-display text-3xl md:text-4xl font-bold tracking-tight m-0">
              Three taps to your first set.
            </h2>
          </Reveal>

          <div className="mt-14 grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              {
                step: "01",
                title: "Pick a program",
                desc: "Choose from 5x5, GZCLP, or Wendler 5/3/1. Set your starting weights.",
              },
              {
                step: "02",
                title: "Follow the plan",
                desc: "Schlift tells you exactly what to lift. Hit your reps, log it, move on.",
              },
              {
                step: "03",
                title: "Get stronger",
                desc: "Weights go up automatically. Failed a set? The program adapts.",
              },
            ].map((item, i) => (
              <Reveal key={item.step} delay={i * 120}>
                <div className="relative">
                  <span className="font-display text-5xl font-black text-white/[0.04] leading-none">
                    {item.step}
                  </span>
                  <h3 className="font-display font-bold text-lg tracking-tight mt-2 mb-2">
                    {item.title}
                  </h3>
                  <p className="text-sm text-muted leading-relaxed m-0">
                    {item.desc}
                  </p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      {/* Final CTA */}
      <section className="relative py-28 px-5 text-center overflow-hidden">
        {/* Background glow */}
        <div className="pointer-events-none absolute inset-0">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[60vw] h-[30vw] rounded-full bg-white/[0.02] blur-[100px]" />
        </div>

        <Reveal className="relative z-10">
          <h2 className="font-display text-4xl md:text-5xl font-bold tracking-tight m-0">
            Ready to lift?
          </h2>
          <p className="mt-4 text-muted max-w-sm mx-auto leading-relaxed">
            Download Schlift and start your first session in under a minute.
          </p>
          <div className="mt-8">
            <a href={storeUrl} className="no-underline">
              <Button variant="primary" size="lg" className="group">
                Get the App
                <ArrowRight
                  size={16}
                  className="ml-2 transition-transform group-hover:translate-x-0.5"
                />
              </Button>
            </a>
          </div>
        </Reveal>
      </section>
    </div>
  );
}
