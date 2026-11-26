/// The program's progression, in one place: every lift in your workouts
/// with how it moves and how its sets are laid out, in plain words. Tap
/// one to change it (the lift screen).
library;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../gen/copy.dart';
import '../../logic/exercises.dart';
import '../../logic/program_doc.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/common/flat.dart';
import '../../widgets/connect_ai.dart';
import 'lift_rules_screen.dart';

class ProgressionScreen extends StatefulWidget {
  const ProgressionScreen({super.key});

  @override
  State<ProgressionScreen> createState() => _ProgressionScreenState();
}

class _ProgressionScreenState extends State<ProgressionScreen> {
  ProgramDoc? _doc;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await context.read<WorkoutProvider>().programDocument();
    if (mounted) setState(() => _doc = ProgramDoc(doc));
  }

  @override
  Widget build(BuildContext context) {
    final r = copy.rules;
    final unit = context.watch<SettingsProvider>().weightUnit;
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(title: PageTitle(r.liftsTitle)),
      body: doc == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                const LetAiDoIt(),
                FlatHeading(r.liftsHeading),
                if (doc.trainedLifts().isEmpty)
                  FlatSection(child: Text(r.liftsEmpty)),
                for (final key in doc.trainedLifts())
                  FlatRow(
                    label: exerciseName(key),
                    subtitle:
                        '${ruleSentence(doc.rule(key), unit)}\n'
                        '${schemeSentence(doc.schemes[doc.schemeName(key)] as Json? ?? const {'steps': []})}',
                    onTap: () async {
                      await showLiftRules(context, exercise: key);
                      await _load();
                    },
                  ),
              ],
            ),
    );
  }
}
