import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gen/workout/v1/settings.pbenum.dart';

// ─── Regime info data ─────────────────────────────────────────────────────────

class _RegimeInfo {
  final RegimeType type;
  final String name;
  final String tagline;
  final String description;
  final List<(String, String)> stats; // (label, value)
  final String howItWorks;
  final List<(String, String)> links; // (label, url)

  const _RegimeInfo({
    required this.type,
    required this.name,
    required this.tagline,
    required this.description,
    required this.stats,
    required this.howItWorks,
    required this.links,
  });
}

const _regimes = [
  _RegimeInfo(
    type: RegimeType.REGIME_TYPE_LINEAR_5X5,
    name: 'Linear 5×5',
    tagline: 'The best beginner program.',
    description:
        'Linear 5×5 is the simplest and most battle-tested beginner program ever designed. '
        'You do 5 sets of 5 reps on the big compound lifts — Squat, Bench, Deadlift, Overhead Press, and Row. '
        'After every successful session you add weight. When you stall 3 times in a row, '
        'you deload 10% and rebuild momentum. Simple, effective, and proven.',
    stats: [
      ('Frequency', '3 days/week'),
      ('Style', 'Linear progression'),
      ('Best for', 'Beginners'),
      ('Session time', '~45 min'),
    ],
    howItWorks: '''
Week structure: Alternate between Workout A (Squat, Bench, Row) and Workout B (Squat, OHP, Deadlift) 3 days/week.

Progression: Add 2.5–5 kg per session to upper body lifts, 5–10 kg to lower body.

Failure: Miss all 5 reps in a set? Weight stays the same next session. Miss 3 sessions in a row at the same weight? Deload by 10%.

Long break: More than 2 weeks off? Automatically deloads 10–20% to ease back in safely.

The magic: Beginners can progress every single session because the CNS adapts faster than the muscles. This linear window closes eventually — that's when you graduate to GZCLP or Wendler.
''',
    links: [
      ('StrongLifts 5x5', 'https://stronglifts.com/5x5/'),
      ('Starting Strength', 'https://startingstrength.com'),
      ('Reddit: r/Fitness 5x5 FAQ', 'https://reddit.com/r/Fitness/wiki/faq/stronglifts5x5'),
    ],
  ),
  _RegimeInfo(
    type: RegimeType.REGIME_TYPE_GZCLP,
    name: 'GZCLP',
    tagline: 'Tier-based linear progression.',
    description:
        'Developed by powerlifter Cody Lefever, GZCLP (GZCL Linear Progression) organizes every exercise '
        'into 3 tiers based on intensity and volume. When you fail at one stage, the rep scheme shifts '
        'to a harder pattern that preserves the intensity while managing fatigue. '
        'This makes it far more resilient to stalls than simple linear programs.',
    stats: [
      ('Frequency', '4 days/week'),
      ('Style', 'Tiered state machine'),
      ('Best for', 'Intermediate lifters'),
      ('Session time', '60–90 min'),
    ],
    howItWorks: '''
T1 — Heavy Compounds (Squat, Deadlift):
  Stage 1: 5×3 with last set AMRAP. Success → +5–10 lbs, stay Stage 1.
  Stage 2: 6×2 with last set AMRAP. Triggered by Stage 1 failure. Success → +5–10 lbs, back to Stage 1.
  Stage 3: 10×1. Triggered by Stage 2 failure. Success → +5–10 lbs, back to Stage 1.
  Hard reset: If Stage 3 fails, reset to starting weight and Stage 1.

T2 — Supplemental Compounds (Bench, OHP, Row):
  Stage 1: 3×10. Success → +5 lbs, stay Stage 1.
  Stage 2: 3×8. Triggered by failure. Success → +5 lbs, back to Stage 1.
  Stage 3: 3×6. Triggered by failure. Success → +5 lbs, back to Stage 1.
  Hard reset: If Stage 3 fails, revert to last good Stage 1 weight.

T3 — Accessories (Hip Thrust, RDL, etc.): 3×15 simple linear progression.

The rule: For every 1 rep in T1, do 2+ reps in T2 and 3+ reps in T3.
''',
    links: [
      ('GZCLP Reddit Wiki', 'https://www.reddit.com/r/gzcl/wiki/gzclp'),
      ('Cody\'s Original Post', 'https://swoleateveryheight.blogspot.com/2016/02/gzcl-applications-adaptations.html'),
      ('Subreddit: r/gzcl', 'https://reddit.com/r/gzcl'),
    ],
  ),
  _RegimeInfo(
    type: RegimeType.REGIME_TYPE_WENDLER_531,
    name: 'Wendler 5/3/1',
    tagline: 'Slow, sustainable, built for years.',
    description:
        'Jim Wendler\'s 5/3/1 is one of the most popular intermediate/advanced programs ever written. '
        'You train off 90% of your true 1RM — your Training Max — which prevents CNS burnout. '
        'Each 4-week cycle follows a strict percentage wave: Volume → Intensity → Peak → Deload. '
        'After every cycle your Training Max goes up. Slow, boring, and it works forever.',
    stats: [
      ('Frequency', '4 days/week'),
      ('Style', 'Percentage periodization'),
      ('Best for', 'Intermediate / Advanced'),
      ('Session time', '45–75 min'),
    ],
    howItWorks: '''
Training Max (TM): 90% of your 1RM. All percentages calculated from this number.

4-Week Wave:
  Week 1 (Volume):    65%, 75%, 85% × TM — 5-rep sets, last set AMRAP
  Week 2 (Intensity): 70%, 80%, 90% × TM — 3-rep sets, last set AMRAP
  Week 3 (Peak):      75%, 85%, 95% × TM — 1-rep sets, last set AMRAP
  Week 4 (Deload):    40%, 50%, 60% × TM — 5-rep sets, easy recovery week

After each 4-week cycle:
  Upper body TM +5 lbs
  Lower body TM +10 lbs

The AMRAP set: The "plus" sets are where progress is measured. Blast them — more reps = stronger.

BBB (Boring But Big): Wendler's favourite accessory protocol adds 5×10 at 50–60% TM of the main lift after the main work for pure hypertrophy volume.
''',
    links: [
      ('Jim Wendler\'s Site', 'https://jimwendler.com'),
      ('5/3/1 Forever Book', 'https://jimwendler.com/collections/books-programs'),
      ('Reddit: r/531Discussion', 'https://reddit.com/r/531Discussion'),
    ],
  ),
];

