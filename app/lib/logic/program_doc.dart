/// The program's document, read and changed by hand: the same JSON an
/// assistant edits (core/programs/GUIDE.md), so a person can set anything
/// it can. Which rule and scheme a lift follows, the plain sentence for
/// each, and the changes the hand editors make. The core checks the whole
/// document when it's set, as it does an assistant's.
library;

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart' show WeightUnit;
import 'weight_units.dart';

typedef Json = Map<String, dynamic>;

/// The kinds of progression, as the document names them.
const progressionKinds = [
  'estimated_max',
  'linear',
  'double',
  'cycle',
  'fixed',
  'formula',
];

/// The muscles, as the document names them, in Home's order.
const muscleKeys = [
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'quads',
  'hamstrings',
  'glutes',
  'calves',
  'core',
];

/// The days of the week, as `schedule` names them, Monday first.
const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// The scheme step roles, as the document names them.
const stepRoles = ['working', 'top', 'backoff', 'drop', 'mini'];

class ProgramDoc {
  final Json doc;
  ProgramDoc(this.doc);

  List<Json> get exercises => (doc['exercises'] as List).cast<Json>();
  List<Json> get workouts => (doc['workouts'] as List).cast<Json>();
  Json get classes => (doc['classes'] as Json);
  Json get progressions => (doc['progressions'] as Json);
  Json get schemes => (doc['schemes'] ??= <String, dynamic>{}) as Json;

  Json? exercise(String key) {
    for (final e in exercises) {
      if (e['key'] == key) return e;
    }
    return null;
  }

  /// Every lift in a workout, each once, in the workouts' order.
  List<String> trainedLifts() {
    final out = <String>[];
    for (final w in workouts) {
      for (final ex in (w['exercises'] as List).cast<String>()) {
        if (!out.contains(ex)) out.add(ex);
      }
    }
    return out;
  }

  String groupOf(String key) => exercise(key)?['class'] as String? ?? '';
  Json group(String name) => classes[name] as Json;

  /// The lifts in group [name].
  List<String> groupLifts(String name) => [
    for (final e in exercises)
      if (e['class'] == name) e['key'] as String,
  ];

  /// The name of the rule [key] follows: its own, or its group's.
  String ruleName(String key) =>
      exercise(key)?['progression'] as String? ??
      group(groupOf(key))['progression'] as String;

  bool hasOwnRule(String key) => exercise(key)?['progression'] != null;

  Json rule(String key) => progressions[ruleName(key)] as Json;

  /// The scheme [key]'s sets are laid out by: its own, or its group's.
  String schemeName(String key) =>
      exercise(key)?['scheme'] as String? ??
      group(groupOf(key))['scheme'] as String? ??
      'straight';

  bool hasOwnScheme(String key) => exercise(key)?['scheme'] != null;

  /// The name of the lift's own rule, made when one is first set by hand.
  static String ownRuleName(String key) => '${key}_rule';

  /// The name of the lift's own layout, made when its steps are edited.
  static String ownSchemeName(String key) => '${key}_sets';

  /// [key] follows [rule] of its own; null: its group's again.
  void setRule(String key, Json? rule) {
    final ex = exercise(key)!;
    final own = ownRuleName(key);
    if (rule == null) {
      ex['progression'] = null;
      if (!_ruleUsed(own)) progressions.remove(own);
      return;
    }
    progressions[own] = rule;
    ex['progression'] = own;
  }

  bool _ruleUsed(String name) =>
      exercises.any((e) => e['progression'] == name) ||
      classes.values.any((c) => (c as Json)['progression'] == name);

  /// [key]'s sets laid out by scheme [name]; null: its group's again.
  void setScheme(String key, String? name) {
    exercise(key)!['scheme'] = name;
  }

  /// [key]'s own layout, [steps], made or replaced.
  void setOwnScheme(String key, List<Json> steps) {
    final name = ownSchemeName(key);
    schemes[name] = {'steps': steps};
    exercise(key)!['scheme'] = name;
  }

