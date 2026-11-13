/// The workout's motivational quote: one of the copy's, picked at random
/// when a workout starts and recorded with it, so it stays the same for
/// that workout and can be read back afterwards.
library;

import 'dart:math';

import '../gen/copy.dart';
import '../gen/workout/v1/workout.pb.dart';

/// A quote for a workout about to start.
String randomMotivation() {
  final quotes = copy.motivation.quotes;
  return quotes.isEmpty ? '' : quotes[Random().nextInt(quotes.length)];
}

/// [workout]'s quote. One started before quotes were recorded has none of
/// its own: it is given one by its id, the same every time it is asked.
String motivationFor(Workout workout) {
  if (workout.motivation.isNotEmpty) return workout.motivation;
  final quotes = copy.motivation.quotes;
  if (quotes.isEmpty) return '';
  final sum = workout.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return quotes[sum % quotes.length];
}