_RegimeInfo? _infoForType(RegimeType type) {
  try {
    return _regimes.firstWhere((r) => r.type == type);
  } catch (_) {
    return null;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RegimeInfoScreen extends StatelessWidget {
  final RegimeType regimeType;

  const RegimeInfoScreen({super.key, required this.regimeType});

  @override
  Widget build(BuildContext context) {
    final info = _infoForType(regimeType);
    if (info == null) {
      return const Scaffold(body: Center(child: Text('Unknown regime')));
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(info.name),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Tagline
          Text(
            info.tagline,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            info.description,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),

          // Stats row
          _SectionLabel('AT A GLANCE'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: info.stats
                .map((s) => _StatChip(label: s.$1, value: s.$2))
                .toList(),
          ),
          const SizedBox(height: 28),

          // How it works
          _SectionLabel('HOW IT WORKS'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: Text(
              info.howItWorks.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                fontFamily: 'monospace',
                color: colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Learn more links
          _SectionLabel('LEARN MORE'),
          const SizedBox(height: 10),
          ...info.links.map(
            (link) => _LinkTile(label: link.$1, url: link.$2),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.tertiary,
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: cs.primary.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final String url;
  const _LinkTile({required this.label, required this.url});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.open_in_new_rounded,
                  size: 16, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      url,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
