/// A workout's supersets and circuits, by hand: lifts whose sets alternate,
/// each group with the rest after a round, as the guide's `groups` has
/// them. Nothing changes until Save.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../logic/exercises.dart';
import '../../logic/program_doc.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/connect_ai.dart';
import 'rule_fields.dart';

Future<void> showSupersets(BuildContext context, String workoutId) {
  final wp = context.read<WorkoutProvider>();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/supersets'),
      builder: (_) => ChangeNotifierProvider.value(
        value: wp,
        child: SupersetsScreen(workoutId: workoutId),
      ),
    ),
  );
}

class SupersetsScreen extends StatefulWidget {
  final String workoutId;
  const SupersetsScreen({super.key, required this.workoutId});

  @override
  State<SupersetsScreen> createState() => _SupersetsScreenState();
}

class _SupersetsScreenState extends State<SupersetsScreen> {
  ProgramDoc? _doc;
  Json? _workout;
  bool _busy = false;

  /// Lifts ticked for a new group.
  final _picked = <String>[];
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = ProgramDoc(
      await context.read<WorkoutProvider>().programDocument(),
    );
    if (!mounted) return;
    setState(() {
      _doc = doc;
      _workout = doc.workouts
          .where((w) => w['id'] == widget.workoutId)
          .firstOrNull;
      _workout?['groups'] ??= <dynamic>[];
    });
  }

  List<Json> get _groups => (_workout!['groups'] as List).cast<Json>();
  List<String> get _lifts => (_workout!['exercises'] as List).cast<String>();
  Set<String> get _grouped => {
    for (final g in _groups) ...(g['exercises'] as List).cast<String>(),
  };

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await saveDocument(context, _doc!.doc);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = copy.rules;
    final t = context.tokens;
    final w = _workout;
    return Scaffold(
      appBar: AppBar(title: PageTitle(r.groupsHeading)),
      body: w == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const LetAiDoIt(),
                      FlatSection(
                        child: Text(
                          r.groupsHint,
                          style: TextStyle(
                            fontSize: t.size.small,
                            color: t.muted,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _groups.length; i++) ...[
                        FlatHeading(
                          r.groupRow.replaceAll(
                            '{lifts}',
                            (_groups[i]['exercises'] as List)
                                .cast<String>()
                                .map(exerciseShortName)
                                .join(' + '),
                          ),
                        ),
                        NumberRow(
                          label: r.groupRest,
                          value: _groups[i]['rest_seconds'] as num? ?? 90,
                          min: 0,
                          max: 1800,
                          step: 15,
                          onChanged: (v) =>
                              setState(() => _groups[i]['rest_seconds'] = v),
                        ),
                        FlatRow(
                          icon: AppIcons.delete,
                          label: r.groupRemove,
                          onTap: () => setState(() => _groups.removeAt(i)),
                        ),
                      ],
                      if (!_adding)
                        FlatRow(
                          icon: AppIcons.addCircle,
                          label: r.groupAdd,
                          onTap: () => setState(() {
                            _adding = true;
                            _picked.clear();
                          }),
                        )
                      else ...[
                        FlatHeading(r.groupPick),
                        for (final ex in _lifts)
                          if (!_grouped.contains(ex))
                            FlatRow(
                              label: exerciseName(ex),
                              onTap: () => setState(
                                () => _picked.contains(ex)
                                    ? _picked.remove(ex)
                                    : _picked.add(ex),
                              ),
                              trailing: Icon(
                                AppIcons.check,
                                color: _picked.contains(ex)
                                    ? t.primary
                                    : Colors.transparent,
                              ),
                            ),
                        FlatSection(
                          child: FilledButton(
                            onPressed: _picked.length < 2
                                ? null
                                : () => setState(() {
                                    // In the workout's order, as the
                                    // guide asks.
                                    _groups.add({
                                      'exercises': [
                                        for (final ex in _lifts)
                                          if (_picked.contains(ex)) ex,
                                      ],
                                      'rest_seconds': 90,
                                    });
                                    _adding = false;
                                  }),
                            child: Text(r.groupAdd),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SaveBar(onSave: _save, busy: _busy),
              ],
            ),
    );
  }
}