  /// A rule of [kind] to start editing from: the lift's current numbers
  /// where they carry over, sensible ones otherwise.
  static Json starter(String kind, Json? from, Json group) {
    int n(String k, int d) => (from?[k] as num?)?.toInt() ?? d;
    final low = (group['rep_low'] as num).toInt();
    final high = (group['rep_high'] as num).toInt();
    return switch (kind) {
      'linear' => {
        'kind': 'linear',
        'sets': from?['sets'] ?? 3,
        'reps': n('reps', low),
        'increment_lb': from?['increment_lb'] ?? 0,
        'deload_after_fails': n('deload_after_fails', 3),
        'deload_factor': from?['deload_factor'] ?? 0.9,
      },
      'double' => {
        'kind': 'double',
        'sets': from?['sets'] ?? 3,
        'rep_low': n('rep_low', low),
        'rep_high': n('rep_high', high),
        'increment_lb': from?['increment_lb'] ?? 0,
        'rep_step': n('rep_step', 1),
      },
      'fixed' => {
        'kind': 'fixed',
        'sets': n('sets', 3),
        'reps': n('reps', low),
        'weight_lb': from?['weight_lb'] ?? 45,
      },
      'cycle' => {
        'kind': 'cycle',
        'steps':
            from?['steps'] ??
            [
              {'sets': 3, 'reps': 5, 'fraction': 0.75},
              {'sets': 3, 'reps': 3, 'fraction': 0.85},
              {'sets': 1, 'reps': 1, 'fraction': 0.95},
            ],
      },
      _ => {'kind': 'estimated_max'},
    };
  }
}

String _pct(num f) => '${(f * 100).round()}%';

String _step(num lb, WeightUnit unit) => lb == 0
    ? copy.suggestions.ruleStepDefault
    : formatWeight(lb.toDouble(), unit, includeUnit: true);

/// A rule in a sentence, as the suggestion screen says it.
String ruleSentence(Json rule, WeightUnit unit) {
  final c = copy.suggestions;
  return switch (rule['kind']) {
    'linear' =>
      c.ruleLinear
          .replaceAll('{reps}', '${rule['reps']}')
          .replaceAll('{step}', _step(rule['increment_lb'] as num? ?? 0, unit)),
    'double' =>
      c.ruleDouble
          .replaceAll('{low}', '${rule['rep_low']}')
          .replaceAll('{high}', '${rule['rep_high']}')
          .replaceAll('{step}', _step(rule['increment_lb'] as num? ?? 0, unit)),
    'fixed' =>
      c.ruleFixed
          .replaceAll('{sets}', '${rule['sets']}')
          .replaceAll('{reps}', '${rule['reps']}')
          .replaceAll(
            '{weight}',
            formatWeight(
              (rule['weight_lb'] as num).toDouble(),
              unit,
              includeUnit: true,
            ),
          ),
    'cycle' => c.ruleCycle.replaceAll(
      '{n}',
      '${(rule['steps'] as List).length}',
    ),
    'formula' => c.ruleFormula,
    _ => c.ruleEstimatedMax,
  };
}

/// A layout in a few words: "1 top · back-offs @85% ×8".
String schemeSentence(Json scheme) {
  final r = copy.rules;
  final steps = (scheme['steps'] as List).cast<Json>();
  if (steps.length == 1 &&
      steps.first['role'] == 'working' &&
      steps.first['count'] == 'rest' &&
      steps.first.keys.toSet().difference({'role', 'count'}).isEmpty) {
    return r.schemeStraight;
  }
  final parts = <String>[];
  for (final s in steps) {
    final rest = s['count'] == 'rest';
    final role = switch (s['role']) {
      'top' => rest ? r.roleTopMany : r.roleTop,
      'backoff' => rest ? r.roleBackoffMany : r.roleBackoff,
      'drop' => r.roleDrop,
      'mini' => r.roleMini,
      _ => rest ? r.roleWorkingMany : r.roleWorking,
    }.toLowerCase();
    var part = rest ? role : '${s['count']} $role';
    final f = s['fraction'] as num?;
    if (f != null && f != 1) part += ' @${_pct(f)}';
    if (s['reps'] != null) part += ' ×${s['reps']}';
    if (s['amrap'] == true) part += ' AMRAP';
    if (s['rir'] != null) part += ' RIR ${s['rir']}';
    if (s['every_seconds'] != null) part += ' EMOM ${s['every_seconds']}s';
    parts.add(part);
  }
  final text = parts.join(' · ');
  return text[0].toUpperCase() + text.substring(1);
}
