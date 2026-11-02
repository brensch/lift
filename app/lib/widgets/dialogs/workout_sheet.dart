import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/workout_provider.dart';

/// A bottom sheet over the whole app (the workout bar included) whose
/// [child] works on [provider]: the app's, or the tutorial's sandbox one
/// when the tutorial opened it. [name] names the route for page tracking.
Future<T?> showWorkoutSheet<T>(
  BuildContext context, {
  required WorkoutProvider provider,
  required Widget child,
  String? name,
}) {
  return showModalBottomSheet<T>(
    context: context,
    routeSettings: name == null ? null : RouteSettings(name: name),
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(value: provider, child: child),
  );
}
