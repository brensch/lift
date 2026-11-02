// GENERATED FROM app/copy.yaml BY scripts/gen_copy.py — DO NOT EDIT.
// Edit the YAML, then run `make copy`.
// ignore_for_file: type=lint

class Copy {
  final CopyTutorial tutorial;
  final CopyLibrary library;
  final CopyRotation rotation;
  final CopyLogin login;
  final CopyPermissions permissions;
  final CopyOnboarding onboarding;
  final List<CopySoundsItem> sounds;
  final CopyLostPasskey lostPasskey;
  final CopyWorkout workout;
  final CopyPlan plan;
  const Copy({
    required this.tutorial,
    required this.library,
    required this.rotation,
    required this.login,
    required this.permissions,
    required this.onboarding,
    required this.sounds,
    required this.lostPasskey,
    required this.workout,
    required this.plan,
  });
}

class CopyPlan {
  final String budget;
  final String estimate;
  final String longest;
  final String needs;
  final String ramp;
  final CopyPlanReasons reasons;
  final CopyPlanVersus versus;
  final CopyPlanChanges changes;
  final CopyPlanOverride override;
  final CopyPlanSummary summary;
  const CopyPlan({
    required this.budget,
    required this.estimate,
    required this.longest,
    required this.needs,
    required this.ramp,
    required this.reasons,
    required this.versus,
    required this.changes,
    required this.override,
    required this.summary,
  });
}

class CopyPlanSummary {
  final String planned;
  const CopyPlanSummary({required this.planned});
}

class CopyPlanOverride {
  final String body;
  final String weight;
  final String reps;
  final String sets;
  final String setsAuto;
  final String save;
  final String remove;
  final String custom;
  const CopyPlanOverride({
    required this.body,
    required this.weight,
    required this.reps,
    required this.sets,
    required this.setsAuto,
    required this.save,
    required this.remove,
    required this.custom,
  });
}

class CopyPlanChanges {
  final String userAdjust;
  final String calibrationStep;
  final String calibrationSettled;
  final String correction;
  const CopyPlanChanges({
    required this.userAdjust,
    required this.calibrationStep,
    required this.calibrationSettled,
    required this.correction,
  });
}

class CopyPlanVersus {
  final String weightUp;
  final String weightDown;
  final String repsUpOne;
  final String repsUp;
  final String repsDownOne;
  final String repsDown;
  final String same;
  final String hit;
  final String missed;
  final String stoppedEarly;
  final String rushed;
  final String sets;
  final String timeOff;
  const CopyPlanVersus({
    required this.weightUp,
    required this.weightDown,
    required this.repsUpOne,
    required this.repsUp,
    required this.repsDownOne,
    required this.repsDown,
    required this.same,
    required this.hit,
    required this.missed,
    required this.stoppedEarly,
    required this.rushed,
    required this.sets,
    required this.timeOff,
  });
}

