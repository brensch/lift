/// The receipts: every number the app plans, where it comes from,
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
            'Every number I give you comes from one estimate per lift and '
            'the time you said you have. The studies behind it are below.',
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const _Section(
            title: 'Three kinds of lift',
            body:
                'Barbell compounds are heavy: 5–8 reps, 3:00 rest, warmups '
                'first. Every other loaded lift is 8–12 reps with 2:00. '
                'Bodyweight and core are 5–15 reps with 1:30. Heavy is '
                'better for strength. For size, anything from about 6 to 30 '
                'reps works if it\'s hard. Long rest beats short on the big '
                'lifts.',
            citations: [
              _Citation(
                'Schoenfeld et al. (2017): low- vs high-load training, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/28834797/',
              ),
              _Citation(
                'Schoenfeld et al. (2016): 3 min vs 1 min rest, '
                    'randomized trial',
                'https://pubmed.ncbi.nlm.nih.gov/26605807/',
              ),
            ],
          ),
          const _Section(
            title: 'Your estimated max',
            body:
                'Each lift has one number: the most I think you could lift '
                'once. For bodyweight lifts it\'s the most reps in a set. I '
                'work it out from every set you\'ve logged, assuming one rep '
                'left in the tank and a bit of fatigue per set. Hit every '
                'rep and it goes up a rep\'s worth. Miss one and it drops to '
                'what you actually showed. Stop early, or lower the weight '
                'yourself, and it stays put.',
            citations: [
              _Citation(
                'Grgic et al. (2022): training to failure vs not, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/33497853/',
              ),
            ],
          ),
          const _Section(
            title: 'Reps and weight',
            body:
                'I keep you at the weight you did last time, for as many '
                'reps as your max covers. Past the top of the range, the '
                'weight goes up a step. Under the bottom, it comes down to '
                'what you can do. So you add a rep a session, then a '
                'plate. More reps works about as well as more weight.',
            citations: [
              _Citation(
                'Plotkin et al. (2022): load progression vs repetition '
                    'progression',
                'https://pubmed.ncbi.nlm.nih.gov/36199287/',
              ),
            ],
          ),
          const _Section(
            title: 'Sets: from your time',
            body:
                'You tell me how long you have on the home screen. Sixty '
                'minutes unless you say otherwise. Every lift gets two '
                'sets. The rest go one at a time, five at most, to whichever '
                'muscle is furthest under ten sets this week. I time your '
                'sets and rests, and once I have ten of each I use yours '
                'instead of my guesses. If two sets each won\'t fit, I tell '
                'you how long it needs.',
            citations: [
              _Citation(
                'Schoenfeld, Ogborn & Krieger (2017): dose-response of '
                    'weekly sets on muscle growth',
                'https://pubmed.ncbi.nlm.nih.gov/27433992/',
              ),
            ],
          ),
          const _Section(
            title: 'Weekly volume: 10–20 sets per muscle',
            body:
                'Ten hard sets a week per muscle beats fewer. Past twenty '
                'you\'re mostly just tired. That\'s the band on the home '
                'screen.',
            citations: [
              _Citation(
                'Baz-Valle et al. (2022): systematic review of weekly '
                    'volume per muscle group',
                'https://pubmed.ncbi.nlm.nih.gov/35291645/',
              ),
            ],
          ),
          const _Section(
            title: 'Time off',
            body:
                'Strength holds for about three weeks. Away from a lift '
                'longer than that and I cut its max to 90%. Six weeks, 80%. '
                'It comes back fast.',
            citations: [
              _Citation(
                'Bosquet et al. (2013): training cessation and muscular '
                    'performance, meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/23347054/',
              ),
            ],
          ),
          const _Section(
            title: 'The first time',
            body:
                'A lift you\'ve never done starts from the weight your '
                'emoji picked, or wherever you tell me to start. Sets of 5 '
                'from 60% of it, 10% heavier each '
                'set, until you miss a rep. Six sets at most. Get all 5 and '
                'I ask how many more you had in you. 0–1 and we\'re done '
                'there. 2–4, the next set goes up as usual. 5+, it jumps '
                'about a fifth, to roughly one rep short of what you '
                'showed. Or type exactly how much to add and the next set '
                'goes up by that. Don\'t answer and it goes up as usual. '
                'The set you '
                'missed, or the one you said 0–1 on, tells me your max, and '
                'the rest of the workout comes from that. Bodyweight lifts '
                'start at the bottom of the range.',
            citations: [],
          ),
          const _Section(
            title: 'Your own numbers',
            body:
                'Tap a lift in a workout\'s editor to give it your own '
                'weight and reps, and sets if you want. I work out the max '
                'that means and carry on from there. Take them off and I '
                'go back to your history.',
            citations: [],
          ),
          const _Section(
            title: 'No automatic drops',
            body:
                'I never lower a weight during a workout. Missed reps? Rest '
                'and go again. Cooked? Lower it yourself. I\'ll take the '
                'hint next time.',
            citations: [],
          ),
          const _Section(
            title: 'Warmups',
            body:
                'Heavy lifts get four warmup sets at about 40, 55, 70 and '
                '85% of the working weight. Everything else warms itself '
                'up.',
            citations: [],
          ),
          const _Section(
            title: 'Recovery',
            body:
                'Big muscles take about 48 hours, arms and shoulders 36, '
                'calves and core 24. The amber marker is a suggestion, not '
                'a bouncer.',
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: context.tokens.br(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Honesty note: the effects in these studies are small and '
              'most of them are short. Good programs barely differ. '
              'Showing up beats all of it, so I kept it simple.',
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
