/// The receipts: every number the app plans, where it comes from,
/// and links to the actual research. Reachable from onboarding (pushed
/// over the flow, back pops) and from the main menu.
library;

import '../widgets/common/flat.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../gen/copy.dart';
import '../theme/theme_spec.dart';
import '../theme/app_icons.dart';

class ScienceScreen extends StatelessWidget {
  const ScienceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: PageTitle(copy.science.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            copy.science.intro,
            style: TextStyle(
              fontSize: context.tokens.size.body,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const _Section(
            'kinds',
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
            'max',
            citations: [
              _Citation(
                'Grgic et al. (2022): training to failure vs not, '
                    'meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/33497853/',
              ),
            ],
          ),
          const _Section(
            'reps',
            citations: [
              _Citation(
                'Plotkin et al. (2022): load progression vs repetition '
                    'progression',
                'https://pubmed.ncbi.nlm.nih.gov/36199287/',
              ),
            ],
          ),
          const _Section(
            'sets',
            citations: [
              _Citation(
                'Schoenfeld, Ogborn & Krieger (2017): dose-response of '
                    'weekly sets on muscle growth',
                'https://pubmed.ncbi.nlm.nih.gov/27433992/',
              ),
            ],
          ),
          const _Section(
            'volume',
            citations: [
              _Citation(
                'Baz-Valle et al. (2022): systematic review of weekly '
                    'volume per muscle group',
                'https://pubmed.ncbi.nlm.nih.gov/35291645/',
              ),
            ],
          ),
          const _Section(
            'time_off',
            citations: [
              _Citation(
                'Bosquet et al. (2013): training cessation and muscular '
                    'performance, meta-analysis',
                'https://pubmed.ncbi.nlm.nih.gov/23347054/',
              ),
            ],
          ),
          const _Section('first_time', citations: []),
          const _Section('overrides', citations: []),
          const _Section('no_drops', citations: []),
          const _Section('warmups', citations: []),
          const _Section(
            'recovery',
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
              borderRadius: context.tokens.brMd,
              border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            ),
            child: Text(
              copy.science.honesty,
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
  /// Which of copy.science.sections this is.
  final String id;
  final List<_Citation> citations;

  const _Section(this.id, {required this.citations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final words = copy.science.sections.firstWhere((s) => s.id == id);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            words.title,
            style: TextStyle(
              fontSize: context.tokens.size.bodyLg,
              fontWeight: context.tokens.weight.heavy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            words.body,
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
