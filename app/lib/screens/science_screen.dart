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
            'Every number I give you comes from a study below. Where the '
            'studies disagree, I went with the simpler option.',
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const _Section(
            title: 'Weekly volume: 10–20 sets per muscle',
            body:
                'Ten hard sets a week per muscle beats fewer. Past '
                'twenty you\'re mostly just tired. That\'s the band on '
                'the home screen.',
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
            title: 'Effort',
            body:
                'You don\'t rate anything. The weight goes up until '
                'you miss a rep, which is how I know it was hard. '
                'Close to failure grows about as much as failure, and '
                'hurts less.',
            citations: [
              _Citation(
                'Grgic et al. (2022): training to failure vs not, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/33497853/',
              ),
            ],
          ),
          const _Section(
            title: 'Sets and reps',
            body:
                'Barbell lifts are 5×5 (deadlifts 3×5). Everything '
                'else is 3×8–12. Effort matters more than the exact '
                'numbers, so I picked easy ones.',
            citations: [
              _Citation(
                'Schoenfeld et al. (2017): low- vs high-load training, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/28834797/',
              ),
            ],
          ),
          const _Section(
            title: 'Rest',
            body:
                'Three minutes beats one. Big lower-body lifts get '
                '3:00, down to 1:00 for core. Start early if you '
                'want, I won\'t tell anyone.',
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
            title: 'Progression',
            body:
                'Hit every rep and it goes up next time. In a rep '
                'range the reps climb first, then the weight. More '
                'reps works about as well as more weight.',
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
                'Miss a rep and the weight stays. Miss three sessions '
                'in a row and it drops 10%, then climbs back past '
                'where you got stuck.',
            citations: [],
          ),
          const _Section(
            title: 'Finding your weight',
            body:
                'A new lift starts light and goes up 10% a set until '
                'you miss. Your working weight is 90% of the last set '
                'you finished.',
            citations: [],
          ),
          const _Section(
            title: 'Time off',
            body:
                'Strength holds for about three weeks. Gone longer '
                'and I start you at 90%, or 80% after six. It comes '
                'back fast.',
            citations: [
              _Citation(
                'Bosquet et al. (2013): training cessation and muscular '
                    'performance, meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/23347054/',
              ),
            ],
          ),
          const _Section(
            title: 'Recovery',
            body:
                'Big muscles take about 48 hours, arms and shoulders '
                '36, calves and core 24. The amber marker is a '
                'suggestion, not a bouncer.',
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
                'Barbell lifts get four warmup sets, at 40, 55, 70 '
                'and 85%. Light stuff doesn\'t need one.',
            citations: [],
          ),
          const _Section(
            title: 'Gender',
            body:
                'Women average about 52% of men\'s upper-body strength '
                'and 66% lower, so starting weights are scaled down. '
                'That\'s the only difference. It\'s a first guess, and '
                'two or three sessions fix it either way.',
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
              'Honestly, the effects are small and the studies are short. '
              'Turning up beats everything above.',
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
