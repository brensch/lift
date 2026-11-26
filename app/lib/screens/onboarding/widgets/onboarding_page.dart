/// The frame every setup step is drawn in, in the app's flat style: the
/// step's title and line at the top over a hairline, its sections full
/// width under that (heading bands, edge-to-edge rows), and its buttons
/// along the bottom over a hairline.
library;

import 'package:material_ui/material_ui.dart';

import '../../../gen/copy.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/theme_spec.dart';
import '../../../widgets/common/flat.dart';

class OnboardingPage extends StatelessWidget {
  final String title;
  final String? body;

  /// The [body] a size up: when it is the step's one point, not an aside.
  final bool bigBody;

  /// The step's sections, top to bottom.
  final List<Widget> children;

  /// The sections scroll; when false they fill the space between the title
  /// and the buttons instead (one of them [Expanded]).
  final bool scroll;

  /// Back to the step before; no Back button when null.
  final VoidCallback? onBack;
  final bool backEnabled;

  /// The button on the right: on to the next step, or finish.
  final Widget primary;

  /// A line over the buttons, when there is something to say there.
  final Widget? above;

  const OnboardingPage({
    super.key,
    required this.title,
    this.body,
    this.bigBody = false,
    required this.children,
    this.scroll = true,
    this.onBack,
    this.backEnabled = true,
    required this.primary,
    this.above,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final header = FlatSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: t.size.headline,
              fontWeight: t.weight.heavy,
              height: 1.15,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              style: TextStyle(
                fontSize: bigBody ? t.size.subtitle : t.size.body,
                height: 1.4,
                color: bigBody ? t.text : t.muted,
              ),
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: scroll
              ? ListView(padding: EdgeInsets.zero, children: children)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.hairline)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FlatSection.margin,
              12,
              FlatSection.margin,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (above != null) ...[above!, const SizedBox(height: 10)],
                Row(
                  children: [
                    if (onBack != null) ...[
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: backEnabled ? onBack : null,
                            child: Text(copy.onboarding.back),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: SizedBox(height: 56, child: primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The filled button that moves setup on: [label], or a spinner while
/// [busy].
class OnboardingNext extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const OnboardingNext({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            label,
            style: TextStyle(fontWeight: context.tokens.weight.heavy),
          ),
  );
}

/// One of a few choices as a full-width row: a [badge], its title over a
/// quieter line, and a tick when it is the one chosen. Rows stack with a
/// hairline between them, edge to edge.
class ChoiceRow extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const ChoiceRow({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.primary.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FlatSection.margin,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.hairline)),
          ),
          child: Row(
            children: [
              Text(
                badge,
                style: TextStyle(fontSize: t.size.headline, height: 1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: t.size.bodyLg,
                        fontWeight: t.weight.bold,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: t.size.small, color: t.muted),
                    ),
                  ],
                ),
              ),
              // Always there, only shown when chosen, so choosing doesn't
              // reflow the row.
              const SizedBox(width: 12),
              Visibility.maintain(
                visible: selected,
                child: Icon(
                  AppIcons.check,
                  size: t.size.title,
                  color: t.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
