// GENERATED FROM app/copy.yaml BY scripts/gen_copy.py — DO NOT EDIT.
// Edit the YAML, then run `make copy`.
// ignore_for_file: type=lint

class Copy {
  final CopyTutorial tutorial;
  final CopyLibrary library;
  final CopyLogin login;
  final CopyPermissions permissions;
  final CopyOnboarding onboarding;
  final List<CopySoundsItem> sounds;
  final CopyLostPasskey lostPasskey;
  final CopyWorkout workout;
  const Copy({
    required this.tutorial,
    required this.library,
    required this.login,
    required this.permissions,
    required this.onboarding,
    required this.sounds,
    required this.lostPasskey,
    required this.workout,
  });
}

class CopyWorkout {
  final String start;
  final String done;
  final String ready;
  final String lifting;
  final String yapping;
  final String resting;
  final String allDone;
  final String endWorkout;
  final String setLine;
  final String warmupLine;
  final String warmupLabel;
  final String workingLabel;
  final String nextLabel;
  final String skipWarmups;
  final String firstTimeTitle;
  final String firstTimeLift;
  final String firstTimeTest;
  final String emptyBar;
  final CopyWorkoutHints hints;
  const CopyWorkout({
    required this.start,
    required this.done,
    required this.ready,
    required this.lifting,
    required this.yapping,
    required this.resting,
    required this.allDone,
    required this.endWorkout,
    required this.setLine,
    required this.warmupLine,
    required this.warmupLabel,
    required this.workingLabel,
    required this.nextLabel,
    required this.skipWarmups,
    required this.firstTimeTitle,
    required this.firstTimeLift,
    required this.firstTimeTest,
    required this.emptyBar,
    required this.hints,
  });
}

