// GENERATED FROM app/copy.yaml BY scripts/gen_copy.py — DO NOT EDIT.
// Edit the YAML, then run `make copy`.
// ignore_for_file: type=lint

class Copy {
  final CopyTutorial tutorial;
  final CopyLibrary library;
  final CopyLogin login;
  final CopyOnboarding onboarding;
  final List<CopySoundsItem> sounds;
  final CopyLostPasskey lostPasskey;
  const Copy({
    required this.tutorial,
    required this.library,
    required this.login,
    required this.onboarding,
    required this.sounds,
    required this.lostPasskey,
  });
}

class CopyLostPasskey {
  final String button;
  final String title;
  final String body;
  const CopyLostPasskey({
    required this.button,
    required this.title,
    required this.body,
  });
}

class CopySoundsItem {
  final String id;
  final String name;
  const CopySoundsItem({
    required this.id,
    required this.name,
  });
}

class CopyOnboarding {
  final String next;
  final String back;
  final CopyOnboardingMarker marker;
  final CopyOnboardingUnit unit;
  final CopyOnboardingStrength strength;
  final CopyOnboardingWeight weight;
  final CopyOnboardingTemplates templates;
  const CopyOnboarding({
    required this.next,
    required this.back,
    required this.marker,
    required this.unit,
    required this.strength,
    required this.weight,
    required this.templates,
  });
}

class CopyOnboardingTemplates {
  final String title;
  final String body;
  final String noneSelected;
  final String finish;
  const CopyOnboardingTemplates({
    required this.title,
    required this.body,
    required this.noneSelected,
    required this.finish,
  });
}

class CopyOnboardingWeight {
  final String title;
  final String body;
  final String field;
  final String failed;
  const CopyOnboardingWeight({
    required this.title,
    required this.body,
    required this.field,
    required this.failed,
  });
}

class CopyOnboardingStrength {
  final String title;
  final String body;
  final String note;
  final List<CopyOnboardingStrengthLiftsItem> lifts;
  const CopyOnboardingStrength({
    required this.title,
    required this.body,
    required this.note,
    required this.lifts,
  });
}

class CopyOnboardingStrengthLiftsItem {
  final String id;
  final String label;
  const CopyOnboardingStrengthLiftsItem({
    required this.id,
    required this.label,
  });
}

class CopyOnboardingUnit {
  final String title;
  final String body;
  final String pounds;
  final String poundsBody;
  final String kilograms;
  final String kilogramsBody;
  const CopyOnboardingUnit({
    required this.title,
    required this.body,
    required this.pounds,
    required this.poundsBody,
    required this.kilograms,
    required this.kilogramsBody,
  });
}

class CopyOnboardingMarker {
  final String title;
  final String body;
  final String refresh;
  const CopyOnboardingMarker({
    required this.title,
    required this.body,
    required this.refresh,
  });
}

