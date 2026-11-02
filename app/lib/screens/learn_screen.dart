import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_icons.dart';
import '../widgets/common/flat.dart';
import '../widgets/top_level_back_scope.dart';
import 'maths_screen.dart';
import 'science_screen.dart';
import 'tutorial_screen.dart';

/// The walkthrough and the reading behind the app, a page of its own on the
/// menu.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TopLevelBackScope(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(AppIcons.back),
            onPressed: () => context.go('/'),
          ),
          title: PageTitle('Learn'),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            FlatRow(
              icon: AppIcons.tutorial,
              label: 'Tutorial',
              subtitle: 'The walkthrough again',
              onTap: () => _push(context, 'tutorial', const TutorialScreen()),
            ),
            FlatRow(
              icon: AppIcons.science,
              label: 'Workout science',
              subtitle: 'The papers behind the app',
              onTap: () => _push(context, 'science', const ScienceScreen()),
            ),
            FlatRow(
              icon: AppIcons.maths,
              label: 'Calorie maths',
              subtitle: 'How burn is worked out',
              onTap: () => _push(context, 'maths', const MathsScreen()),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, String name, Widget page) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => page,
      ),
    );
  }
}
