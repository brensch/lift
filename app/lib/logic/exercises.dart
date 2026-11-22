import '../gen/workout/v1/settings.pbenum.dart';
import '../gen/workout/v1/workout.pb.dart' as pb;
import '../gen/workout/v1/workout.pbenum.dart';

/// Body-part groupings used for tags + the exercise-picker filters.
/// `ass` is its own first-class group (glutes are a focus, not an afterthought).
enum BodyPart { chest, back, shoulders, arms, legs, ass, core }

const Map<BodyPart, String> bodyPartLabels = {
  BodyPart.chest: 'Chest',
  BodyPart.back: 'Back',
  BodyPart.shoulders: 'Shoulders',
  BodyPart.arms: 'Arms',
  BodyPart.legs: 'Legs',
  BodyPart.ass: 'Ass',
  BodyPart.core: 'Core',
};

const Map<MuscleGroup, BodyPart> _bodyPartOf = {
  MuscleGroup.MUSCLE_GROUP_CHEST: BodyPart.chest,
  MuscleGroup.MUSCLE_GROUP_BACK: BodyPart.back,
  MuscleGroup.MUSCLE_GROUP_SHOULDERS: BodyPart.shoulders,
  MuscleGroup.MUSCLE_GROUP_BICEPS: BodyPart.arms,
  MuscleGroup.MUSCLE_GROUP_TRICEPS: BodyPart.arms,
  MuscleGroup.MUSCLE_GROUP_QUADS: BodyPart.legs,
  MuscleGroup.MUSCLE_GROUP_HAMSTRINGS: BodyPart.legs,
  MuscleGroup.MUSCLE_GROUP_CALVES: BodyPart.legs,
  MuscleGroup.MUSCLE_GROUP_GLUTES: BodyPart.ass,
  MuscleGroup.MUSCLE_GROUP_CORE: BodyPart.core,
};

/// An exercise as the person's program defines it: the core's answer
/// (`ListExercises`, and each workout's own lifts), never a list in the app.
class CatalogExercise {
  final String key;
  final String name;
  final String shortName;

  /// The muscles it trains, primary first.
  final List<MuscleGroup> muscles;
  final EquipmentKind equipment;

  /// Plain words on how to do it: shown for a lift with no picture.
  final String description;

  const CatalogExercise({
    required this.key,
    required this.name,
    required this.shortName,
    this.muscles = const [],
    this.equipment = EquipmentKind.EQUIPMENT_KIND_UNSPECIFIED,
    this.description = '',
  });

  factory CatalogExercise.from(pb.ExerciseInfo proto) => CatalogExercise(
    key: proto.key,
    name: proto.name,
    shortName: proto.shortName,
    muscles: proto.muscles,
    equipment: proto.equipment,
    description: proto.description,
  );

  /// The picker's groups it falls in, from its muscles, primary first.
  List<BodyPart> get bodyParts {
    final out = <BodyPart>[];
    for (final m in muscles) {
      final part = _bodyPartOf[m];
      if (part != null && !out.contains(part)) out.add(part);
    }
    return out;
  }
}

/// The exercises the app knows: the account's program's, in its order (the
/// picker's), and any a session partner's workout named. Set when the
/// account opens and again whenever its program may have changed.
class ExerciseCatalog {
  ExerciseCatalog._();

  static final List<CatalogExercise> _program = [];
  static final Map<String, CatalogExercise> _known = {};

  /// The program's exercises, in its order.
  static List<CatalogExercise> get all => List.unmodifiable(_program);

  /// The program's exercises, replacing whatever it had.
  static void setProgram(Iterable<CatalogExercise> exercises) {
    _program
      ..clear()
      ..addAll(exercises);
    for (final e in exercises) {
      _known[e.key] = e;
    }
  }

  /// Exercises a workout response named (a partner's own lifts included).
  static void learn(Iterable<CatalogExercise> exercises) {
    for (final e in exercises) {
      _known.putIfAbsent(e.key, () => e);
    }
  }

  static CatalogExercise? of(String key) => _known[key];
}

/// The program's exercises, in the picker's order.
List<CatalogExercise> get exerciseCatalog => ExerciseCatalog.all;

/// A key made readable when nothing names it: `zercher_squat` → "Zercher Squat".
String _readable(String key) => key
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

/// An exercise's name.
String exerciseName(String key) =>
    ExerciseCatalog.of(key)?.name ?? _readable(key);

/// An exercise's short name.
String exerciseShortName(String key) =>
    ExerciseCatalog.of(key)?.shortName ?? _readable(key);

/// Short display names for the ten muscles, shared by the volume rows, the
/// template chips and the plan reasons.
const muscleShortLabels = {
  MuscleGroup.MUSCLE_GROUP_CHEST: 'Chest',
  MuscleGroup.MUSCLE_GROUP_BACK: 'Back',
  MuscleGroup.MUSCLE_GROUP_SHOULDERS: 'Delts',
  MuscleGroup.MUSCLE_GROUP_BICEPS: 'Biceps',
  MuscleGroup.MUSCLE_GROUP_TRICEPS: 'Triceps',
  MuscleGroup.MUSCLE_GROUP_QUADS: 'Quads',
  MuscleGroup.MUSCLE_GROUP_HAMSTRINGS: 'Hams',
  MuscleGroup.MUSCLE_GROUP_GLUTES: 'Glutes',
  MuscleGroup.MUSCLE_GROUP_CALVES: 'Calves',
  MuscleGroup.MUSCLE_GROUP_CORE: 'Core',
};