class CopyLogin {
  final String newUserTab;
  final String signInTab;
  final String usernamePrompt;
  final List<String> usernameExamples;
  final String usernameRequired;
  final String createAccount;
  final String signInBlurb;
  final String signIn;
  final String devLoginHeading;
  final String devUsername;
  final String devLogin;
  const CopyLogin({
    required this.newUserTab,
    required this.signInTab,
    required this.usernamePrompt,
    required this.usernameExamples,
    required this.usernameRequired,
    required this.createAccount,
    required this.signInBlurb,
    required this.signIn,
    required this.devLoginHeading,
    required this.devUsername,
    required this.devLogin,
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

const copy = Copy(tutorial: CopyTutorial(skip: 'SKIP', next: 'NEXT', previous: 'BACK', finish: 'LET\'S LIFT', papersButton: 'READ THE PAPERS', steps: [CopyTutorialStepsItem(screen: 'home', target: 'home_volume', title: 'I\'m tracking your muscles.', body: 'Not in a creepy way though. I\'ll let you know which muscle groups need more work and which have rested enough.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_templates', title: 'Pick your workout', body: 'The star is today\'s suggestion, picked from whatever covers the most unworked muscles. You can pick whatever you want though, ie butt again.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_add', title: 'Need more options?', body: 'We\'re spoilt for choice in today\'s society. Continue being spoilt by browsing the lovingly curated set of workouts to add to your favourites, or make your own.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_plan', title: 'I got your numbers', body: 'The last thing I want is for you to have to worry about numbers. I track them for you - sets × reps @ weight. Just decide what you want to work on.', action: ''), CopyTutorialStepsItem(screen: 'home', target: 'home_start', title: 'Start', body: 'Pressing Start is how you Start. Cool.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'workout_current', title: 'Whatcha up to', body: 'Summary of what you\'re up to if someone asks how many sets you have left. It\'s also shown on the watch app.', action: 'start_workout'), CopyTutorialStepsItem(screen: 'workout', target: 'workout_all', title: 'what\'s up next', body: 'All the activities for the rest of the workout are here. Drag them to rearrange if someone is camping the squat rack.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_status', title: 'Your current set', body: 'The weight and the reps to hit, plus time left resting/time spent yapping etc. Beautifully colour coded for maximum aesthetics.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_plates', title: 'Plate maths', body: 'I calculate how many plates to use to make up the weight. This feature costs money in other apps, I give it to you for free since I\'m such a nice guy.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_timer', title: 'Elapsed / heart rate', body: 'How long you\'ve been going, and your heart rate from the watch if you\'re wearing one.', action: ''), CopyTutorialStepsItem(screen: 'workout', target: 'bar_button', title: 'Tap to start/finish sets', body: 'You can also do that from your watch.', action: 'start_set'), CopyTutorialStepsItem(screen: 'workout', target: 'workout_tabs', title: 'Log and heart', body: 'Everything you\'ve lifted this session, and your heart rate over time.', action: '')]), library: CopyLibrary(sheetTitle: 'Add a workout', makeYourOwn: 'Make your own', makeYourOwnHint: 'Pick the exercises, name it whatever.', add: 'ADD', added: 'ADDED', loadingFailed: 'Couldn\'t load the library. Check your connection.', empty: 'The library is empty. Someone deleted the internet.'), login: CopyLogin(newUserTab: 'NEW USER', signInTab: 'SIGN IN', usernamePrompt: 'What should we call you', usernameExamples: ['squat_master_9000', 'bench_press_king', 'iron_addict', 'gains_goblin', 'reps_for_jesus', 'dorito_pump', 'senior_minister_of_gains', 'chicken_and_rice', 'gluteus_maximus_prime', 'anabolic_pigeon', 'whey_too_much', 'bicep_charles', 'chuck_norris', 'preworkout_heartbeat', 'creatine_gremlin', 'quadzilla_jr', 'quadzilla_sr', 'deltoid_dan', 'shrugged_off', 'gym_shark_bait', 'tuna_shake', 'failed_pr', 'broccoli_boy'], usernameRequired: 'you gotta pick a username', createAccount: 'Create account', signInBlurb: 'Use a passkey on your device to sign in securely.', signIn: 'Sign in', devLoginHeading: 'DEV NAME LOGIN', devUsername: 'Username', devLogin: 'Dev Login'), onboarding: CopyOnboarding(next: 'NEXT', back: 'BACK', marker: CopyOnboardingMarker(title: 'Which emoji do you identify as', body: 'The hardest question in', refresh: 'These ones suck'), unit: CopyOnboardingUnit(title: 'Favourite unit?', body: 'Ie are you in America', pounds: 'Pounds', poundsBody: 'Best for making you think you lift more because the number is larger.', kilograms: 'Kilograms', kilogramsBody: 'Best for science and everywhere except America'), strength: CopyOnboardingStrength(title: 'How huge are you', body: 'This does not reflect on who you are as a person, just helps me get your starting weight right.', note: 'Snapped to what fits on a bar. Every lift adjusts itself after your first session.', lifts: [CopyOnboardingStrengthLiftsItem(id: 'squat', label: 'Squat'), CopyOnboardingStrengthLiftsItem(id: 'bench_press', label: 'Bench press'), CopyOnboardingStrengthLiftsItem(id: 'deadlift', label: 'Deadlift'), CopyOnboardingStrengthLiftsItem(id: 'overhead_press', label: 'Overhead press')]), weight: CopyOnboardingWeight(title: 'Weight', body: 'we log calories burned for you into your fitness tracker because that\'s the only reason to go to the gym. calories burned is proportional to weight. leave it blank and we use an average.', field: 'Bodyweight', failed: 'Setup failed: {error}. Try again.'), templates: CopyOnboardingTemplates(title: 'Pick your workouts', body: 'Tick the ones you want on your home screen. You can add more later, and edit any of them.', noneSelected: 'Pick at least one. Or one hundred.', finish: 'START LIFTING')), sounds: [CopySoundsItem(id: 'microwave_ding', name: 'Microwave ding'), CopySoundsItem(id: 'referee_whistle', name: 'Referee whistle'), CopySoundsItem(id: 'you_died', name: 'You died'), CopySoundsItem(id: 'notification', name: 'Notification'), CopySoundsItem(id: 'police_whistle', name: 'Police whistle'), CopySoundsItem(id: 'slide_whistle', name: 'Slide whistle'), CopySoundsItem(id: 'wolf_whistle', name: 'Wolf whistle'), CopySoundsItem(id: 'nature_whistle', name: 'Whistle'), CopySoundsItem(id: 'metallic_clang', name: 'Metallic clang'), CopySoundsItem(id: 'opening_bell', name: 'Opening bell'), CopySoundsItem(id: 'bell_ring', name: 'Bell ring'), CopySoundsItem(id: 'winner_bell', name: 'Winner bell'), CopySoundsItem(id: 'creepy_bell', name: 'Creepy bell'), CopySoundsItem(id: 'big_bell', name: 'Big bell'), CopySoundsItem(id: 'big_ben', name: 'Big Ben'), CopySoundsItem(id: 'dirty_siren', name: 'Dirty siren'), CopySoundsItem(id: 'mega_horn', name: 'Mega horn'), CopySoundsItem(id: 'kamata_grito', name: 'Kamata grito'), CopySoundsItem(id: 'angry_siren', name: 'Angry siren'), CopySoundsItem(id: 'car_horn', name: 'Vintage car horn'), CopySoundsItem(id: 'air_horn', name: 'Air horn'), CopySoundsItem(id: 'truck_horn', name: 'Truck horn'), CopySoundsItem(id: 'tada', name: 'Ta-da')], lostPasskey: CopyLostPasskey(button: 'Lost passkey?', title: 'Lost passkey', body: 'This is so sad that you\'ve lost your passkey. I have empathy for you during this difficult time. Make sure you check your password manager, your phone should have saved it for you when you signed up. If you deleted it, please tell Brendan your previous username and he will fix it for you.'));
