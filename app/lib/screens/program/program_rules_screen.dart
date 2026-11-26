/// The program's own rules, by hand: how Home picks the workout it
/// suggests (by volume, in order, or by the day), the week a schedule
/// gives, each muscle's weekly set target and the hours it needs to
/// recover. Nothing changes until Save.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart' show MuscleGroup;
import '../../logic/exercises.dart';
import '../../logic/program_doc.dart';
import '../../providers/workout_provider.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/connect_ai.dart';
import 'rule_fields.dart';

/// The document's muscle names to the app's.
const _muscles = {
  'chest': MuscleGroup.MUSCLE_GROUP_CHEST,
  'back': MuscleGroup.MUSCLE_GROUP_BACK,
  'shoulders': MuscleGroup.MUSCLE_GROUP_SHOULDERS,
  'biceps': MuscleGroup.MUSCLE_GROUP_BICEPS,
  'triceps': MuscleGroup.MUSCLE_GROUP_TRICEPS,
  'quads': MuscleGroup.MUSCLE_GROUP_QUADS,
  'hamstrings': MuscleGroup.MUSCLE_GROUP_HAMSTRINGS,
  'glutes': MuscleGroup.MUSCLE_GROUP_GLUTES,
  'calves': MuscleGroup.MUSCLE_GROUP_CALVES,
  'core': MuscleGroup.MUSCLE_GROUP_CORE,
};

class ProgramRulesScreen extends StatefulWidget {
  const ProgramRulesScreen({super.key});

  @override
  State<ProgramRulesScreen> createState() => _ProgramRulesScreenState();
}

class _ProgramRulesScreenState extends State<ProgramRulesScreen> {
  ProgramDoc? _doc;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await context.read<WorkoutProvider>().programDocument();
    if (mounted) setState(() => _doc = ProgramDoc(doc));
  }

  Json get _d => _doc!.doc;
  Json get _volume => _d['volume'] as Json;
  Json get _targets => (_volume['targets'] ??= <String, dynamic>{}) as Json;
  Json get _recovery => _d['recovery'] as Json;
  Json get _hours => _recovery['hours'] as Json;
  Json get _schedule => (_d['schedule'] ??= <String, dynamic>{}) as Json;

  Future<void> _save() async {
    // A schedule only counts for `next: schedule`; leave none behind.
    if (_d['next'] != 'schedule') _d['schedule'] = <String, dynamic>{};
    setState(() => _busy = true);
    final ok = await saveDocument(context, _d);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      await _load();
    }
  }

  Widget _choice(String value, String label, String sub) => PickRow(
    label: label,
    sub: sub,
    selected: (_d['next'] ?? 'volume') == value,
    onTap: () => setState(() => _d['next'] = value),
  );

  @override
  Widget build(BuildContext context) {
    final r = copy.rules;
    return Scaffold(
      appBar: AppBar(title: PageTitle(r.homeRow)),
      body: _doc == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const LetAiDoIt(),
                      FlatHeading(r.nextHeading),
                      _choice('volume', r.nextVolume, r.nextVolumeSub),
                      _choice('sequence', r.nextSequence, r.nextSequenceSub),
                      _choice('schedule', r.nextSchedule, r.nextScheduleSub),
                      if (_d['next'] == 'schedule') ..._week(),
                      FlatHeading(r.setsHeading),
                      NumberRow(
                        label: r.setsPerLift,
                        value: (_d['sets'] as Json)['per_lift'] as num? ?? 3,
                        min: 1,
                        max: 20,
                        onChanged: (v) => setState(
                          () => (_d['sets'] as Json)['per_lift'] = v,
                        ),
                      ),
                      ..._targetRows(),
                      ..._recoveryRows(),
                    ],
                  ),
                ),
                SaveBar(onSave: _save, busy: _busy),
              ],
            ),
    );
  }

  List<Widget> _week() {
    final r = copy.rules;
    final workouts = _doc!.workouts;
    return [
      FlatHeading(r.scheduleHeading),
      for (var i = 0; i < 7; i++)
        Container(
          padding: const EdgeInsets.fromLTRB(FlatSection.margin, 4, 8, 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.tokens.hairline)),
          ),
          child: Row(
            children: [
              Expanded(child: Text(r.days[i])),
              DropdownButton<String>(
                value: _schedule[weekdayKeys[i]] as String? ?? '',
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: '', child: Text(r.scheduleRest)),
                  for (final w in workouts)
                    DropdownMenuItem(
                      value: w['id'] as String,
                      child: Text(w['name'] as String),
                    ),
                ],
                onChanged: (id) => setState(() {
                  if (id == null || id.isEmpty) {
                    _schedule.remove(weekdayKeys[i]);
                  } else {
                    _schedule[weekdayKeys[i]] = id;
                  }
                }),
              ),
            ],
          ),
        ),
    ];
  }

  /// A band as two rows, fewest and most.
  List<Widget> _band(
    String label,
    int low,
    int high,
    void Function(int low, int high) set,
  ) {
    final r = copy.rules;
    return [
      FlatRow(
        label: label,
        subtitle: r.targetsRow
            .replaceAll('{low}', '$low')
            .replaceAll('{high}', '$high'),
      ),
      NumberRow(
        label: r.targetLow,
        value: low,
        min: 0,
        max: high,
        onChanged: (v) => set(v.toInt(), high),
      ),
      NumberRow(
        label: r.targetHigh,
        value: high,
        min: low,
        max: 100,
        onChanged: (v) => set(low, v.toInt()),
      ),
    ];
  }

  List<Widget> _targetRows() {
    final r = copy.rules;
    final low = (_volume['target_low'] as num).toInt();
    final high = (_volume['target_high'] as num).toInt();
    return [
      FlatHeading(r.targetsHeading),
      ..._band(
        r.targetsDefault,
        low,
        high,
        (l, h) => setState(() {
          _volume['target_low'] = l;
          _volume['target_high'] = h;
        }),
      ),
      for (final m in muscleKeys)
        ..._band(
          muscleShortLabels[_muscles[m]] ?? m,
          ((_targets[m] as Json?)?['low'] as num? ?? low).toInt(),
          ((_targets[m] as Json?)?['high'] as num? ?? high).toInt(),
          (l, h) => setState(() {
            if (l == low && h == high) {
              _targets.remove(m);
            } else {
              _targets[m] = {'low': l, 'high': h};
            }
          }),
        ),
    ];
  }

  List<Widget> _recoveryRows() {
    final r = copy.rules;
    final fallback = (_recovery['default_hours'] as num).toInt();
    return [
      FlatHeading(r.recoveryHeading),
      NumberRow(
        label: r.recoveryDefault,
        value: fallback,
        min: 0,
        max: 240,
        step: 6,
        onChanged: (v) => setState(() => _recovery['default_hours'] = v),
      ),
      for (final m in muscleKeys)
        NumberRow(
          label: muscleShortLabels[_muscles[m]] ?? m,
          value: (_hours[m] as num? ?? fallback).toInt(),
          min: 0,
          max: 240,
          step: 6,
          onChanged: (v) => setState(() => _hours[m] = v),
        ),
    ];
  }
}
