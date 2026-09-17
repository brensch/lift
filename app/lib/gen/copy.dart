// GENERATED FROM app/copy.yaml BY scripts/gen_copy.py — DO NOT EDIT.
// Edit the YAML, then run `make copy`.
// ignore_for_file: type=lint

class Copy {
  final CopyTutorial tutorial;
  final CopyLibrary library;
  final CopyOnboarding onboarding;
  const Copy({
    required this.tutorial,
    required this.library,
    required this.onboarding,
  });
}

class CopyOnboarding {
  final CopyOnboardingTemplates templates;
  const CopyOnboarding({
    required this.templates,
  });
}

class CopyOnboardingTemplates {
  final String kicker;
  final String title;
  final String body;
  final String noneSelected;
  final String back;
  final String finish;
  const CopyOnboardingTemplates({
    required this.kicker,
    required this.title,
    required this.body,
    required this.noneSelected,
    required this.back,
    required this.finish,
  });
}

class CopyLibrary {
  final String sheetTitle;
  final String makeYourOwn;
  final String makeYourOwnHint;
  final String add;
  final String added;
  final String loadingFailed;
  final String empty;
  const CopyLibrary({
    required this.sheetTitle,
    required this.makeYourOwn,
    required this.makeYourOwnHint,
    required this.add,
    required this.added,
    required this.loadingFailed,
    required this.empty,
  });
}

class CopyTutorial {
  final String skip;
  final String next;
  final String previous;
  final String finish;
  final String papersButton;
  final List<CopyTutorialStepsItem> steps;
  const CopyTutorial({
    required this.skip,
    required this.next,
    required this.previous,
    required this.finish,
    required this.papersButton,
    required this.steps,
  });
}

class CopyTutorialStepsItem {
  final String screen;
  final String target;
  final String title;
  final String body;
  final String action;
  const CopyTutorialStepsItem({
    required this.screen,
    required this.target,
    required this.title,
    required this.body,
    required this.action,
  });
}

const copy = Copy(tutorial: CopyTutorial(skip: 'SKIP', next: 'NEXT', previous: 'BACK', finish: 'LET\'S LIFT', papersButton: 'READ THE PAPERS', steps: [CopyTutorialStepsItem(screen: 'home', target: 'home_volume', title: 'Your muscles, tracked', body: 'Hard sets this week, per muscle. Aim for the band. Yellow means still recovering, a tick means you\'ve done enough.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_templates', title: 'Pick a workout', body: 'The star is today\'s suggestion, picked from whatever is furthest behind. Tap any template to pick it instead. They\'re yours to edit.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_add', title: 'Need more workouts?', body: 'The library has StrongLifts, splits, body parts, Butt Stuff. Add one and it\'s yours. Or make your own from scratch.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_plan', title: 'The numbers are handled', body: 'Sets × reps @ weight, all prescribed. The flame means warmups are included.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_start', title: 'Start from here', body: 'One tap and the session is on.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'workout_current', title: 'What you\'re doing now', body: 'The current exercise with its warmups and working sets. Tap a set to change it, or the pencil to change the weight.', action: 'start_workout'), CopyTutorialStepsItem(screen: 'workout', target: 'bar_status', title: 'Your current set', body: 'The weight and the reps to hit, always at the bottom.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_timer', title: 'Elapsed · heart rate', body: 'How long you\'ve been going, and your heart rate from the watch if you\'re wearing one.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_button', title: 'Tap when the set is done', body: 'The rest timer starts on its own and tells you when to stop yapping.', action: 'start_set'), CopyTutorialStepsItem(screen: 'workout', target: 'workout_tabs', title: 'Log and heart', body: 'Everything you\'ve lifted this session, and your heart rate over time.', action: '')]), library: CopyLibrary(sheetTitle: 'Add a workout', makeYourOwn: 'Make your own', makeYourOwnHint: 'Pick the exercises, name it whatever.', add: 'ADD', added: 'ADDED', loadingFailed: 'Couldn\'t load the library. Check your connection.', empty: 'The library is empty. Someone deleted the internet.'), onboarding: CopyOnboarding(templates: CopyOnboardingTemplates(kicker: 'YOUR WORKOUTS', title: 'Pick your workouts', body: 'Tick the ones you want on your home screen. You can add more later, and edit any of them.', noneSelected: 'Pick at least one. Or one hundred.', back: 'BACK', finish: 'START LIFTING')));
