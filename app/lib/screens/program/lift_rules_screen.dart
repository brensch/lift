/// One lift, by hand, as fully as an assistant sets it: how it progresses
/// (any kind and its numbers, or its group's), its group's rep range,
/// rest and warmups, how its sets are laid out (a layout of the program's,
/// or its own steps), its tempo cue and whether the number is per side.
/// Nothing changes until Save, which sets the program as a whole.
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../gen/workout/v1/settings.pb.dart' show WeightUnit;
import '../../logic/exercises.dart';
import '../../logic/program_doc.dart';
import '../../logic/weight_units.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/connect_ai.dart';
import 'rule_fields.dart';
import 'scheme_editor_screen.dart';

Future<void> showLiftRules(
  BuildContext context, {
  required String exercise,
  VoidCallback? onOverride,
}) {
  final wp = context.read<WorkoutProvider>();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/lift-rules'),
      builder: (_) => ChangeNotifierProvider.value(
        value: wp,
        child: LiftRulesScreen(exercise: exercise, onOverride: onOverride),
      ),
    ),
  );
}

class LiftRulesScreen extends StatefulWidget {
  final String exercise;

  /// Set this lift's own next numbers (the override sheet); no row if null.
  final VoidCallback? onOverride;

  const LiftRulesScreen({super.key, required this.exercise, this.onOverride});

  @override
  State<LiftRulesScreen> createState() => _LiftRulesScreenState();
}

/// The group's own rule: the lift has none of its own.
const _group = 'group';

class _LiftRulesScreenState extends State<LiftRulesScreen> {
  ProgramDoc? _doc;
  String _kind = _group;
  Json _rule = {};
  Json _groupDef = {};
  String? _scheme;
  List<Json>? _ownSteps;
  final _tempo = TextEditingController();
  bool _perSide = false;
  bool _busy = false;

