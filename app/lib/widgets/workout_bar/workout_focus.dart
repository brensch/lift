/// Tapping the workout banner asks the workout page to show where you're
/// up to: the page bumps this and the workout screen answers by switching
/// to the workout view and scrolling the current exercise into view, just
/// above the banner.
library;

import 'package:flutter/foundation.dart';

final workoutFocusRequests = ValueNotifier<int>(0);

void requestWorkoutFocus() => workoutFocusRequests.value++;
