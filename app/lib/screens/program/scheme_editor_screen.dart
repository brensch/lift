/// A set layout's steps, by hand: each step's kind of set, how many, reps,
/// share of the working weight, AMRAP, reps-in-reserve target, rest and
/// EMOM, as the guide's `schemes` has them. Returns the steps on Save; the
/// lift screen makes them the lift's own layout. Fields this screen
/// doesn't show (`on_miss`) are kept as they were.
library;

import 'package:material_ui/material_ui.dart';

import '../../gen/copy.dart';
import '../../logic/program_doc.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme_spec.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/connect_ai.dart';
import 'rule_fields.dart';

/// Edit a copy of [steps]; the new steps, or null when backed out of.
Future<List<Json>?> editSchemeSteps(BuildContext context, List<Json> steps) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<List<Json>>(
        settings: const RouteSettings(name: '/scheme-steps'),
        builder: (_) => SchemeEditorScreen(steps: steps),
      ),
    );

class SchemeEditorScreen extends StatefulWidget {
  final List<Json> steps;
  const SchemeEditorScreen({super.key, required this.steps});

  @override
  State<SchemeEditorScreen> createState() => _SchemeEditorScreenState();
}

class _SchemeEditorScreenState extends State<SchemeEditorScreen> {
  late final List<Json> _steps = [
    for (final s in widget.steps) Map<String, dynamic>.of(s),
  ];

  bool get _restTaken => _steps.any((s) => s['count'] == 'rest');

  String _role(String role) {
    final r = copy.rules;
    return switch (role) {
      'top' => r.roleTop,
      'backoff' => r.roleBackoff,
      'drop' => r.roleDrop,
      'mini' => r.roleMini,
      _ => r.roleWorking,
    };
  }

  @override
  Widget build(BuildContext context) {
    final r = copy.rules;
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: PageTitle(r.stepsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const LetAiDoIt(),
                FlatSection(
                  child: Text(
                    schemeSentence({'steps': _steps}),
                    style: t.mono(TextStyle(fontSize: t.size.small)),
                  ),
                ),
                for (var i = 0; i < _steps.length; i++) ..._step(i),
                FlatRow(
                  icon: AppIcons.addCircle,
                  label: r.addStep,
                  onTap: () => setState(
                    () => _steps.add({'role': 'working', 'count': 1}),
                  ),
                ),
              ],
            ),
          ),
          SaveBar(
            onSave: _steps.isEmpty
                ? null
                : () => Navigator.pop(context, _steps),
          ),
        ],
      ),
    );
  }

  List<Widget> _step(int i) {
    final r = copy.rules;
    final s = _steps[i];
    void set(String k, Object? v) => setState(() {
      if (v == null) {
        s.remove(k);
      } else {
        s[k] = v;
      }
    });
    final main = const ['working', 'top', 'backoff'].contains(s['role']);
    final rest = s['count'] == 'rest';
    return [
      FlatHeading(
        '${r.cycleStep.replaceAll('{n}', '${i + 1}')} · ${_role(s['role'] as String)}',
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(FlatSection.margin, 8, 8, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in stepRoles)
              ChoiceChip(
                label: Text(_role(role)),
                selected: s['role'] == role,
                onSelected: (_) => setState(() {
                  s['role'] = role;
                  if (!const ['working', 'top', 'backoff'].contains(role) &&
                      s['count'] == 'rest') {
                    s['count'] = 1;
                  }
                }),
              ),
            if (_steps.length > 1)
              ActionChip(
                label: Text(r.removeStep),
                onPressed: () => setState(() => _steps.removeAt(i)),
              ),
          ],
        ),
      ),
      if (main && (rest || !_restTaken))
        SwitchRow(
          label: r.countRest,
          value: rest,
          onChanged: (v) => set('count', v ? 'rest' : 1),
        ),
      if (!rest)
        NumberRow(
          label: r.count,
          value: s['count'] as num,
          min: 0,
          max: 20,
          onChanged: (v) => set('count', v),
        ),
      NumberRow(
        label: r.stepReps,
        value: s['reps'] as num? ?? 0,
        min: 0,
        max: 100,
        onChanged: (v) => set('reps', v == 0 ? null : v),
      ),
      NumberRow(
        label: r.fraction,
        value: ((s['fraction'] as num? ?? 1) * 100).round(),
        min: 5,
        max: 150,
        step: 5,
        onChanged: (v) => set('fraction', v == 100 ? null : v / 100),
      ),
      SwitchRow(
        label: r.amrap,
        value: s['amrap'] == true,
        onChanged: (v) => set('amrap', v ? true : null),
      ),
      NumberRow(
        label: r.rir,
        value: s['rir'] as num? ?? -1,
        min: -1,
        max: 5,
        show: (v) => v < 0 ? '—' : '$v',
        onChanged: (v) => set('rir', v < 0 ? null : v),
      ),
      NumberRow(
        label: r.stepRest,
        value: s['rest_seconds'] as num? ?? 0,
        min: 0,
        max: 1800,
        step: 15,
        onChanged: (v) => set('rest_seconds', v == 0 ? null : v),
      ),
      NumberRow(
        label: r.every,
        value: s['every_seconds'] as num? ?? 0,
        min: 0,
        max: 600,
        step: 10,
        show: (v) => v == 0 ? '—' : '${v}s',
        onChanged: (v) =>
            set('every_seconds', v == 0 ? null : (v < 10 ? 10 : v)),
      ),
    ];
  }
}