  String get _key => widget.exercise;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tempo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = ProgramDoc(
      await context.read<WorkoutProvider>().programDocument(),
    );
    final ex = doc.exercise(_key);
    if (!mounted || ex == null) return;
    setState(() {
      _doc = doc;
      _groupDef = Map.of(doc.group(doc.groupOf(_key)));
      if (doc.hasOwnRule(_key)) {
        _rule = _copy(doc.rule(_key));
        _kind = _rule['kind'] as String;
      }
      _scheme = ex['scheme'] as String?;
      _tempo.text = ex['tempo'] as String? ?? '';
      _perSide = ex['per_side'] as bool? ?? false;
    });
  }

  static Json _copy(Json j) => {
    for (final e in j.entries)
      e.key: e.value is List
          ? [
              for (final v in e.value as List)
                v is Map ? Map<String, dynamic>.of(v.cast()) : v,
            ]
          : e.value,
  };

  void _pick(String kind) => setState(() {
    if (kind == _kind) return;
    _kind = kind;
    if (kind != _group) _rule = ProgramDoc.starter(kind, _rule, _groupDef);
  });

  Future<void> _save() async {
    final doc = _doc!;
    final ex = doc.exercise(_key)!;
    doc.setRule(_key, _kind == _group ? null : _rule);
    doc.classes[doc.groupOf(_key)] = _groupDef;
    if (_ownSteps != null) {
      doc.setOwnScheme(_key, _ownSteps!);
    } else {
      doc.setScheme(_key, _scheme);
    }
    ex['tempo'] = _tempo.text.trim();
    ex['per_side'] = _perSide;
    setState(() => _busy = true);
    final ok = await saveDocument(context, doc.doc);
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
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(title: PageTitle(exerciseName(_key))),
      body: doc == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const LetAiDoIt(),
                      if (widget.onOverride != null)
                        FlatRow(
                          icon: AppIcons.edit,
                          label: copy.rules.liftOverride,
                          subtitle: copy.rules.liftOverrideSub,
                          onTap: widget.onOverride,
                        ),
                      ..._progression(context, doc),
                      ..._groupRows(context, doc),
                      ..._schemeRows(context, doc),
                      ..._other(context),
                    ],
                  ),
                ),
                SaveBar(onSave: _save, busy: _busy),
              ],
            ),
    );
  }

  Widget _choice({
    required String label,
    required String sub,
    required bool selected,
    VoidCallback? onTap,
  }) => PickRow(label: label, sub: sub, selected: selected, onTap: onTap);

  List<Widget> _progression(BuildContext context, ProgramDoc doc) {
    final r = copy.rules;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final group = doc.groupOf(_key);
    final groupRule = doc.progressions[_groupDef['progression']] as Json?;
    final kinds = [
      ('estimated_max', r.kindEstimatedMax, r.kindEstimatedMaxSub),
      ('linear', r.kindLinear, r.kindLinearSub),
      ('double', r.kindDouble, r.kindDoubleSub),
      ('cycle', r.kindCycle, r.kindCycleSub),
      ('fixed', r.kindFixed, r.kindFixedSub),
    ];
    return [
      FlatHeading(r.progressionHeading),
      _choice(
        label: r.groupRule.replaceAll('{group}', group),
        sub: groupRule == null ? '' : ruleSentence(groupRule, unit),
        selected: _kind == _group,
        onTap: () => _pick(_group),
      ),
      for (final (kind, label, sub) in kinds)
        _choice(
          label: label,
          sub: sub,
          selected: _kind == kind,
          onTap: () => _pick(kind),
        ),
      if (_kind == 'formula')
        _choice(label: r.kindFormula, sub: r.kindFormulaSub, selected: true),
      ..._fields(unit),
    ];
  }

  /// The numbers of the chosen kind.
  List<Widget> _fields(WeightUnit unit) {
    final r = copy.rules;
    final rule = _rule;
    void set(String k, Object? v) => setState(() => rule[k] = v);
    num n(String k, num d) => rule[k] as num? ?? d;
    final metric = isMetricUnit(unit);
    final wStep = metric ? 2.5 : 5;
    String w(num v) => formatWeight(
      poundsFromDisplayWeight(v.toDouble(), unit),
      unit,
      includeUnit: false,
    );
    Widget weightRow(String k, String label, {bool zeroAuto = false}) =>
        NumberRow(
          label: label.replaceAll('{unit}', weightUnitSuffix(unit)),
          value: displayWeightFromPounds(n(k, 0).toDouble(), unit),
          min: 0,
          max: metric ? 500 : 1100,
          step: wStep,
          show: (v) => zeroAuto && v == 0 ? '—' : w(v),
          onChanged: (v) => set(k, poundsFromDisplayWeight(v.toDouble(), unit)),
        );
    Widget sets() => SwitchRow(
      label: r.setsAuto,
      value: rule['sets'] == null,
      onChanged: (auto) => set('sets', auto ? null : 3),
    );
    Widget setCount() => rule['sets'] == null
        ? const SizedBox.shrink()
        : NumberRow(
            label: r.sets,
            value: n('sets', 3),
            min: 1,
            max: 20,
            onChanged: (v) => set('sets', v),
          );
    return switch (_kind) {
      'linear' => [
        sets(),
        setCount(),
        NumberRow(
          label: r.reps,
          value: n('reps', 5),
          min: 1,
          max: 100,
          onChanged: (v) => set('reps', v),
        ),
        weightRow('increment_lb', r.increment, zeroAuto: true),
        NumberRow(
          label: r.deloadAfter,
          value: n('deload_after_fails', 3),
          min: 0,
          max: 20,
          onChanged: (v) => set('deload_after_fails', v),
        ),
        NumberRow(
          label: r.deloadTo,
          value: (n('deload_factor', 0.9) * 100).round(),
          min: 50,
          max: 100,
          step: 5,
          onChanged: (v) => set('deload_factor', v / 100),
        ),
      ],
      'double' => [
        sets(),
        setCount(),
        NumberRow(
          label: r.repLow,
          value: n('rep_low', 8),
          min: 1,
          max: n('rep_high', 12),
          onChanged: (v) => set('rep_low', v),
        ),
        NumberRow(
          label: r.repHigh,
          value: n('rep_high', 12),
          min: n('rep_low', 8),
          max: 100,
          onChanged: (v) => set('rep_high', v),
        ),
        NumberRow(
          label: r.repStep,
          value: n('rep_step', 1),
          min: 1,
          max: 10,
          onChanged: (v) => set('rep_step', v),
        ),
        weightRow('increment_lb', r.increment, zeroAuto: true),
      ],
      'fixed' => [
        NumberRow(
          label: r.sets,
          value: n('sets', 3),
          min: 1,
          max: 20,
          onChanged: (v) => set('sets', v),
        ),
        NumberRow(
          label: r.reps,
          value: n('reps', 10),
          min: 1,
          max: 100,
          onChanged: (v) => set('reps', v),
        ),
        weightRow('weight_lb', r.weight),
      ],
      'cycle' => _cycleRows(),
      _ => const <Widget>[],
    };
  }

  List<Widget> _cycleRows() {
    final r = copy.rules;
    final steps = (_rule['steps'] as List).cast<Json>();
    return [
      for (var i = 0; i < steps.length; i++) ...[
        FlatRow(
          label: r.cycleStep.replaceAll('{n}', '${i + 1}'),
          trailing: steps.length > 1
              ? TextButton(
                  onPressed: () => setState(() => steps.removeAt(i)),
                  child: Text(r.removeStep),
                )
              : null,
        ),
        NumberRow(
          label: r.sets,
          value: steps[i]['sets'] as num,
          min: 1,
          max: 20,
          onChanged: (v) => setState(() => steps[i]['sets'] = v),
        ),
        NumberRow(
          label: r.reps,
          value: steps[i]['reps'] as num,
          min: 1,
          max: 100,
          onChanged: (v) => setState(() => steps[i]['reps'] = v),
        ),
        NumberRow(
          label: r.cycleFraction,
          value: ((steps[i]['fraction'] as num) * 100).round(),
          min: 5,
          max: 150,
          step: 5,
          onChanged: (v) => setState(() => steps[i]['fraction'] = v / 100),
        ),
      ],
      FlatRow(
        icon: AppIcons.addCircle,
        label: r.addStep,
        onTap: () =>
            setState(() => steps.add({'sets': 3, 'reps': 5, 'fraction': 0.8})),
      ),
    ];
  }

  List<Widget> _groupRows(BuildContext context, ProgramDoc doc) {
    final r = copy.rules;
    final group = doc.groupOf(_key);
    final g = _groupDef;
    void set(String k, Object v) => setState(() => g[k] = v);
    final members = doc
        .groupLifts(group)
        .where(doc.trainedLifts().contains)
        .map(exerciseName)
        .join(', ');
    return [
      FlatHeading(r.groupHeading.replaceAll('{group}', group)),
      if (members.isNotEmpty)
        FlatSection(
          child: Text(
            r.groupLifts.replaceAll('{lifts}', members),
            style: TextStyle(
              fontSize: context.tokens.size.small,
              color: context.tokens.muted,
            ),
          ),
        ),
      NumberRow(
        label: r.repLow,
        value: g['rep_low'] as num,
        min: 1,
        max: g['rep_high'] as num,
        onChanged: (v) => set('rep_low', v),
      ),
      NumberRow(
        label: r.repHigh,
        value: g['rep_high'] as num,
        min: g['rep_low'] as num,
        max: 100,
        onChanged: (v) => set('rep_high', v),
      ),
      NumberRow(
        label: r.rest,
        value: g['rest_seconds'] as num,
        min: 0,
        max: 1800,
        step: 15,
        onChanged: (v) => set('rest_seconds', v),
      ),
      SwitchRow(
        label: r.warmups,
        value: g['warmups'] as bool,
        onChanged: (v) => set('warmups', v),
      ),
    ];
  }

  String _schemeLabel(String name) {
    final n = copy.rules.schemeNames;
    return switch (name) {
      'straight' => n.straight,
      'top_backoff' => n.topBackoff,
      'plus_set' => n.plusSet,
      'pyramid' => n.pyramid,
      'drop_finish' => n.dropFinish,
      'myo' => n.myo,
      'cluster' => n.cluster,
      'emom' => n.emom,
      _ when name == ProgramDoc.ownSchemeName(_key) => copy.rules.schemeOwn,
      _ => name,
    };
  }

  List<Widget> _schemeRows(BuildContext context, ProgramDoc doc) {
    final r = copy.rules;
    final groupScheme = _groupDef['scheme'] as String? ?? 'straight';
    final names = doc.schemes.keys.toList();
    final current = _ownSteps != null
        ? ProgramDoc.ownSchemeName(_key)
        : (_scheme ?? groupScheme);
    final currentSteps =
        _ownSteps ??
        ((doc.schemes[current] as Json?)?['steps'] as List?)?.cast<Json>() ??
        [
          {'role': 'working', 'count': 'rest'},
        ];
    return [
      FlatHeading(r.schemeHeading),
      _choice(
        label: r.groupRule.replaceAll('{group}', doc.groupOf(_key)),
        sub: _schemeLabel(groupScheme),
        selected: _scheme == null && _ownSteps == null,
        onTap: () => setState(() {
          _scheme = null;
          _ownSteps = null;
        }),
      ),
      for (final name in names)
        _choice(
          label: _schemeLabel(name),
          sub: schemeSentence(doc.schemes[name] as Json),
          selected: _ownSteps == null && _scheme == name,
          onTap: () => setState(() {
            _scheme = name;
            _ownSteps = null;
          }),
        ),
      if (_ownSteps != null)
        _choice(
          label: r.schemeOwn,
          sub: schemeSentence({'steps': _ownSteps}),
          selected: true,
        ),
      FlatRow(
        icon: AppIcons.edit,
        label: r.schemeEdit,
        subtitle: schemeSentence({'steps': currentSteps}),
        onTap: () async {
          final steps = await editSchemeSteps(context, currentSteps);
          if (steps != null) setState(() => _ownSteps = steps);
        },
      ),
    ];
  }

  List<Widget> _other(BuildContext context) {
    final r = copy.rules;
    return [
      FlatHeading(r.otherHeading),
      FlatSection(
        child: TextField(
          controller: _tempo,
          decoration: InputDecoration(
            labelText: r.tempo,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      SwitchRow(
        label: r.perSide,
        value: _perSide,
        onChanged: (v) => setState(() => _perSide = v),
      ),
    ];
  }
}
