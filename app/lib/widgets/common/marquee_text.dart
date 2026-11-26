/// One line of text that, when it doesn't fit and [MarqueeText.active] is
/// set, does the usual marquee: it sits at its start, then scrolls through
/// to its end, waits, and goes back to the start to wait again. Otherwise,
/// or when it fits, it's plain text cut off with an ellipsis.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool active;

  const MarqueeText(
    this.text, {
    super.key,
    required this.style,
    required this.active,
  });

  /// At the start, before scrolling.
  static const pauseAtStart = Duration(seconds: 3);

  /// At the end, before going back.
  static const pauseAtEnd = Duration(milliseconds: 1500);

  /// How fast it scrolls, in logical pixels a second.
  static const speed = 40.0;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _scroll = ScrollController();
  int _run = 0;

  @override
  void dispose() {
    _run++;
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls round and round until the widget changes or goes: each loop
  /// checks it's still the run that started it.
  Future<void> _loop(double overflow) async {
    final run = ++_run;
    bool live() => mounted && run == _run && _scroll.hasClients;
    while (true) {
      await Future<void>.delayed(MarqueeText.pauseAtStart);
      if (!live()) return;
      await _scroll.animateTo(
        overflow,
        duration: Duration(
          milliseconds: (overflow / MarqueeText.speed * 1000).round(),
        ),
        curve: Curves.linear,
      );
      if (!live()) return;
      await Future<void>.delayed(MarqueeText.pauseAtEnd);
      if (!live()) return;
      _scroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final overflow = painter.width - constraints.maxWidth;
        final plain = Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
        if (!widget.active || overflow <= 0 || !constraints.hasBoundedWidth) {
          // Stop any loop; start afresh when it's active again.
          if (_started != null) {
            _run++;
            _started = null;
          }
          return plain;
        }
        // Start (or restart, for new text or room) after this frame.
        final key = '${widget.text}|$overflow';
        if (_started != key) {
          _started = key;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scroll.hasClients) _scroll.jumpTo(0);
            unawaited(_loop(overflow));
          });
        }
        return SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(widget.text, maxLines: 1, style: widget.style),
        );
      },
    );
  }

  String? _started;
}
