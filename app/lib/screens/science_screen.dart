/// The receipts: every number the app prescribes, where it comes from,
/// and links to the actual research. Reachable from onboarding (pushed
/// over the flow, back pops) and from the main menu.
library;

import '../widgets/common/flat.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class ScienceScreen extends StatelessWidget {
  const ScienceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: PageTitle('🧠 Workout science')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Schlift trains you for muscle growth. Every number (sets, '
            'reps, rest, weight) comes from the research below. One '
            'rule filters it all: keep it simple enough that you do it.',
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const _Section(
            title: 'Weekly volume: 10–20 sets per muscle',
            body:
                'More weekly hard sets grow more muscle, up to a limit. '
                'Ten or more sets per muscle clearly beat fewer. The '
                'benefit fades past about twenty. That is the band on the '
                'home screen. A set counts 1.0 for the muscle that drives '
                'the movement and 0.5 for each helper.',
            citations: [
              _Citation(
                'Schoenfeld, Ogborn & Krieger (2017): dose-response of '
                    'weekly sets on muscle growth',
                'https://pubmed.ncbi.nlm.nih.gov/27433992/',
              ),
              _Citation(
                'Baz-Valle et al. (2022): systematic review of weekly '
                    'volume per muscle group',
                'https://pubmed.ncbi.nlm.nih.gov/35291645/',
              ),
            ],
          ),
          const _Section(
            title: 'Effort: the reps decide',
            body:
                'Sets only count if they are hard, but you never have to '
                'rate them. Hitting every target rep is the only signal. '
                'The weight climbs each session you hit them all, so sets '
                'get hard on their own, and a missed rep says you got '
                'there. Sets close to failure grow muscle like full '
                'failure does, with less fatigue.',
            citations: [
              _Citation(
                'Grgic et al. (2022): training to failure vs not, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/33497853/',
              ),
            ],
          ),
          const _Section(
            title: 'Sets and reps: 5×5, 3×8–12',
            body:
                'Effort decides growth, not the exact load, so the '
                'numbers are practical. Barbell compounds are 5 sets of 5 '
                '(deadlifts 3 of 5): heavy enough for strength, enough '
                'sets for size. Other loaded work is 3 sets of 8–12, '
                'bodyweight 3 of 5–15, core 3 of 10–20.',
            citations: [
              _Citation(
                'Schoenfeld et al. (2017): low- vs high-load training, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/28834797/',
              ),
            ],
          ),
          const _Section(
            title: 'Rest: 3:00 / 2:30 / 2:00 / 1:30 / 1:00',
            body:
                'Short rest cuts your next set, which cuts growth. Three '
                'minutes beat one minute in trials. Rest goes where it '
                'pays: 3:00 on lower-body barbell lifts, 2:30 on '
                'upper-body barbell lifts, 2:00 on other compounds, 1:30 '
                'on isolation, 1:00 on core. Starting early is always '
                'allowed.',
            citations: [
              _Citation(
                'Schoenfeld et al. (2016): 3 min vs 1 min rest, '
                    'randomized trial',
                'https://pubmed.ncbi.nlm.nih.gov/26605807/',
              ),
              _Citation(
                'Grgic et al. (2017): rest interval review for '
                    'hypertrophy',
                'https://pubmed.ncbi.nlm.nih.gov/28933024/',
              ),
            ],
          ),
          const _Section(
            title: 'Progression: hit every rep',
            body:
                'On a 5×5, every rep of every set means one small step '
                'up next time. In a rep range, clear every set and the '
                'rep target climbs by one; top the range and the weight '
                'takes a step while reps reset. Adding reps grows muscle '
                'about as well as adding load. Progression always follows '
                'what you actually lifted.',
            citations: [
              _Citation(
                'Plotkin et al. (2022): load progression vs repetition '
                    'progression',
                'https://pubmed.ncbi.nlm.nih.gov/36199287/',
              ),
              _Citation(
                'ACSM (2009): progression models in resistance training',
                'https://pubmed.ncbi.nlm.nih.gov/19204579/',
              ),
            ],
          ),
          const _Section(
            title: 'Misses and deloads',
            body:
                'Miss a rep and the weight holds. Everyone has bad days. '
                'Miss three sessions in a row and the weight drops 10%, '
                'then climbs past the stall. Grinding a stuck weight '
                'forever is how progress dies.',
            citations: [],
          ),
          const _Section(
            title: 'Finding your weight',
            body:
                'A lift you have never logged starts light, in sets of '
                '5, each about 10% heavier than the last. The first '
                'missed rep ends it: your working sets start at 90% of '
                'the heaviest set you did in full. Five reps to failure '
                'is about 85% of your max; a 5×5 sits around 75–80%.',
            citations: [],
          ),
          const _Section(
            title: 'Time off: 3 and 6 weeks',
            body:
                'Strength holds for about three weeks without training, '
                'then fades. Back after 3 weeks away from a lift, it '
                'starts at 90%; after 6 weeks, at 80%. Your old numbers '
                'come back fast.',
            citations: [
              _Citation(
                'Bosquet et al. (2013): training cessation and muscular '
                    'performance, meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/23347054/',
              ),
            ],
          ),
          const _Section(
            title: 'Recovery windows: 48 / 36 / 24 hours',
            body:
                'Muscle rebuilds for roughly 24–48 hours after training. '
                'Big muscles show ready after ~48 h, arms and delts after '
                '~36 h, calves and core after ~24 h. Training early is '
                'allowed. The amber marker is information, not a gate.',
            citations: [
              _Citation(
                'MacDougall et al. (1995): muscle protein synthesis '
                    'time course after training',
                'https://pubmed.ncbi.nlm.nih.gov/8563679/',
              ),
              _Citation(
                'Schoenfeld, Grgic & Krieger (2019): training frequency '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/30558493/',
              ),
            ],
          ),
          const _Section(
            title: 'Warmups',
            body:
                'Barbell compounds get four warmup sets at roughly '
                '40/55/70/85% of the working weight. Walking up to a '
                'heavy bar cold is how injuries happen. Light isolation '
                'work needs none. The first set is its own warmup.',
            citations: [],
          ),
          const _Section(
            title: 'Starting weights, and what gender changes',
            body:
                'First weights are seeded from bodyweight, experience '
                'and gender. At the same bodyweight, women average ~52% '
                'of men\u2019s upper-body strength and ~66% lower-body. So '
                'upper-body seeds scale to ~60% and lower-body to ~75%. '
                'Gender changes nothing else. Relative gains are similar '
                'between sexes, so the program is identical. The seed is '
                'only a guess: progression finds your real weight in 2–3 '
                'sessions.',
            citations: [
              _Citation(
                'Miller et al. (1993): sex differences in strength: '
                    '~52% upper body, ~66% lower body',
                'https://pubmed.ncbi.nlm.nih.gov/8477683/',
              ),
              _Citation(
                'Nuzzo (2023): comprehensive review of sex differences '
                    'in muscle strength and size',
                'https://pubmed.ncbi.nlm.nih.gov/36696264/',
              ),
              _Citation(
                'Roberts et al. (2020): sex differences in resistance '
                    'training response, meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/32218059/',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: context.tokens.br(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Honesty note: effect sizes in this research are modest '
              'and most studies are short. Good programs differ little. '
              'The one variable that beats all others is showing up. '
              'That is why Schlift optimises for simplicity.',
              style: TextStyle(
                fontSize: context.tokens.size.body,
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
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.heavy,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: context.tokens.size.body,
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
                    Icon(AppIcons.openExternal, size: 14, color: cs.tertiary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        citation.label,
                        style: TextStyle(
                          fontSize: context.tokens.size.small,
                          height: 1.4,
                          fontWeight: context.tokens.weight.bold,
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
