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

    // A figure under its label, in the cells of a row split by hairlines.
    Widget cell(
      String label,
      String value, {
      Color? color,
      bool last = false,
    }) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : BorderSide(color: t.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              style: t.label(color: color).copyWith(fontSize: t.size.small),
            ),
            Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: t.mono(
                TextStyle(
                  fontSize: t.size.title,
                  fontWeight: t.weight.bold,
                  color: t.text,
                  height: 1.2,
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

    String show(int Function(_Totals) f, String Function(int) fmt) =>
        totals == null ? '–' : fmt(f(totals));

    // How your time splits, as one bar in the stages' colours: each as wide
    // as its share. Even thirds until there is time to split.
    final split = [
      (t.lifting, totals?.lifting ?? 0),
      (t.resting, totals?.resting ?? 0),
      (t.yapping, totals?.yapping ?? 0),
    ];
    final timed = split.fold<int>(0, (sum, part) => sum + part.$2) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // You, as the workout's status box has you: your emoji on a block of
        // your colour, your name beside it. Tap to edit your profile.
        Material(
          color: t.panel,
          child: InkWell(
            onTap: widget.onEditProfile,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: t.hairline),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    alignment: Alignment.center,
                    color: bannerColor,
                    child: Text(
                      normalizedProfileEmoji(auth.profileEmoji),
                      style: TextStyle(fontSize: t.size.display, height: 1),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        auth.username ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: t.size.titleLg,
                          fontWeight: t.weight.bold,
                          color: t.text,
                        ),
                      ),
                    ),
                  ),
                  // Says the row edits your profile.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      AppIcons.edit,
                      size: t.size.title,
                      color: t.muted,
                    ),
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
        // Under the three, so their dividers run up to the line above.
        SizedBox(
          height: 6,
          child: Row(
            children: [
              for (final (color, seconds) in split)
                Expanded(
                  flex: timed ? seconds.clamp(1, 1 << 30) : 1,
                  child: ColoredBox(color: color),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
