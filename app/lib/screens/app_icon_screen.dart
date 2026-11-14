/// Settings → App icon: pick the launcher icon by the stage it is coloured
/// for, like picking a character. The icon is drawn big at the top and its
/// coloured plate changes as each one is tapped; the button under the list
/// makes it the phone's icon.
library;

import 'package:flutter/material.dart';

import '../gen/copy.dart';
import '../services/app_icon.dart';
import '../theme/theme_spec.dart';
import '../widgets/common/flat.dart';

class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  /// The phone's icon now (null until it has been asked), and the one
  /// picked on this page.
  AppIconChoice? _current;
  AppIconChoice _picked = AppIconChoice.ready;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    AppIconService.current().then((current) {
      if (!mounted) return;
      setState(() {
        _current = current;
        _picked = current;
      });
    });
  }

  Future<void> _use() async {
    setState(() => _saving = true);
    final done = await AppIconService.set(_picked);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (done) _current = _picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = copy.appIcon;
    Color colourOf(AppIconChoice choice) => switch (choice) {
      AppIconChoice.ready => t.ready,
      AppIconChoice.lifting => t.lifting,
      AppIconChoice.resting => t.resting,
      AppIconChoice.yapping => t.yapping,
    };
    String lineOf(AppIconChoice choice) => switch (choice) {
      AppIconChoice.ready => c.ready,
      AppIconChoice.lifting => c.lifting,
      AppIconChoice.resting => c.resting,
      AppIconChoice.yapping => c.yapping,
    };
    String stageOf(AppIconChoice choice) => switch (choice) {
      AppIconChoice.ready => copy.workout.ready,
      AppIconChoice.lifting => copy.workout.lifting,
      AppIconChoice.resting => copy.workout.resting,
      AppIconChoice.yapping => copy.workout.yapping,
    };

    return Scaffold(
      appBar: AppBar(title: PageTitle(c.title)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The icon as the launcher will show it, in the colour picked.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: AppIconArt(colour: colourOf(_picked)),
                    ),
                  ),
                ),
              ),
            ),
            for (final choice in AppIconChoice.values)
              _ChoiceRow(
                colour: colourOf(choice),
                stage: stageOf(choice),
                line: lineOf(choice),
                picked: choice == _picked,
                onTap: () => setState(() => _picked = choice),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed:
                      _saving ||
                          _current == null ||
                          _picked == _current ||
                          !AppIconService.supported
                      ? null
                      : _use,
                  child: Text(_picked == _current ? c.inUse : c.use),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One icon to pick: its colour as a block, the stage it is, and its line.
class _ChoiceRow extends StatelessWidget {
  final Color colour;
  final String stage;
  final String line;
  final bool picked;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.colour,
    required this.stage,
    required this.line,
    required this.picked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: picked ? t.panel : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: t.hairline)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The stage's colour, edge to edge down the row's side.
                Container(width: picked ? 20 : 8, color: colour),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stage, style: t.label()),
                        Text(
                          line,
                          style: TextStyle(
                            fontSize: t.size.subtitle,
                            fontWeight: t.weight.bold,
                            color: t.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The app icon, drawn: the end of a loaded bar on the ground colour, one
/// plate in [colour]. The same shapes as the icon itself
/// (scripts/render_brand.py: `icon`), on its 100 grid.
class AppIconArt extends StatelessWidget {
  final Color colour;

  const AppIconArt({super.key, required this.colour});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.radiusXl * 3),
      child: CustomPaint(
        painter: _IconPainter(
          colour: colour,
          ink: t.text,
          ground: t.background,
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  final Color colour;
  final Color ink;
  final Color ground;

  const _IconPainter({
    required this.colour,
    required this.ink,
    required this.ground,
  });

  // (x, width, height, is the coloured one), lightest first.
  static const _plates = [
    (22.0, 5.0, 18.0, false),
    (26.7, 7.3, 30.0, false),
    (33.7, 9.3, 54.0, true),
    (42.7, 10.3, 70.0, false),
    (52.7, 10.3, 70.0, false),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 100;
    void rect(
      double x,
      double y,
      double width,
      double height,
      double radius,
      Color fill,
    ) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x * unit, y * unit, width * unit, height * unit),
        Radius.circular(radius * unit),
      ),
      Paint()..color = fill,
    );

    rect(0, 0, 100, 100, 0, ground);
    rect(14, 47, 52, 6, 1, ink);
    rect(60, 48, 40, 4, 0, ink);
    for (final (x, width, height, coloured) in _plates) {
      rect(x, 50 - height / 2, width, height, 1.5, coloured ? colour : ink);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.colour != colour || old.ink != ink || old.ground != ground;
}
