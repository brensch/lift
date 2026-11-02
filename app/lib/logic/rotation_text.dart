/// The words for the rotation: Home's line under the suggested workout,
/// from the core's structured reason, the rotation check's warnings, and
/// what a workout would add to the rotation.
library;

import '../gen/copy.dart';
import '../gen/workout/v1/settings.pb.dart' show MuscleGroup;
import '../gen/workout/v1/workout.pb.dart';
import 'exercises.dart';

/// At most this many muscles on each side of the reason line.
const _shown = 2;

String _muscle(MuscleGroup muscle) => muscleShortLabels[muscle] ?? '?';

/// "a", "a and b", "a, b and c".
String joinList(List<String> items) {
  if (items.length <= 1) return items.join();
  final head = items.sublist(0, items.length - 1).join(', ');
  return '$head ${copy.rotation.and} ${items.last}';
}

String _sets(double sets) =>
    sets % 1 == 0 ? sets.toStringAsFixed(0) : sets.toStringAsFixed(1);

String _sentence(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// "Chest 2/10 and back 0/10 this week, both rested · quads recovering
/// (20h)". When every workout opens on a muscle still recovering, that
/// and nothing else. Empty when there is no reason to give.
String suggestionLine(SuggestionReason reason) {
  final r = copy.rotation;
  if (reason.hasFirstLiftRecovering()) {
    final waiting = reason.firstLiftRecovering;
    return r.firstLift
        .replaceAll('{muscle}', _muscle(waiting.muscle))
        .replaceAll('{hours}', '${waiting.hoursRemaining}');
  }
  final parts = <String>[];
  if (reason.fallback) {
    parts.add(r.fallback);
  } else {
    final behind = reason.behind.take(_shown).toList();
    if (behind.isNotEmpty) {
      final muscles = joinList([
        for (final m in behind)
          '${_muscle(m.muscle).toLowerCase()} ${_sets(m.sets7d)}/${m.target}',
      ]);
      final template = behind.length == 1 ? r.restedOne : r.restedTwo;
      parts.add(template.replaceAll('{muscles}', muscles));
    }
  }
  final recovering = reason.recovering
      .take(_shown)
      .map(
        (m) => r.recovering
            .replaceAll('{muscle}', _muscle(m.muscle).toLowerCase())
            .replaceAll('{hours}', '${m.hoursRemaining}'),
      );
  parts.addAll(recovering);
  return _sentence(parts.join(' · '));
}

/// One plain line per warning, in the order the core gives them (the gap
/// is not said: each workout's addition says it instead); [names] maps a
/// template id to its name.
List<String> rotationWarningLines(
  RotationCheck check,
  Map<String, String> names,
) {
  final r = copy.rotation;
  String name(String id) => names[id] ?? '?';
  return [
    for (final w in check.warnings)
      switch (w.kind) {
        RotationWarningKind.ROTATION_WARNING_KIND_OVERLAP =>
          r.overlap
              .replaceAll('{a}', name(w.templateIds.first))
              .replaceAll('{b}', name(w.templateIds.last))
              .replaceAll('{shared}', '${w.shared}')
              .replaceAll('{of}', '${w.of}'),
        _ => '',
      },
  ].where((line) => line.isNotEmpty).toList();
}

/// "Trains calves and core, which you don't have.": what a workout would
/// add to the rotation. Empty when it adds nothing.
String additionLine(List<MuscleGroup> muscles) => muscles.isEmpty
    ? ''
    : copy.rotation.adds.replaceAll(
        '{muscles}',
        joinList([for (final m in muscles) _muscle(m).toLowerCase()]),
      );

/// What each workout would add, from the check: the user's templates by
/// id, and library entries by library id.
({
  Map<String, List<MuscleGroup>> templates,
  Map<String, List<MuscleGroup>> library,
})
additionsOf(RotationCheck? check) => (
  templates: {
    for (final a in check?.additions ?? const <RotationAddition>[])
      if (a.templateId.isNotEmpty) a.templateId: a.muscles,
  },
  library: {
    for (final a in check?.additions ?? const <RotationAddition>[])
      if (a.libraryId.isNotEmpty) a.libraryId: a.muscles,
  },
);