class CopyWorkoutHints {
  final String ready;
  final String lifting;
  final String resting;
  final String yapping;
  final String allDone;
  const CopyWorkoutHints({
    required this.ready,
    required this.lifting,
    required this.resting,
    required this.yapping,
    required this.allDone,
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
  final List<String> emojis;
  final List<CopyOnboardingStrengthLiftsItem> lifts;
  const CopyOnboardingStrength({
    required this.title,
    required this.body,
    required this.note,
    required this.emojis,
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

class CopyPermissions {
  final String title;
  final String button;
  const CopyPermissions({
    required this.title,
    required this.button,
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
  final String openFile;
  final String openFileFailed;
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
    required this.openFile,
    required this.openFileFailed,
    required this.devLoginHeading,
    required this.devUsername,
    required this.devLogin,
  });
}

class CopyLibrary {
  final String editButton;
  final String sheetTitle;
  final String makeYourOwn;
  final String makeYourOwnHint;
  final String add;
  final String added;
  final String yoursHeading;
  final String personal;
  final String clone;
  final String remove;
  final String delete;
  final String loadingFailed;
  final String empty;
  const CopyLibrary({
    required this.editButton,
    required this.sheetTitle,
    required this.makeYourOwn,
    required this.makeYourOwnHint,
    required this.add,
    required this.added,
    required this.yoursHeading,
    required this.personal,
    required this.clone,
    required this.remove,
    required this.delete,
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
  const CopyTutorialStepsItem({
    required this.screen,
    required this.target,
    required this.title,
    required this.body,
  });
}

const copy = Copy(tutorial: CopyTutorial(skip: 'SKIP', next: 'NEXT', previous: 'BACK', finish: 'LET\'S SCHLIFT', papersButton: 'READ THE PAPERS', steps: [CopyTutorialStepsItem(screen: 'home', target: 'home_volume', title: 'I\'m tracking your muscles.', body: 'Not in a creepy way though. I\'ll let you know which muscle groups need more work and which have rested enough.'), CopyTutorialStepsItem(screen: 'home', target: 'home_templates', title: 'Pick your workout', body: 'The star is today\'s suggestion, picked from whatever covers the most unworked muscles. You can pick whatever you want though, ie butt again.'), CopyTutorialStepsItem(screen: 'home', target: 'home_add', title: 'Need more options?', body: 'We\'re spoilt for choice in today\'s society. Continue being spoilt by browsing the lovingly curated set of workouts to add to your favourites, or make your own.'), CopyTutorialStepsItem(screen: 'home', target: 'home_plan', title: 'I got your numbers', body: 'The last thing I want is for you to have to worry about numbers. I track them for you - sets × reps @ weight. Just decide what you want to work on.'), CopyTutorialStepsItem(screen: 'home', target: 'home_start', title: 'Start', body: 'Pressing Start is how you Start. Let\'s get schlifting!')]), library: CopyLibrary(editButton: 'Edit', sheetTitle: 'Your workouts', makeYourOwn: 'Make your own', makeYourOwnHint: 'Pick the exercises, name it whatever.', add: 'ADD', added: 'ADDED', yoursHeading: 'Yours', personal: 'Personalised', clone: 'Clone', remove: 'Remove', delete: 'Delete', loadingFailed: 'Couldn\'t load the library. Check your connection.', empty: 'The library is empty. Someone deleted the internet.'), login: CopyLogin(newUserTab: 'NEW USER', signInTab: 'SIGN IN', usernamePrompt: 'What should we call you', usernameExamples: ['squat_master_9000', 'bench_press_king', 'iron_addict', 'gains_goblin', 'reps_for_jesus', 'dorito_pump', 'senior_minister_of_gains', 'chicken_and_rice', 'gluteus_maximus_prime', 'anabolic_pigeon', 'whey_too_much', 'bicep_charles', 'chuck_norris', 'preworkout_heartbeat', 'creatine_gremlin', 'quadzilla_jr', 'quadzilla_sr', 'deltoid_dan', 'shrugged_off', 'gym_shark_bait', 'tuna_shake', 'failed_pr', 'broccoli_boy'], usernameRequired: 'you gotta pick a username', createAccount: 'Create account', signInBlurb: 'Use a passkey on your device to sign in securely.', signIn: 'Sign in', openFile: 'Open an account file', openFileFailed: 'That file couldn\'t be opened', devLoginHeading: 'DEV NAME LOGIN', devUsername: 'Username', devLogin: 'Dev Login'), permissions: CopyPermissions(title: 'Studies show that people who give this app the permissions it needs get 23% more huge', button: 'GRANT PERMISSIONS'), onboarding: CopyOnboarding(next: 'NEXT', back: 'BACK', marker: CopyOnboardingMarker(title: 'Which emoji do you identify as', body: 'The hardest question in the whole signup.', refresh: 'These ones suck'), unit: CopyOnboardingUnit(title: 'Favourite unit?', body: 'Ie are you in America', pounds: 'Pounds', poundsBody: 'Best for making you think you lift more because the number is larger.', kilograms: 'Kilograms', kilogramsBody: 'Best for science and everywhere except America'), strength: CopyOnboardingStrength(title: 'How huge are you', body: 'This does not reflect on who you are as a person, just helps me get your starting weight right.', note: 'You can change these later don\'t worry.', emojis: ['🐣', '🐥', '🐤', '🐔', '🐇', '🐕', '🐒', '🐎', '🐂', '🦍'], lifts: [CopyOnboardingStrengthLiftsItem(id: 'squat', label: 'Squat'), CopyOnboardingStrengthLiftsItem(id: 'bench_press', label: 'Bench press'), CopyOnboardingStrengthLiftsItem(id: 'deadlift', label: 'Deadlift'), CopyOnboardingStrengthLiftsItem(id: 'overhead_press', label: 'Overhead press')]), weight: CopyOnboardingWeight(title: 'Weight', body: 'We log calories burned for you into your fitness tracker because that\'s the only reason to go to the gym. Calories burned is proportional to weight. Leave it blank and we use an average.', field: 'Bodyweight', failed: 'Setup failed: {error}. Try again.'), templates: CopyOnboardingTemplates(title: 'Pick your favourite workouts', body: 'You can add, remove, or edit them later. Pretty cool.', noneSelected: 'Pick at least one. Or one hundred.', finish: 'START LIFTING')), sounds: [CopySoundsItem(id: 'microwave_ding', name: 'Microwave ding'), CopySoundsItem(id: 'referee_whistle', name: 'Referee whistle'), CopySoundsItem(id: 'you_died', name: 'You died'), CopySoundsItem(id: 'notification', name: 'Notification'), CopySoundsItem(id: 'police_whistle', name: 'Police whistle'), CopySoundsItem(id: 'slide_whistle', name: 'Slide whistle'), CopySoundsItem(id: 'wolf_whistle', name: 'Wolf whistle'), CopySoundsItem(id: 'nature_whistle', name: 'Whistle'), CopySoundsItem(id: 'metallic_clang', name: 'Metallic clang'), CopySoundsItem(id: 'opening_bell', name: 'Opening bell'), CopySoundsItem(id: 'bell_ring', name: 'Bell ring'), CopySoundsItem(id: 'winner_bell', name: 'Winner bell'), CopySoundsItem(id: 'creepy_bell', name: 'Creepy bell'), CopySoundsItem(id: 'big_bell', name: 'Big bell'), CopySoundsItem(id: 'big_ben', name: 'Big Ben'), CopySoundsItem(id: 'dirty_siren', name: 'Dirty siren'), CopySoundsItem(id: 'mega_horn', name: 'Mega horn'), CopySoundsItem(id: 'kamata_grito', name: 'Kamata grito'), CopySoundsItem(id: 'angry_siren', name: 'Angry siren'), CopySoundsItem(id: 'car_horn', name: 'Vintage car horn'), CopySoundsItem(id: 'air_horn', name: 'Air horn'), CopySoundsItem(id: 'truck_horn', name: 'Truck horn'), CopySoundsItem(id: 'tada', name: 'Ta-da')], lostPasskey: CopyLostPasskey(button: 'Lost passkey?', title: 'Lost passkey', body: 'This is so sad that you\'ve lost your passkey. I have empathy for you during this difficult time. Make sure you check your password manager, your phone should have saved it for you when you signed up. If you deleted it, please tell Brendan your previous username and he will fix it for you.'), workout: CopyWorkout(start: 'Start', done: 'Done', ready: 'Ready', lifting: 'Lifting', yapping: 'Yapping', resting: 'Resting', allDone: 'All done', endWorkout: 'End workout', setLine: 'Set {n} of {m}', warmupLine: 'Warmup {n} of {m}', warmupLabel: 'WARMUP', workingLabel: 'WORKING', nextLabel: 'NEXT', skipWarmups: 'Skip', firstTimeTitle: 'First time doing {exercise}.', firstTimeLift: 'Bro I lift', firstTimeTest: 'Dunno. Test me', emptyBar: 'Bar', hints: CopyWorkoutHints(ready: 'Tap the orange circle to start the set.', lifting: 'Tap the circle again when the set is done.', resting: 'Missed reps? Tap that circle once for each.', yapping: 'Rest is over. Tap the next circle to start.', allDone: 'That\'s everything. End the workout when you\'re ready.')));
