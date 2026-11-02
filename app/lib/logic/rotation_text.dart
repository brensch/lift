/// The words for the rotation: Home's line under the suggested workout,
/// from the core's structured reason, and the rotation check's lines.
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

/// The rotation check in words: [trains] is one line of what a lap of
/// the rotation trains (the gap, when there is one: [gap] is then true),
/// and [warnings] one plain line for each other thing wrong, in the order
/// the core gives them. [names] maps a template id to its name.
({String trains, bool gap, List<String> warnings}) rotationCheckLines(
  RotationCheck check,
  Map<String, String> names,
) {
  final r = copy.rotation;
  String name(String id) => names[id] ?? '?';
  var trains = check.volume.any((v) => v.completedSets7d > 0)
      ? r.trainsEverything
      : r.trainsNothing;
  var gap = false;
  final warnings = <String>[];
  for (final w in check.warnings) {
    switch (w.kind) {
      case RotationWarningKind.ROTATION_WARNING_KIND_GAP:
        gap = true;
        trains = r.gap.replaceAll(
          '{muscles}',
          joinList([for (final m in w.muscles) _muscle(m).toLowerCase()]),
        );
      case RotationWarningKind.ROTATION_WARNING_KIND_OVERLAP:
        warnings.add(
          r.overlap
              .replaceAll('{a}', name(w.templateIds.first))
              .replaceAll('{b}', name(w.templateIds.last))
              .replaceAll('{shared}', '${w.shared}')
              .replaceAll('{of}', '${w.of}'),
        );
      case RotationWarningKind.ROTATION_WARNING_KIND_TOO_FEW:
        warnings.add(r.tooFew);
      default:
        break;
    }
  }
  return (trains: trains, gap: gap, warnings: warnings);
}