class CopyPlanReasons {
  final String maxUp;
  final String maxFromMiss;
  final String held;
  final String heldRushed;
  final String heldStoppedEarly;
  final String timeOff;
  final String firstTime;
  final String firstTimeBodyweight;
  final String userSet;
  final String setsExtra;
  final String setsFloor;
  const CopyPlanReasons({
    required this.maxUp,
    required this.maxFromMiss,
    required this.held,
    required this.heldRushed,
    required this.heldStoppedEarly,
    required this.timeOff,
    required this.firstTime,
    required this.firstTimeBodyweight,
    required this.userSet,
    required this.setsExtra,
    required this.setsFloor,
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
  final String choosing;
  final String endWorkout;
  final String setLine;
  final String warmupLine;
  final String warmupLabel;
  final String workingLabel;
  final String upNext;
  final String skipWarmups;
  final String firstTimeTitle;
  final String firstTimeLift;
  final String firstTimeTest;
  final String firstTimeStatus;
  final String watchEachSide;
  final String watchMinLeft;
  final String watchUnderAMin;
  final String watchMinOver;
  final String watchRestUntil;
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
    required this.choosing,
    required this.endWorkout,
    required this.setLine,
    required this.warmupLine,
    required this.warmupLabel,
    required this.workingLabel,
    required this.upNext,
    required this.skipWarmups,
    required this.firstTimeTitle,
    required this.firstTimeLift,
    required this.firstTimeTest,
    required this.firstTimeStatus,
    required this.watchEachSide,
    required this.watchMinLeft,
    required this.watchUnderAMin,
    required this.watchMinOver,
    required this.watchRestUntil,
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
  const CopySoundsItem({required this.id, required this.name});
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
  const CopyPermissions({required this.title, required this.button});
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

class CopyRotation {
  final String switchLabel;
  final String switchHint;
  final String add;
  final String remove;
  final String restedOne;
  final String restedTwo;
  final String and;
  final String recovering;
  final String fallback;
  final String firstLift;
  final String trainsEverything;
  final String trainsNothing;
  final String gap;
  final String overlap;
  final String tooFew;
  final String musclesTitle;
  final String musclesHint;
  const CopyRotation({
    required this.switchLabel,
    required this.switchHint,
    required this.add,
    required this.remove,
    required this.restedOne,
    required this.restedTwo,
    required this.and,
    required this.recovering,
    required this.fallback,
    required this.firstLift,
    required this.trainsEverything,
    required this.trainsNothing,
    required this.gap,
    required this.overlap,
    required this.tooFew,
    required this.musclesTitle,
    required this.musclesHint,
  });
}

class CopyLibrary {
  final String newButton;
  final String editButton;
  final String sheetTitle;
  final String rotationHeading;
  final String favouritesHeading;
  final String addHeading;
  final String rotationEmptyHome;
  final String dropHere;
  final String addToPlan;
  final String personal;
  final String clone;
  final String remove;
  final String delete;
  final String loadingFailed;
  final String empty;
  const CopyLibrary({
    required this.newButton,
    required this.editButton,
    required this.sheetTitle,
    required this.rotationHeading,
    required this.favouritesHeading,
    required this.addHeading,
    required this.rotationEmptyHome,
    required this.dropHere,
    required this.addToPlan,
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

const copy = Copy(
  tutorial: CopyTutorial(
    skip: 'SKIP',
    next: 'NEXT',
    previous: 'BACK',
    finish: 'LET\'S SCHLIFT',
    papersButton: 'READ THE PAPERS',
    steps: [
      CopyTutorialStepsItem(
        screen: 'home',
        target: 'home_volume',
        title: 'I\'m tracking your muscles.',
        body:
            'Not in a creepy way though. I\'ll let you know which muscle groups need more work and which have rested enough.',
      ),
      CopyTutorialStepsItem(
        screen: 'home',
        target: 'home_templates',
        title: 'Pick your workout',
        body:
            'The star is today\'s suggestion, picked from whatever covers the most unworked muscles. You can pick whatever you want though, ie butt again.',
      ),
      CopyTutorialStepsItem(
        screen: 'home',
        target: 'home_add',
        title: 'Need more options?',
        body:
            'We\'re spoilt for choice in today\'s society. Continue being spoilt by browsing the lovingly curated set of workouts to add to your main plan, or make your own.',
      ),
      CopyTutorialStepsItem(
        screen: 'home',
        target: 'home_plan',
        title: 'I got your numbers',
        body:
            'The last thing I want is for you to have to worry about numbers. I track them for you - sets × reps @ weight. Just decide what you want to work on.',
      ),
      CopyTutorialStepsItem(
        screen: 'home',
        target: 'home_start',
        title: 'Start',
        body: 'Pressing Start is how you Start. Let\'s get schlifting!',
      ),
    ],
  ),
  library: CopyLibrary(
    newButton: 'New',
    editButton: 'Manage',
    sheetTitle: 'Your workouts',
    rotationHeading: 'Main plan',
    favouritesHeading: 'Backup',
    addHeading: 'Add',
    rotationEmptyHome: 'Nothing in the main plan. Manage puts some in.',
    dropHere: 'Drag a workout here',
    addToPlan: 'Add to the main plan',
    personal: 'Personalised',
    clone: 'Clone',
    remove: 'Remove',
    delete: 'Delete',
    loadingFailed: 'Couldn\'t load the library. Check your connection.',
    empty: 'The library is empty. Someone deleted the internet.',
  ),
  rotation: CopyRotation(
    switchLabel: 'In the main plan',
    switchHint: 'The suggestion picks from these. Off, it\'s a backup.',
    add: 'Move to main plan',
    remove: 'Move to backup',
    restedOne: '{muscles} this week, rested',
    restedTwo: '{muscles} this week, both rested',
    and: 'and',
    recovering: '{muscle} recovering ({hours}h)',
    fallback: 'Everything\'s recovering or done. This one\'s waited longest.',
    firstLift:
        'Every workout starts on something sore. First back: {muscle}, in {hours}h.',
    trainsEverything: 'Trains everything.',
    trainsNothing: 'Trains nothing yet.',
    gap: 'Trains everything but {muscles}.',
    overlap: '{a} and {b} share {shared} of {of} lifts.',
    tooFew: 'Put two or more workouts in the main plan.',
    musclesTitle: 'Muscles you train',
    musclesHint: 'Tap one you don\'t care about. It stops counting.',
  ),
  login: CopyLogin(
    newUserTab: 'NEW USER',
    signInTab: 'SIGN IN',
    usernamePrompt: 'What should we call you',
    usernameExamples: [
      'squat_master_9000',
      'bench_press_king',
      'iron_addict',
      'gains_goblin',
      'reps_for_jesus',
      'dorito_pump',
      'senior_minister_of_gains',
      'chicken_and_rice',
      'gluteus_maximus_prime',
      'anabolic_pigeon',
      'whey_too_much',
      'bicep_charles',
      'chuck_norris',
      'preworkout_heartbeat',
      'creatine_gremlin',
      'quadzilla_jr',
      'quadzilla_sr',
      'deltoid_dan',
      'shrugged_off',
      'gym_shark_bait',
      'tuna_shake',
      'failed_pr',
      'broccoli_boy',
    ],
    usernameRequired: 'you gotta pick a username',
    createAccount: 'Create account',
    signInBlurb: 'Use a passkey on your device to sign in securely.',
    signIn: 'Sign in',
    openFile: 'Open an account file',
    openFileFailed: 'That file couldn\'t be opened',
    devLoginHeading: 'DEV NAME LOGIN',
    devUsername: 'Username',
    devLogin: 'Dev Login',
  ),
  permissions: CopyPermissions(
    title:
        'Studies show that people who give this app the permissions it needs get 23% more huge',
    button: 'GRANT PERMISSIONS',
  ),
  onboarding: CopyOnboarding(
    next: 'NEXT',
    back: 'BACK',
    marker: CopyOnboardingMarker(
      title: 'Which emoji do you identify as',
      body: 'The hardest question in the whole signup.',
      refresh: 'These ones suck',
    ),
    unit: CopyOnboardingUnit(
      title: 'Favourite unit?',
      body: 'Ie are you in America',
      pounds: 'Pounds',
      poundsBody:
          'Best for making you think you lift more because the number is larger.',
      kilograms: 'Kilograms',
      kilogramsBody: 'Best for science and everywhere except America',
    ),
    strength: CopyOnboardingStrength(
      title: 'How huge are you',
      body:
          'This does not reflect on who you are as a person, just helps me get your starting weight right.',
      note: 'You can change these later don\'t worry.',
      emojis: ['🐣', '🐥', '🐤', '🐔', '🐇', '🐕', '🐒', '🐎', '🐂', '🦍'],
      lifts: [
        CopyOnboardingStrengthLiftsItem(id: 'squat', label: 'Squat'),
        CopyOnboardingStrengthLiftsItem(
          id: 'bench_press',
          label: 'Bench press',
        ),
        CopyOnboardingStrengthLiftsItem(id: 'deadlift', label: 'Deadlift'),
        CopyOnboardingStrengthLiftsItem(
          id: 'overhead_press',
          label: 'Overhead press',
        ),
      ],
    ),
    weight: CopyOnboardingWeight(
      title: 'Weight',
      body:
          'We log calories burned for you into your fitness tracker because that\'s the only reason to go to the gym. Calories burned is proportional to weight. Leave it blank and we use an average.',
      field: 'Bodyweight',
      failed: 'Setup failed: {error}. Try again.',
    ),
    templates: CopyOnboardingTemplates(
      title: 'Pick your main plan',
      body: 'You can add, remove, or edit them later. Pretty cool.',
      noneSelected: 'Pick at least one. Or one hundred.',
      finish: 'START LIFTING',
    ),
  ),
  sounds: [
    CopySoundsItem(id: 'microwave_ding', name: 'Microwave ding'),
    CopySoundsItem(id: 'referee_whistle', name: 'Referee whistle'),
    CopySoundsItem(id: 'you_died', name: 'You died'),
    CopySoundsItem(id: 'notification', name: 'Notification'),
    CopySoundsItem(id: 'police_whistle', name: 'Police whistle'),
    CopySoundsItem(id: 'slide_whistle', name: 'Slide whistle'),
    CopySoundsItem(id: 'wolf_whistle', name: 'Wolf whistle'),
    CopySoundsItem(id: 'nature_whistle', name: 'Whistle'),
    CopySoundsItem(id: 'metallic_clang', name: 'Metallic clang'),
    CopySoundsItem(id: 'opening_bell', name: 'Opening bell'),
    CopySoundsItem(id: 'bell_ring', name: 'Bell ring'),
    CopySoundsItem(id: 'winner_bell', name: 'Winner bell'),
    CopySoundsItem(id: 'creepy_bell', name: 'Creepy bell'),
    CopySoundsItem(id: 'big_bell', name: 'Big bell'),
    CopySoundsItem(id: 'big_ben', name: 'Big Ben'),
    CopySoundsItem(id: 'dirty_siren', name: 'Dirty siren'),
    CopySoundsItem(id: 'mega_horn', name: 'Mega horn'),
    CopySoundsItem(id: 'kamata_grito', name: 'Kamata grito'),
    CopySoundsItem(id: 'angry_siren', name: 'Angry siren'),
    CopySoundsItem(id: 'car_horn', name: 'Vintage car horn'),
    CopySoundsItem(id: 'air_horn', name: 'Air horn'),
    CopySoundsItem(id: 'truck_horn', name: 'Truck horn'),
    CopySoundsItem(id: 'tada', name: 'Ta-da'),
  ],
  lostPasskey: CopyLostPasskey(
    button: 'Lost passkey?',
    title: 'Lost passkey',
    body:
        'This is so sad that you\'ve lost your passkey. I have empathy for you during this difficult time. Make sure you check your password manager, your phone should have saved it for you when you signed up. If you deleted it, please tell Brendan your previous username and he will fix it for you.',
  ),
  workout: CopyWorkout(
    start: 'Start',
    done: 'Done',
    ready: 'Ready',
    lifting: 'Lifting',
    yapping: 'Yapping',
    resting: 'Resting',
    allDone: 'All done',
    choosing: 'Choosing workout',
    endWorkout: 'End workout',
    setLine: 'Set {n} of {m}',
    warmupLine: 'Warmup {n} of {m}',
    warmupLabel: 'WARMUP',
    workingLabel: 'WORKING',
    upNext: 'UP\nNEXT!',
    skipWarmups: 'Skip',
    firstTimeTitle: 'First time doing {exercise}.',
    firstTimeLift: 'I know I do',
    firstTimeTest: 'Dunno. Test me',
    firstTimeStatus: 'First time!',
    watchEachSide: 'each side',
    watchMinLeft: '{n} min',
    watchUnderAMin: '<1 min',
    watchMinOver: '+{n} min',
    watchRestUntil: 'till {time}',
    emptyBar: 'Bar',
    hints: CopyWorkoutHints(
      ready: 'Tap the orange circle to start the set.',
      lifting: 'Tap the circle again when the set is done.',
      resting: 'Missed reps? Tap that circle once for each.',
      yapping: 'Rest is over. Tap the next circle to start.',
      allDone: 'That\'s everything. End the workout when you\'re ready.',
    ),
  ),
  plan: CopyPlan(
    budget: '{min} min',
    estimate: '~{min} min',
    longest: '~{min} min · the longest it gets',
    needs: 'Needs {min} min',
    ramp: 'Ramp from {weight}',
    reasons: CopyPlanReasons(
      maxUp: 'Hit every rep. Max up to {max}.',
      maxFromMiss: 'Missed a rep. Max back to {max}.',
      held: 'Max held at {max}.',
      heldRushed: 'Held at {max}: you missed a set you didn\'t rest for.',
      heldStoppedEarly: 'Held at {max}: you stopped early.',
      timeOff: '{days} days off. Max cut to {max}.',
      firstTime: 'First time. The ramp finds your max.',
      firstTimeBodyweight: 'First time. Bottom of the range.',
      userSet: 'Your numbers, from {date}.',
      setsExtra: '{sets} sets. {muscle} is behind this week.',
      setsFloor: '{sets} sets. That\'s what the time fits.',
    ),
    versus: CopyPlanVersus(
      weightUp: 'Up to {after}',
      weightDown: 'Down to {after}',
      repsUpOne: 'One more rep',
      repsUp: '{n} more reps',
      repsDownOne: 'One rep fewer',
      repsDown: '{n} fewer reps',
      same: 'Same as last time',
      hit: 'every rep last time',
      missed: 'missed reps last time',
      stoppedEarly: 'stopped early last time',
      rushed: 'you missed a set you didn\'t rest for',
      sets: '{sets} sets today, {last} last time',
      timeOff: '{days} days off',
    ),
    changes: CopyPlanChanges(
      userAdjust: 'You changed it: {before} → {after}',
      calibrationStep: 'Ramp: {before} → {after}',
      calibrationSettled: 'Ramp done: {after}',
      correction: 'Fixed a set: {before} → {after}',
    ),
    override: CopyPlanOverride(
      body: 'Your weight and reps. I carry on from here.',
      weight: 'Weight',
      reps: 'Reps',
      sets: 'Sets',
      setsAuto: 'From the time',
      save: 'SAVE',
      remove: 'Let the plan decide',
      custom: 'yours',
    ),
    summary: CopyPlanSummary(planned: 'Planned: {plan}'),
  ),
);
