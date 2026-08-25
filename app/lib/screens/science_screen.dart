/// The receipts: every number the app prescribes, where it comes from,
/// and links to the actual research. Reachable from onboarding (pushed
/// over the flow, back pops) and from the main menu.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ScienceScreen extends StatelessWidget {
  const ScienceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🧠 Papers',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Schlift trains you for muscle growth. Every number it '
            'prescribes — sets, reps, rest, weight — comes from the '
            'hypertrophy research below, filtered through one rule: keep '
            'it simple enough that you actually do it.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const _Section(
            title: 'Weekly volume: 10–20 sets per muscle',
            body:
                'The clearest dose-response finding in hypertrophy '
                'research: more weekly hard sets grow more muscle, with '
                'diminishing returns. Meta-analysis puts 10+ weekly sets '
                'per muscle clearly ahead of fewer, and most additional '
                'benefit fades past ~20. That is the band on the home '
                'screen. A set counts 1.0 for the muscle that drives the '
                'movement and 0.5 for each muscle that assists — a common '
                'convention for counting indirect volume.',
            citations: [
              _Citation(
                'Schoenfeld, Ogborn & Krieger (2017) — dose-response of '
                    'weekly sets on muscle growth',
                'https://pubmed.ncbi.nlm.nih.gov/27433992/',
              ),
              _Citation(
                'Baz-Valle et al. (2022) — systematic review of weekly '
                    'volume per muscle group',
                'https://pubmed.ncbi.nlm.nih.gov/35291645/',
              ),
            ],
          ),
          const _Section(
            title: 'Effort: stop 1–2 reps before failure',
            body:
                'Sets only count if they are hard. Training close to '
                'failure produces similar growth to training to absolute '
                'failure, with less fatigue to recover from — so the '
                'prescription assumes you stop with about 1–2 clean reps '
                'left. If you finish a set knowing you had 5 more, it was '
                'a warmup.',
            citations: [
              _Citation(
                'Grgic et al. (2022) — training to failure vs not, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/33497853/',
              ),
            ],
          ),
          const _Section(
            title: 'Rep ranges: 6–10, 8–12, 10–15',
            body:
                'Muscle grows across a wide load range — light and heavy '
                'sets produce similar hypertrophy when effort is matched. '
                'Rep ranges are therefore chosen for practicality, not '
                'magic: 6–10 on barbell compounds (heavy enough to '
                'progress load cleanly, light enough to keep form), 8–12 '
                'on other compounds, 10–15 on isolation work where tiny '
                'weight increments are impossible, and 10–20 for core.',
            citations: [
              _Citation(
                'Schoenfeld et al. (2017) — low- vs high-load training, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/28834797/',
              ),
            ],
          ),
          const _Section(
            title: 'Rest: 3:00 / 2:30 / 2:00 / 1:30 / 1:00',
            body:
                'Longer rest beats short rest for growth — cutting rest '
                'cuts the weight you can lift on the next set, which cuts '
                'the stimulus. Three minutes outperformed one minute for '
                'both size and strength. Schlift spends rest where it '
                'pays: 3:00 on barbell lifts that load the lower body '
                '(squats, hinges — they tax the whole system), 2:30 on '
                'upper-body barbell lifts, 2:00 on other compounds, 1:30 '
                'on isolation, 1:00 on core. The timer is advisory — '
                'starting early is always allowed.',
            citations: [
              _Citation(
                'Schoenfeld et al. (2016) — 3 min vs 1 min rest, '
                    'randomized trial',
                'https://pubmed.ncbi.nlm.nih.gov/26605807/',
              ),
              _Citation(
                'Grgic et al. (2017) — rest interval review for '
                    'hypertrophy',
                'https://pubmed.ncbi.nlm.nih.gov/28933024/',
              ),
            ],
          ),
          const _Section(
            title: 'Progression: reps first, then load',
            body:
                'Progressive overload is the engine of adaptation, but '
                '"overload" includes reps, not just weight. Schlift uses '
                'double progression: clear every set and the rep target '
                'climbs; top the rep range on every set and the weight '
                'takes one small equipment step while reps reset to the '
                'bottom. Adding reps at a fixed load grows muscle about '
                'as well as adding load — so the app progresses whichever '
                'is available, and a mid-session weight change counts, '
                'because progression follows what you actually lifted.',
            citations: [
              _Citation(
                'Plotkin et al. (2022) — load progression vs repetition '
                    'progression',
                'https://pubmed.ncbi.nlm.nih.gov/36199287/',
              ),
              _Citation(
                'ACSM (2009) — progression models in resistance training',
                'https://pubmed.ncbi.nlm.nih.gov/19204579/',
              ),
            ],
          ),
          const _Section(
            title: 'Misses and deloads',
            body:
                'One missed session holds the weight — everyone has bad '
                'days. Two misses in a row on the same exercise drops it '
                '10% and rebuilds through the rep range. This is standard '
                'autoregulation practice rather than the finding of a '
                'specific trial: grinding a stuck weight forever is how '
                'progress (and enthusiasm) dies.',
            citations: [],
          ),
          const _Section(
            title: 'Recovery windows: 48 / 36 / 24 hours',
            body:
                'Muscle protein synthesis stays elevated for roughly '
                '24–48 hours after training, and meta-analysis finds '
                'frequency itself matters little once weekly volume is '
                'matched — so the windows exist to spread quality work, '
                'not to gate you. Schlift marks big muscles (chest, back, '
                'legs, glutes) ready after ~48 h, arms and delts after '
                '~36 h, calves and core after ~24 h. Training a muscle '
                'early is allowed; the amber marker just tells you it '
                'may not be at full strength.',
            citations: [
              _Citation(
                'MacDougall et al. (1995) — muscle protein synthesis '
                    'time course after training',
                'https://pubmed.ncbi.nlm.nih.gov/8563679/',
              ),
              _Citation(
                'Schoenfeld, Grgic & Krieger (2019) — training frequency '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/30558493/',
              ),
            ],
          ),
          const _Section(
            title: 'Warmups',
            body:
                'Barbell compounds get a four-step ladder (roughly '
                '40/55/70/85% of the working weight) because walking up '
                'to a heavy squat cold is how injuries happen. Isolation '
                'and machine work starts light enough that the first '
                'working set is its own preparation. This is standard '
                'practice; the exact percentages are convention, chosen '
                'to land on plates you can actually load.',
            citations: [],
          ),
          const _Section(
            title: 'Starting weights, and what gender changes',
            body:
                'First-session weights are seeded from your bodyweight, '
                'experience and gender. The gender part follows the '
                'measured population differences: at the same bodyweight, '
                'women average roughly half to two-thirds of men\u2019s '
                'upper-body strength but a clearly smaller gap in the '
                'lower body — so Schlift scales the upper-body barbell '
                'seeds to ~60% and the lower-body seeds to ~75%, and '
                'skipping the question splits the difference. That is '
                'ALL gender changes. Sets, reps, rest, the volume band '
                'and the progression rule are identical, on purpose: '
                'relative gains from resistance training are similar '
                'between sexes, so the program does not need to differ — '
                'only the starting guess does. Every seed is '
                'conservative and temporary: double progression finds '
                'your real weight within a couple of sessions.',
            citations: [
              _Citation(
                'Miller et al. (1993) — sex differences in strength: '
                    '~52% upper body, ~66% lower body',
                'https://pubmed.ncbi.nlm.nih.gov/8477683/',
              ),
              _Citation(
                'Nuzzo (2023) — comprehensive review of sex differences '
                    'in muscle strength and size',
                'https://pubmed.ncbi.nlm.nih.gov/36696264/',
              ),
              _Citation(
                'Roberts et al. (2020) — sex differences in resistance '
                    'training response, meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/32218059/',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Honesty note: effect sizes in this literature are modest, '
              'many studies are short, and the differences between good '
              'programs are small. The variable that dominates every '
              'other is whether you keep showing up — which is why '
              'Schlift optimises for simplicity first.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontStyle: FontStyle.italic,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  final List<_Citation> citations;

  const _Section({
    required this.title,
    required this.body,
    required this.citations,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          for (final citation in citations)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse(citation.url),
                  mode: LaunchMode.externalApplication,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: cs.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        citation.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: cs.tertiary,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Citation {
  final String label;
  final String url;
  const _Citation(this.label, this.url);
}
