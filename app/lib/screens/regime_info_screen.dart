import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen/workout/v1/settings.pb.dart';
import '../providers/settings_provider.dart';

class RegimeInfoScreen extends StatelessWidget {
  final RegimeType regimeType;

  const RegimeInfoScreen({super.key, required this.regimeType});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final info = provider.trainingProgramFor(regimeType);
    if (info == null) {
      return const Scaffold(
        body: Center(child: Text('Training program info unavailable')),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(info.displayName), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text(
            info.headline,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (info.summary.isNotEmpty)
            Text(
              info.summary,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          if (info.summary.isNotEmpty) const SizedBox(height: 10),
          Text(
            info.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 24),
          if (info.hasAtAGlance()) ...[
            _SectionLabel('AT A GLANCE'),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _AtAGlanceCard(
                  emoji: '📅',
                  label: 'Days / Week',
                  value: info.atAGlance.daysPerWeek,
                ),
                _AtAGlanceCard(
                  emoji: '🎯',
                  label: 'Best For',
                  value: info.atAGlance.bestFor,
                ),
                _AtAGlanceCard(
                  emoji: '⏱️',
                  label: 'Session Time',
                  value: info.atAGlance.averageSessionTime,
                ),
                _AtAGlanceCard(
                  emoji: '📈',
                  label: 'Progression',
                  value: info.atAGlance.progressionStyle,
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
          if (info.howItWorks.trim().isNotEmpty) ...[
            _SectionLabel('HOW IT WORKS'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Text(
                info.howItWorks.trim(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(height: 28),
          ],
          if (info.details.isNotEmpty) ...[
            _SectionLabel('DETAILS'),
            const SizedBox(height: 10),
            ...info.details.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: cs.primary)),
                    Expanded(child: Text(d, style: const TextStyle(height: 1.4))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (info.learnMoreLinks.isNotEmpty) ...[
            _SectionLabel('LEARN MORE'),
            const SizedBox(height: 10),
            ...info.learnMoreLinks
                .map((link) => _LinkTile(label: link.label, url: link.url)),
          ],
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
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}

class _AtAGlanceCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  const _AtAGlanceCard({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.primary),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }
}
