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

const copy = Copy(tutorial: CopyTutorial(skip: 'SKIP', next: 'NEXT', previous: 'BACK', finish: 'LET\'S LIFT', papersButton: 'READ THE PAPERS', steps: [CopyTutorialStepsItem(screen: 'home', target: 'home_volume', title: 'I\'m tracking your muscles.', body: 'Not in a creepy way though. I\'ll let you know which muscle groups need more work and which have rested enough.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_templates', title: 'Pick your workout', body: 'The star is today\'s suggestion, picked from whatever covers the most unworked muscles. You can pick whatever you want though, ie butt again.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_add', title: 'Need more options?', body: 'We\'re spoilt for choice in today\'s society. Continue being spoilt by browsing the lovingly curated set of workouts to add to your favourites, or make your own.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_plan', title: 'I got your numbers', body: 'The last thing I want is for you to have to worry about numbers. I track them for you - sets × reps @ weight. Just decide what you want to work on.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_start', title: 'Start', body: 'Pressing Start is how you Start. Cool.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'workout_current', title: 'Whatcha up to', body: 'Summary of what you\'re up to if someone asks how many sets you have left. It\'s also shown on the watch app.', action: 'start_workout'), CopyTutorialStepsItem(screen: 'workout', target: 'bar_status', title: 'Your current set', body: 'The weight and the reps to hit, plus time left resting/time spent yapping etc. Beautifully colour coded for maximum aesthetics.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_plates', title: 'Plate maths', body: 'i calculate how many plates to use to make up the weight. this feature costs money in other apps, i give it to you for free since i\'m such a nice guy.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_timer', title: 'Elapsed / heart rate', body: 'How long you\'ve been going, and your heart rate from the watch if you\'re wearing one.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_button', title: 'Tap to start/finish sets', body: 'You can also do that from your watch.', action: 'start_set'), CopyTutorialStepsItem(screen: 'workout', target: 'workout_tabs', title: 'Log and heart', body: 'Everything you\'ve lifted this session, and your heart rate over time.', action: '')]), library: CopyLibrary(sheetTitle: 'Add a workout', makeYourOwn: 'Make your own', makeYourOwnHint: 'Pick the exercises, name it whatever.', add: 'ADD', added: 'ADDED', loadingFailed: 'Couldn\'t load the library. Check your connection.', empty: 'The library is empty. Someone deleted the internet.'), onboarding: CopyOnboarding(templates: CopyOnboardingTemplates(kicker: 'YOUR WORKOUTS', title: 'Pick your workouts', body: 'Tick the ones you want on your home screen. You can add more later, and edit any of them.', noneSelected: 'Pick at least one. Or one hundred.', back: 'BACK', finish: 'START LIFTING')));
