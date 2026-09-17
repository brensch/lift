/// Marks a widget the tutorial can point at. Outside a tutorial it costs
/// nothing: no registry above, no registration. Inside one, the widget's
/// context is registered under [id] so the overlay can scroll to it and
/// measure its box. Ids are plain strings and live in app/copy.yaml, so
/// the copy file and the screens agree on what can be highlighted.
library;

import 'package:flutter/widgets.dart';

class TutorialRegistry extends ChangeNotifier {
  final Map<String, BuildContext> _targets = {};

  BuildContext? contextFor(String id) {
    final ctx = _targets[id];
    return ctx != null && ctx.mounted ? ctx : null;
  }

  void register(String id, BuildContext context) {
    if (identical(_targets[id], context)) return;
    _targets[id] = context;
    // Measurement happens after layout; just tell listeners something moved.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) notifyListeners();
    });
  }

  void unregister(String id, BuildContext context) {
    if (identical(_targets[id], context)) _targets.remove(id);
  }
}

class TutorialScope extends InheritedWidget {
  final TutorialRegistry registry;

  const TutorialScope({
    super.key,
    required this.registry,
    required super.child,
  });

  static TutorialRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TutorialScope>()?.registry;

  @override
  bool updateShouldNotify(TutorialScope oldWidget) =>
      registry != oldWidget.registry;
}

class TutorialTarget extends StatefulWidget {
  final String id;
  final Widget child;

  const TutorialTarget({super.key, required this.id, required this.child});

  @override
  State<TutorialTarget> createState() => _TutorialTargetState();
}

class _TutorialTargetState extends State<TutorialTarget> {
  TutorialRegistry? _registry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = TutorialScope.maybeOf(context);
    if (registry != _registry) {
      _registry?.unregister(widget.id, context);
      _registry = registry;
    }
    _registry?.register(widget.id, context);
  }

  @override
  void didUpdateWidget(TutorialTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _registry?.unregister(oldWidget.id, context);
      _registry?.register(widget.id, context);
    }
  }

  @override
  void dispose() {
    _registry?.unregister(widget.id, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
