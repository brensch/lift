/// The top of the menu: you, as a banner in your colour with your emoji,
/// and under it your totals across every finished workout — how many, how
/// long, and that time split into lifting, resting and yapping. Tap the
/// banner to edit your profile.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../gen/copy.dart';
import '../logic/session_state.dart';
import '../logic/user_profile.dart';
import '../providers/auth_provider.dart';
import '../services/workout_service.dart';
import '../theme/app_icons.dart';
import '../theme/theme_spec.dart';

class MenuProfile extends StatefulWidget {
  final VoidCallback onEditProfile;

  const MenuProfile({super.key, required this.onEditProfile});

  @override
  State<MenuProfile> createState() => _MenuProfileState();
}

class _Totals {
  final int workouts;
  final int seconds;
  final int lifting;
  final int resting;
  final int yapping;

  const _Totals(
    this.workouts,
    this.seconds,
    this.lifting,
    this.resting,
    this.yapping,
  );
}

class _MenuProfileState extends State<MenuProfile> {
  /// The last totals loaded and whose they are, so reopening the menu
  /// shows them at once, and never someone else's after a logout.
  static (String?, _Totals)? _cached;
  _Totals? _totals;

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthProvider>().userId;
    if (_cached case (final id, final totals) when id == userId) {
      _totals = totals;
    }
    _load(userId);
  }

  Future<void> _load(String? userId) async {
    try {
      final all = await context
          .read<WorkoutServiceWrapper>()
          .listWorkoutSummaries();
      var seconds = 0, lifting = 0, resting = 0, yapping = 0;
      for (final w in all) {
        seconds += w.summary.durationSeconds.toInt();
        lifting += w.summary.liftingSeconds.toInt();
        resting += w.summary.restingSeconds.toInt();
        yapping += w.summary.yappingSeconds.toInt();
      }
      final totals = _Totals(all.length, seconds, lifting, resting, yapping);
      _cached = (userId, totals);
      if (mounted) setState(() => _totals = totals);
    } catch (e) {
      debugPrint('Menu totals failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final auth = context.watch<AuthProvider>();
    final totals = _totals;

    Widget cell(
      String label,
      String value, {
      Color? color,
      bool last = false,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : BorderSide(color: t.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, style: t.label(color: color)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: t.mono(
                  TextStyle(
                    fontSize: t.size.title,
                    fontWeight: t.weight.bold,
                    color: t.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget row(List<Widget> cells) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.hairline)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        ),
      ),
    );

    final bannerColor = profileColorFromHex(auth.profileColorHex);
    final onColor = t.inkOn(bannerColor);

    String show(int Function(_Totals) f, String Function(int) fmt) =>
        totals == null ? '–' : fmt(f(totals));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // You: your colour, full width, your emoji on the left.
        Material(
          color: bannerColor,
          child: InkWell(
            onTap: widget.onEditProfile,
            child: SizedBox(
              height: 72,
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Center(
                      child: Text(
                        normalizedProfileEmoji(auth.profileEmoji),
                        style: TextStyle(fontSize: t.size.displayLg, height: 1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (auth.username ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).appBarTheme.titleTextStyle?.copyWith(color: onColor),
                    ),
                  ),
                  // Says the banner edits your profile.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(AppIcons.edit, color: onColor),
                  ),
                ],
              ),
            ),
          ),
        ),
        row([
          cell('Workouts', show((x) => x.workouts, (v) => '$v')),
          cell('Time', show((x) => x.seconds, formatDurationShort), last: true),
        ]),
        row([
          cell(
            copy.workout.lifting,
            show((x) => x.lifting, formatDurationShort),
            color: t.lifting,
          ),
          cell(
            copy.workout.resting,
            show((x) => x.resting, formatDurationShort),
            color: t.resting,
          ),
          cell(
            copy.workout.yapping,
            show((x) => x.yapping, formatDurationShort),
            color: t.yapping,
            last: true,
          ),
        ]),
      ],
    );
  }
}
