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
  final CopyPasskeyErrors passkeyErrors;
  final CopyRecoveryAlert recoveryAlert;
  final CopyWorkout workout;
  final CopyPlan plan;
  final CopyExercise exercise;
  final CopyYourData yourData;
  final CopyEndWorkoutDialog endWorkoutDialog;
  final CopyExercisePicker exercisePicker;
  final CopyHeartRate heartRate;
  final CopyJoinRequest joinRequest;
  final CopyMultiplayer multiplayer;
  final CopyMenu menu;
  final CopySetLog setLog;
  final CopyPlates plates;
  final CopyAdjustWeight adjustWeight;
  final CopyTemplateUpdate templateUpdate;
  final CopyParticipant participant;
  final CopyHealth health;
  final CopyRestNotification restNotification;
  final CopyInvite invite;
  final String sessionExpired;
  final CopyUpdateRequired updateRequired;
  final CopyErrorDialog errorDialog;
  final CopyTemplateEditor templateEditor;
  final CopyHistory history;
  final CopyProgress progress;
  final CopyHome home;
  final CopyWorkoutPage workoutPage;
  final CopyStartup startup;
  final CopySummary summary;
  final CopySettings settings;
  final CopyProfileMarker profileMarker;
  final CopyPasskeys passkeys;
  final CopyAddPasskey addPasskey;
  final CopyPlateColours plateColours;
  final CopyLearn learn;
  final CopyScience science;
  final CopyMaths maths;
  const Copy({
    required this.tutorial,
    required this.library,
    required this.rotation,
    required this.login,
    required this.permissions,
    required this.onboarding,
    required this.sounds,
    required this.lostPasskey,
    required this.passkeyErrors,
    required this.recoveryAlert,
    required this.workout,
    required this.plan,
    required this.exercise,
    required this.yourData,
    required this.endWorkoutDialog,
    required this.exercisePicker,
    required this.heartRate,
    required this.joinRequest,
    required this.multiplayer,
    required this.menu,
    required this.setLog,
    required this.plates,
    required this.adjustWeight,
    required this.templateUpdate,
    required this.participant,
    required this.health,
    required this.restNotification,
    required this.invite,
    required this.sessionExpired,
    required this.updateRequired,
    required this.errorDialog,
    required this.templateEditor,
    required this.history,
    required this.progress,
    required this.home,
    required this.workoutPage,
    required this.startup,
    required this.summary,
    required this.settings,
    required this.profileMarker,
    required this.passkeys,
    required this.addPasskey,
    required this.plateColours,
    required this.learn,
    required this.science,
    required this.maths,
  });
}

class CopyMaths {
  final String title;
  final String estimationLabel;
  final String estimationTitle;
  final String estimationBody;
  final String formulaLabel;
  final String termMet;
  final String termConstant;
  final String termWeight;
  final String termMinutes;
  final String termDivisor;
  final String yourEstimateLabel;
  final String example;
  final String exampleResult;
  final String noWeight;
  final String tonnageLabel;
  final String tonnageTitle;
  final String tonnageBody;
  final String accuracyLabel;
  final String accuracyTitle;
  final String accuracyBody;
  final String referencesLabel;
  final List<String> references;
  const CopyMaths({
    required this.title,
    required this.estimationLabel,
    required this.estimationTitle,
    required this.estimationBody,
    required this.formulaLabel,
    required this.termMet,
    required this.termConstant,
    required this.termWeight,
    required this.termMinutes,
    required this.termDivisor,
    required this.yourEstimateLabel,
    required this.example,
    required this.exampleResult,
    required this.noWeight,
    required this.tonnageLabel,
    required this.tonnageTitle,
    required this.tonnageBody,
    required this.accuracyLabel,
    required this.accuracyTitle,
    required this.accuracyBody,
    required this.referencesLabel,
    required this.references,
  });
}

class CopyScience {
  final String title;
  final String intro;
  final List<CopyScienceSectionsItem> sections;
  final String honesty;
  const CopyScience({
    required this.title,
    required this.intro,
    required this.sections,
    required this.honesty,
  });
}

class CopyScienceSectionsItem {
  final String id;
  final String title;
  final String body;
  const CopyScienceSectionsItem({
    required this.id,
    required this.title,
    required this.body,
  });
}

class CopyLearn {
  final String title;
  final String tutorial;
  final String tutorialSub;
  final String science;
  final String scienceSub;
  final String maths;
  final String mathsSub;
  const CopyLearn({
    required this.title,
    required this.tutorial,
    required this.tutorialSub,
    required this.science,
    required this.scienceSub,
    required this.maths,
    required this.mathsSub,
  });
}

class CopyPlateColours {
  final String title;
  final String red;
  final String blue;
  final String green;
  final String yellow;
  final String amber;
  final String orange;
  final String purple;
  final String pink;
  final String teal;
  final String white;
  final String lightGrey;
  final String grey;
  final String darkGrey;
  final String black;
  final String brown;
  final String custom;
  const CopyPlateColours({
    required this.title,
    required this.red,
    required this.blue,
    required this.green,
    required this.yellow,
    required this.amber,
    required this.orange,
    required this.purple,
    required this.pink,
    required this.teal,
    required this.white,
    required this.lightGrey,
    required this.grey,
    required this.darkGrey,
    required this.black,
    required this.brown,
    required this.custom,
  });
}

class CopyAddPasskey {
  final String title;
  final String body;
  final String name;
  final String nameHint;
  final String nameRequired;
  final String submit;
  final String adding;
  const CopyAddPasskey({
    required this.title,
    required this.body,
    required this.name,
    required this.nameHint,
    required this.nameRequired,
    required this.submit,
    required this.adding,
  });
}

class CopyPasskeys {
  final String title;
  final String heading;
  final String none;
  final String add;
  final String unnamed;
  final String added;
  final String transportInternal;
  final String transportUsb;
  final String transportNfc;
  final String transportBle;
  final String transportHybrid;
  final String onlyOne;
  final String loadFailed;
  final String deleteFailed;
  final String deleteTitle;
  final String deleteWarning;
  final String deleteBody;
  final String deleteCancel;
  final String deleteConfirm;
  const CopyPasskeys({
    required this.title,
    required this.heading,
    required this.none,
    required this.add,
    required this.unnamed,
    required this.added,
    required this.transportInternal,
    required this.transportUsb,
    required this.transportNfc,
    required this.transportBle,
    required this.transportHybrid,
    required this.onlyOne,
    required this.loadFailed,
    required this.deleteFailed,
    required this.deleteTitle,
    required this.deleteWarning,
    required this.deleteBody,
    required this.deleteCancel,
    required this.deleteConfirm,
  });
}

class CopyProfileMarker {
  final String title;
  final String eyebrow;
  final String heading;
  final String body;
  final String previewTitle;
  final String previewBody;
  final String emojis;
  final String refresh;
  final String colours;
  final String save;
  final String saveFailed;
  const CopyProfileMarker({
    required this.title,
    required this.eyebrow,
    required this.heading,
    required this.body,
    required this.previewTitle,
    required this.previewBody,
    required this.emojis,
    required this.refresh,
    required this.colours,
    required this.save,
    required this.saveFailed,
  });
}

class CopySettings {
  final String title;
  final String youHeading;
  final String bodyWeight;
  final String bodyWeightNotSet;
  final String bodyWeightSync;
  final String bodyWeightSynced;
  final String bodyWeightNotFound;
  final String bodyWeightSyncFailed;
  final String bodyWeightSaveFailed;
  final String bodyWeightBody;
  final String bodyWeightField;
  final String save;
  final String weightUnit;
  final String pounds;
  final String poundsSub;
  final String kilograms;
  final String kilogramsSub;
  final String plateColours;
  final String plateColoursSub;
  final String accountHeading;
  final String sync;
  final String syncUpToDate;
  final String syncSending;
  final String syncOffline;
  final String syncOfflineWaiting;
  final String passkeys;
  final String passkeysSub;
  final String soundsHeading;
  final String sound;
  final String soundSub;
  final String behindHeading;
  final String debug;
  final String debugSub;
  final String logs;
  final String logsSub;
  final String buildInfo;
  final String buildInfoSub;
  const CopySettings({
    required this.title,
    required this.youHeading,
    required this.bodyWeight,
    required this.bodyWeightNotSet,
    required this.bodyWeightSync,
    required this.bodyWeightSynced,
    required this.bodyWeightNotFound,
    required this.bodyWeightSyncFailed,
    required this.bodyWeightSaveFailed,
    required this.bodyWeightBody,
    required this.bodyWeightField,
    required this.save,
    required this.weightUnit,
    required this.pounds,
    required this.poundsSub,
    required this.kilograms,
    required this.kilogramsSub,
    required this.plateColours,
    required this.plateColoursSub,
    required this.accountHeading,
    required this.sync,
    required this.syncUpToDate,
    required this.syncSending,
    required this.syncOffline,
    required this.syncOfflineWaiting,
    required this.passkeys,
    required this.passkeysSub,
    required this.soundsHeading,
    required this.sound,
    required this.soundSub,
    required this.behindHeading,
    required this.debug,
    required this.debugSub,
    required this.logs,
    required this.logsSub,
    required this.buildInfo,
    required this.buildInfoSub,
  });
}

class CopySummary {
  final String title;
  final String loadFailed;
  final String retry;
  final String session;
  final String duration;
  final String volume;
  final String sets;
  final String reps;
  final String max;
  final String heart;
  final String trainedWith;
  final String solo;
  final String loading;
  final String exercises;
  final String heaviestSet;
  const CopySummary({
    required this.title,
    required this.loadFailed,
    required this.retry,
    required this.session,
    required this.duration,
    required this.volume,
    required this.sets,
    required this.reps,
    required this.max,
    required this.heart,
    required this.trainedWith,
    required this.solo,
    required this.loading,
    required this.exercises,
    required this.heaviestSet,
  });
}

class CopyStartup {
  final String exitTitle;
  final String exitBody;
  final String exitCancel;
  final String exitConfirm;
  final String failed;
  final String retry;
  const CopyStartup({
    required this.exitTitle,
    required this.exitBody,
    required this.exitCancel,
    required this.exitConfirm,
    required this.failed,
    required this.retry,
  });
}

class CopyWorkoutPage {
  final String tabWorkout;
  final String tabLog;
  final String tabHeart;
  final String noHeartRate;
  final String noHeartRateBody;
  final String addExercise;
  final String weightAndReps;
  const CopyWorkoutPage({
    required this.tabWorkout,
    required this.tabLog,
    required this.tabHeart,
    required this.noHeartRate,
    required this.noHeartRateBody,
    required this.addExercise,
    required this.weightAndReps,
  });
}

class CopyHome {
  final String start;
  final String emptyChip;
  final String emptyTitle;
  final String emptyBody;
  final String edit;
  final String deleteTitle;
  final String deleteBody;
  final String deleteCancel;
  final String deleteConfirm;
  final String noTemplates;
  final String noTemplatesBody;
  final String createOne;
  const CopyHome({
    required this.start,
    required this.emptyChip,
    required this.emptyTitle,
    required this.emptyBody,
    required this.edit,
    required this.deleteTitle,
    required this.deleteBody,
    required this.deleteCancel,
    required this.deleteConfirm,
    required this.noTemplates,
    required this.noTemplatesBody,
    required this.createOne,
  });
}

class CopyProgress {
  final String title;
  final String workouts;
  final String lifted;
  final String since;
  final String noneInSpan;
  final String max;
  final String best;
  final String empty;
  final String emptyBody;
  const CopyProgress({
    required this.title,
    required this.workouts,
    required this.lifted,
    required this.since,
    required this.noneInSpan,
    required this.max,
    required this.best,
    required this.empty,
    required this.emptyBody,
  });
}

class CopyHistory {
  final String title;
  final String empty;
  final String workouts;
  final String thisWeek;
  final String untitled;
  final String sets;
  final String withPartners;
  final String twoNames;
  final String friends;
  final String today;
  final String yesterday;
  final String daysAgo;
  final String lastWeek;
  const CopyHistory({
    required this.title,
    required this.empty,
    required this.workouts,
    required this.thisWeek,
    required this.untitled,
    required this.sets,
    required this.withPartners,
    required this.twoNames,
    required this.friends,
    required this.today,
    required this.yesterday,
    required this.daysAgo,
    required this.lastWeek,
  });
}

class CopyTemplateEditor {
  final String newTitle;
  final String editTitle;
  final String nameHint;
  final String empty;
  final String addExercises;
  final String save;
  final String saveFailed;
  const CopyTemplateEditor({
    required this.newTitle,
    required this.editTitle,
    required this.nameHint,
    required this.empty,
    required this.addExercises,
    required this.save,
    required this.saveFailed,
  });
}

class CopyErrorDialog {
  final String title;
  final String ok;
  const CopyErrorDialog({
    required this.title,
    required this.ok,
  });
}

class CopyUpdateRequired {
  final String title;
  final String body;
  final String button;
  const CopyUpdateRequired({
    required this.title,
    required this.body,
    required this.button,
  });
}

class CopyInvite {
  final String invalid;
  final String joined;
  const CopyInvite({
    required this.invalid,
    required this.joined,
  });
}

class CopyRestNotification {
  final String channel;
  final String channelDescription;
  final String title;
  final String nextUp;
  final String nextUpWarmup;
  final String allDone;
  const CopyRestNotification({
    required this.channel,
    required this.channelDescription,
    required this.title,
    required this.nextUp,
    required this.nextUpWarmup,
    required this.allDone,
  });
}

class CopyHealth {
  final String storeAndroid;
  final String storeIos;
  final String uploaded;
  final String uploadFailed;
  const CopyHealth({
    required this.storeAndroid,
    required this.storeIos,
    required this.uploaded,
    required this.uploadFailed,
  });
}

class CopyParticipant {
  final String noWorkout;
  const CopyParticipant({
    required this.noWorkout,
  });
}

class CopyTemplateUpdate {
  final String newTitle;
  final String newBody;
  final String newConfirm;
  final String newDecline;
  final String updateTitle;
  final String updateBody;
  final String updateConfirm;
  final String updateDecline;
  final String nameLabel;
  final String nameHint;
  final String saveFailed;
  const CopyTemplateUpdate({
    required this.newTitle,
    required this.newBody,
    required this.newConfirm,
    required this.newDecline,
    required this.updateTitle,
    required this.updateBody,
    required this.updateConfirm,
    required this.updateDecline,
    required this.nameLabel,
    required this.nameHint,
    required this.saveFailed,
  });
}

class CopyAdjustWeight {
  final String body;
  final String reps;
  final String save;
  final String done;
  final String removeTooltip;
  final String removeTitle;
  final String removeBody;
  final String removeConfirm;
  final String removeCancel;
  const CopyAdjustWeight({
    required this.body,
    required this.reps,
    required this.save,
    required this.done,
    required this.removeTooltip,
    required this.removeTitle,
    required this.removeBody,
    required this.removeConfirm,
    required this.removeCancel,
  });
}

class CopyPlates {
  final String plates;
  final String bar;
  final String total;
  final String none;
  final String dumbbells;
  final String eachSide;
  final String loadingOrder;
  const CopyPlates({
    required this.plates,
    required this.bar,
    required this.total,
    required this.none,
    required this.dumbbells,
    required this.eachSide,
    required this.loadingOrder,
  });
}

class CopySetLog {
  final String heading;
  final String emptyTitle;
  final String emptyBody;
  final String deleteTitle;
  final String deleteBody;
  final String deleteConfirm;
  final String deleteCancel;
  const CopySetLog({
    required this.heading,
    required this.emptyTitle,
    required this.emptyBody,
    required this.deleteTitle,
    required this.deleteBody,
    required this.deleteConfirm,
    required this.deleteCancel,
  });
}

class CopyMenu {
  final String workout;
  final String progress;
  final String history;
  final String learn;
  final String logout;
  final String settings;
  final String multiplayer;
  final String openWatch;
  final String watchMissing;
  final String watchAlreadyOpen;
  final String watchOpening;
  const CopyMenu({
    required this.workout,
    required this.progress,
    required this.history,
    required this.learn,
    required this.logout,
    required this.settings,
    required this.multiplayer,
    required this.openWatch,
    required this.watchMissing,
    required this.watchAlreadyOpen,
    required this.watchOpening,
  });
}

class CopyMultiplayer {
  final String title;
  final String scan;
  final String scanPrompt;
  final String scanCancel;
  final String shareLink;
  final String shareText;
  final String inSession;
  final String friends;
  final String friendsBody;
  final String friendsEmpty;
  final String ask;
  final String asked;
  final String sessionsOne;
  final String sessions;
  final String recently;
  final String today;
  final String yesterday;
  final String daysAgo;
  final String weeksAgo;
  final String monthsAgo;
  const CopyMultiplayer({
    required this.title,
    required this.scan,
    required this.scanPrompt,
    required this.scanCancel,
    required this.shareLink,
    required this.shareText,
    required this.inSession,
    required this.friends,
    required this.friendsBody,
    required this.friendsEmpty,
    required this.ask,
    required this.asked,
    required this.sessionsOne,
    required this.sessions,
    required this.recently,
    required this.today,
    required this.yesterday,
    required this.daysAgo,
    required this.weeksAgo,
    required this.monthsAgo,
  });
}

class CopyJoinRequest {
  final String icon;
  final String wants;
  final String someone;
  final String decline;
  final String accept;
  final String expired;
  const CopyJoinRequest({
    required this.icon,
    required this.wants,
    required this.someone,
    required this.decline,
    required this.accept,
    required this.expired,
  });
}

class CopyHeartRate {
  final String title;
  final String bpm;
  final String zonesByReserve;
  final String zonesByMax;
  final String resting;
  final String window5m;
  final String window10m;
  const CopyHeartRate({
    required this.title,
    required this.bpm,
    required this.zonesByReserve,
    required this.zonesByMax,
    required this.resting,
    required this.window5m,
    required this.window10m,
  });
}

class CopyExercisePicker {
  final String title;
  final String searchHint;
  final String all;
  final String hideMachines;
  final String showMachines;
  final String empty;
  final String save;
  final String discardTitle;
  final String discardBody;
  final String discardConfirm;
  final String discardCancel;
  const CopyExercisePicker({
    required this.title,
    required this.searchHint,
    required this.all,
    required this.hideMachines,
    required this.showMachines,
    required this.empty,
    required this.save,
    required this.discardTitle,
    required this.discardBody,
    required this.discardConfirm,
    required this.discardCancel,
  });
}

class CopyEndWorkoutDialog {
  final String title;
  final String body;
  final String confirm;
  final String cancel;
  const CopyEndWorkoutDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.cancel,
  });
}

class CopyYourData {
  final String settingsRow;
  final String settingsRowSub;
  final String title;
  final String exportHeading;
  final String exportBody;
  final String exportDownload;
  final String exporting;
  final String exported;
  final String saved;
  final String importHeading;
  final String importBody;
  final String importButton;
  final String importing;
  final String imported;
  final String importConfirmTitle;
  final String importConfirmBody;
  final String importConfirm;
  final String importCancel;
  final String exportFailed;
  final String importFailed;
  const CopyYourData({
    required this.settingsRow,
    required this.settingsRowSub,
    required this.title,
    required this.exportHeading,
    required this.exportBody,
    required this.exportDownload,
    required this.exporting,
    required this.exported,
    required this.saved,
    required this.importHeading,
    required this.importBody,
    required this.importButton,
    required this.importing,
    required this.imported,
    required this.importConfirmTitle,
    required this.importConfirmBody,
    required this.importConfirm,
    required this.importCancel,
    required this.exportFailed,
    required this.importFailed,
  });
}

class CopyExercise {
  final String records;
  final String peakMax;
  final String heaviestSet;
  final String mostReps;
  final String biggestSession;
  final String longestBreak;
  final String breakDays;
  final String pace;
  final String perWeek;
  final String lastTrained;
  final String today;
  final String yesterday;
  final String daysAgo;
  final String gain;
  final String gainSince;
  final String noneInSpan;
  final String noneHere;
  final String empty;
  final String estimatedMax;
  final String heaviestLastTime;
  final String reps;
  final String sessions;
  final String totalSets;
  final String volume;
  final String sessionLine;
  const CopyExercise({
    required this.records,
    required this.peakMax,
    required this.heaviestSet,
    required this.mostReps,
    required this.biggestSession,
    required this.longestBreak,
    required this.breakDays,
    required this.pace,
    required this.perWeek,
    required this.lastTrained,
    required this.today,
    required this.yesterday,
    required this.daysAgo,
    required this.gain,
    required this.gainSince,
    required this.noneInSpan,
    required this.noneHere,
    required this.empty,
    required this.estimatedMax,
    required this.heaviestLastTime,
    required this.reps,
    required this.sessions,
    required this.totalSets,
    required this.volume,
    required this.sessionLine,
  });
}

class CopyPlan {
  final String budget;
  final String calibration;
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
    required this.calibration,
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
  const CopyPlanSummary({
    required this.planned,
  });
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
  final String calibrationStepDown;
  final String calibrationSettled;
  final String correction;
  const CopyPlanChanges({
    required this.userAdjust,
    required this.calibrationStep,
    required this.calibrationStepDown,
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
  final String discardWorkout;
  final String discardTitle;
  final String discardBody;
  final String discardConfirm;
  final String discardCancel;
  final String setLine;
  final String warmupLine;
  final String warmupLabel;
  final String workingLabel;
  final String upNext;
  final String skipWarmups;
  final String firstTimeTitle;
  final String firstTimeTest;
  final String firstTimeStatus;
  final String watchFirstTimeStatus;
  final String rungQuestion;
  final String rungCircleHint;
  final String rungMissedSettled;
  final String rungMissedTooHeavy;
  final String rungOk;
  final String rungQuestionHint;
  final String rungAnswerZeroToOne;
  final String rungAnswerTwoToFour;
  final String rungAnswerFivePlus;
  final String rungOutcomeNext;
  final String rungOutcomeSettle;
  final String rungOr;
  final String rungJumpLabel;
  final String rungJumpApply;
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
    required this.discardWorkout,
    required this.discardTitle,
    required this.discardBody,
    required this.discardConfirm,
    required this.discardCancel,
    required this.setLine,
    required this.warmupLine,
    required this.warmupLabel,
    required this.workingLabel,
    required this.upNext,
    required this.skipWarmups,
    required this.firstTimeTitle,
    required this.firstTimeTest,
    required this.firstTimeStatus,
    required this.watchFirstTimeStatus,
    required this.rungQuestion,
    required this.rungCircleHint,
    required this.rungMissedSettled,
    required this.rungMissedTooHeavy,
    required this.rungOk,
    required this.rungQuestionHint,
    required this.rungAnswerZeroToOne,
    required this.rungAnswerTwoToFour,
    required this.rungAnswerFivePlus,
    required this.rungOutcomeNext,
    required this.rungOutcomeSettle,
    required this.rungOr,
    required this.rungJumpLabel,
    required this.rungJumpApply,
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

class CopyRecoveryAlert {
  final String body;
  final String deny;
  const CopyRecoveryAlert({
    required this.body,
    required this.deny,
  });
}

class CopyPasskeyErrors {
  final String unknown;
  final String notApproved;
  final String notVerified;
  final String alreadyHeld;
  final String tooSlow;
  const CopyPasskeyErrors({
    required this.unknown,
    required this.notApproved,
    required this.notVerified,
    required this.alreadyHeld,
    required this.tooSlow,
  });
}

class CopyLostPasskey {
  final String button;
  final String title;
  final String body;
  final String note;
  final String recoverButton;
  const CopyLostPasskey({
    required this.button,
    required this.title,
    required this.body,
    required this.note,
    required this.recoverButton,
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
  final String profileFailed;
  final CopyOnboardingMarker marker;
  final CopyOnboardingUnit unit;
  final CopyOnboardingStrength strength;
  final CopyOnboardingWeight weight;
  final CopyOnboardingTemplates templates;
  const CopyOnboarding({
    required this.next,
    required this.back,
    required this.profileFailed,
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
  final String checkBody;
  final String overlap;
  final String adds;
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
    required this.checkBody,
    required this.overlap,
    required this.adds,
  });
}

class CopyLibrary {
  final String newButton;
  final String editButton;
  final String sheetTitle;
  final String rotationHeading;
  final String reservesHeading;
  final String rotationDescription;
  final String reservesDescription;
  final String addHeading;
  final String rotationEmptyHome;
  final String dropHere;
  final String addToPlan;
  final String plansHeading;
  final String applyPlan;
  final String planCurrent;
  final String personal;
  final String clone;
  final String remove;
  final String delete;
  final String cancel;
  final String loadingFailed;
  final String empty;
  const CopyLibrary({
    required this.newButton,
    required this.editButton,
    required this.sheetTitle,
    required this.rotationHeading,
    required this.reservesHeading,
    required this.rotationDescription,
    required this.reservesDescription,
    required this.addHeading,
    required this.rotationEmptyHome,
    required this.dropHere,
    required this.addToPlan,
    required this.plansHeading,
    required this.applyPlan,
    required this.planCurrent,
    required this.personal,
    required this.clone,
    required this.remove,
    required this.delete,
    required this.cancel,
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
  final String target;
  final String title;
  final String body;
  const CopyTutorialStepsItem({
    required this.target,
    required this.title,
    required this.body,
  });
}

const copy = Copy(tutorial: CopyTutorial(skip: 'SKIP', next: 'NEXT', previous: 'BACK', finish: 'LET\'S SCHLIFT', papersButton: 'READ THE PAPERS', steps: [CopyTutorialStepsItem(target: 'home_volume', title: 'I\'m tracking your muscles.', body: 'Not in a creepy way though. I\'ll let you know which muscle groups need more work and which have rested enough.'), CopyTutorialStepsItem(target: 'home_templates', title: 'Pick your workout', body: 'The star is today\'s suggestion, picked from whatever covers the most unworked muscles. You can pick whatever you want though, ie butt again.'), CopyTutorialStepsItem(target: 'home_add', title: 'Need more options?', body: 'We\'re spoilt for choice in today\'s society. Continue being spoilt by browsing the lovingly curated set of workouts to add to your rotation, or make your own.'), CopyTutorialStepsItem(target: 'home_time', title: 'I got your number(s)', body: 'You\'re working hard in the gym. I\'m working hard crunching the numbers. What a team. Tell me how long you want to work out and on which workout template, I\'ll figure out the rest.'), CopyTutorialStepsItem(target: 'home_start', title: 'Start', body: 'Pressing Start is how you Start. Let\'s get schlifting!')]), library: CopyLibrary(newButton: 'New', editButton: 'Manage', sheetTitle: 'Your workouts', rotationHeading: 'Rotation', reservesHeading: 'Reserves', rotationDescription: 'The workouts the app picks from when suggesting the best workout to do next.', reservesDescription: 'In case you want to sneak a cheeky butt sesh, keep it here ready to choose.', addHeading: 'Add', rotationEmptyHome: 'Nothing in the rotation. Manage puts some in.', dropHere: 'Drag a workout here', addToPlan: 'Add to the rotation', plansHeading: 'Ready-made plans', applyPlan: 'Make this the rotation', planCurrent: 'Current', personal: 'Personalised', clone: 'Clone', remove: 'Remove', delete: 'Delete', cancel: 'Cancel', loadingFailed: 'Couldn\'t load the library. Check your connection.', empty: 'The library is empty. Someone deleted the internet.'), rotation: CopyRotation(switchLabel: 'In the rotation', switchHint: 'The suggestion picks from these. Off, it\'s a reserve.', add: 'Move to rotation', remove: 'Move to reserves', restedOne: '{muscles} this week, rested', restedTwo: '{muscles} this week, both rested', and: 'and', recovering: '{muscle} recovering ({hours}h)', fallback: 'Everything\'s recovering or done. This one\'s waited longest.', firstLift: 'Every workout starts on something sore. First back: {muscle}, in {hours}h.', checkBody: 'Here\'s what an average rotation would work. Got enough butt in it? Legs? Biceps? Move things into your rotation that we cycle through to make sure you\'re sculpting the right bits.', overlap: '{a} and {b} share {shared} of {of} lifts.', adds: 'Trains {muscles}, which you don\'t have.'), login: CopyLogin(newUserTab: 'NEW USER', signInTab: 'SIGN IN', usernamePrompt: 'What should we call you', usernameExamples: ['squat_master_9000', 'bench_press_king', 'iron_addict', 'gains_goblin', 'reps_for_jesus', 'dorito_pump', 'senior_minister_of_gains', 'chicken_and_rice', 'gluteus_maximus_prime', 'anabolic_pigeon', 'whey_too_much', 'bicep_charles', 'chuck_norris', 'preworkout_heartbeat', 'creatine_gremlin', 'quadzilla_jr', 'quadzilla_sr', 'deltoid_dan', 'shrugged_off', 'gym_shark_bait', 'tuna_shake', 'failed_pr', 'broccoli_boy'], usernameRequired: 'you gotta pick a username', createAccount: 'Create account', signInBlurb: 'Use a passkey on your device to sign in securely.', signIn: 'Sign in', devLoginHeading: 'DEV NAME LOGIN', devUsername: 'Username', devLogin: 'Dev Login'), permissions: CopyPermissions(title: 'Studies show that people who give this app the permissions it needs get 23% more huge', button: 'GRANT PERMISSIONS'), onboarding: CopyOnboarding(next: 'NEXT', back: 'BACK', profileFailed: 'You still gotta pick your emoji mate. The menu has an option to change it.', marker: CopyOnboardingMarker(title: 'Which emoji do you identify as', body: 'The hardest question in the whole signup.', refresh: 'These ones suck'), unit: CopyOnboardingUnit(title: 'Favourite unit?', body: 'Ie are you in America', pounds: 'Pounds', poundsBody: 'Best for making you think you lift more because the number is larger.', kilograms: 'Kilograms', kilogramsBody: 'Best for science and everywhere except America'), strength: CopyOnboardingStrength(title: 'How huge are you', body: 'This does not reflect on who you are as a person, just helps me get your starting weight right.', note: 'You can change these later don\'t worry.', emojis: ['🐣', '🐥', '🐤', '🐔', '🐇', '🐕', '🐒', '🐎', '🐂', '🦍'], lifts: [CopyOnboardingStrengthLiftsItem(id: 'squat', label: 'Squat'), CopyOnboardingStrengthLiftsItem(id: 'bench_press', label: 'Bench press'), CopyOnboardingStrengthLiftsItem(id: 'deadlift', label: 'Deadlift'), CopyOnboardingStrengthLiftsItem(id: 'overhead_press', label: 'Overhead press')]), weight: CopyOnboardingWeight(title: 'Weight', body: 'We log calories burned for you into your fitness tracker because that\'s the only reason to go to the gym. Calories burned is proportional to weight. Leave it blank and we use an average.', field: 'Bodyweight', failed: 'Setup failed: {error}. Try again.'), templates: CopyOnboardingTemplates(title: 'Pick your rotation', body: 'You can add, remove, or edit them later. Pretty cool.', noneSelected: 'Pick at least one. Or one hundred.', finish: 'START LIFTING')), sounds: [CopySoundsItem(id: 'microwave_ding', name: 'Microwave ding'), CopySoundsItem(id: 'referee_whistle', name: 'Referee whistle'), CopySoundsItem(id: 'you_died', name: 'You died'), CopySoundsItem(id: 'notification', name: 'Notification'), CopySoundsItem(id: 'police_whistle', name: 'Police whistle'), CopySoundsItem(id: 'slide_whistle', name: 'Slide whistle'), CopySoundsItem(id: 'wolf_whistle', name: 'Wolf whistle'), CopySoundsItem(id: 'nature_whistle', name: 'Whistle'), CopySoundsItem(id: 'metallic_clang', name: 'Metallic clang'), CopySoundsItem(id: 'opening_bell', name: 'Opening bell'), CopySoundsItem(id: 'bell_ring', name: 'Bell ring'), CopySoundsItem(id: 'winner_bell', name: 'Winner bell'), CopySoundsItem(id: 'creepy_bell', name: 'Creepy bell'), CopySoundsItem(id: 'big_bell', name: 'Big bell'), CopySoundsItem(id: 'big_ben', name: 'Big Ben'), CopySoundsItem(id: 'dirty_siren', name: 'Dirty siren'), CopySoundsItem(id: 'mega_horn', name: 'Mega horn'), CopySoundsItem(id: 'kamata_grito', name: 'Kamata grito'), CopySoundsItem(id: 'angry_siren', name: 'Angry siren'), CopySoundsItem(id: 'car_horn', name: 'Vintage car horn'), CopySoundsItem(id: 'air_horn', name: 'Air horn'), CopySoundsItem(id: 'truck_horn', name: 'Truck horn'), CopySoundsItem(id: 'tada', name: 'Ta-da')], lostPasskey: CopyLostPasskey(button: 'Lost passkey?', title: 'Lost passkey', body: 'This is so sad. Please double check if you saved the passkey in a random place. It could be in google chrome, the apple passwords app, your password manager - every app seems to include a password manager these days. If you looked really hard and still can\'t find it click below.', note: 'Please note that by clicking below you admit you did not read the advice about making sure to not lose my passkey.', recoverButton: 'Make a new passkey'), passkeyErrors: CopyPasskeyErrors(unknown: 'That passkey isn\'t linked to an account any more. Delete it from your password manager and pick another, or tap Lost passkey.', notApproved: 'this replacement passkey is not approved yet mate. please wait for it to be approved.', notVerified: 'Your password manager didn\'t check it was you. Unlock it and try again.', alreadyHeld: 'This password manager already has a passkey for this account. Save the new one somewhere else.', tooSlow: 'That took too long. Try again.'), recoveryAlert: CopyRecoveryAlert(body: 'Someone made a new passkey for your account and asked Brendan to approve it. If that wasn\'t you, stop it.', deny: 'NOT ME'), workout: CopyWorkout(start: 'Start', done: 'Done', ready: 'Ready', lifting: 'Lifting', yapping: 'Yapping', resting: 'Resting', allDone: 'All done', choosing: 'Choosing workout', endWorkout: 'End workout', discardWorkout: 'Discard workout', discardTitle: 'Discard this workout?', discardBody: 'It\'s gone from your history and your plans, as if it never happened. This can\'t be undone.', discardConfirm: 'Discard', discardCancel: 'Keep it', setLine: 'Set {n} of {m}', warmupLine: 'Warmup {n} of {m}', warmupLabel: 'WARMUP', workingLabel: 'WORKING', upNext: 'UP\nNEXT!', skipWarmups: 'Skip', firstTimeTitle: 'First time doing {exercise}.', firstTimeTest: 'Test me from {weight}', firstTimeStatus: 'First time!', watchFirstTimeStatus: 'Open phone!', rungQuestion: 'How many more could you have done?', rungCircleHint: 'Missed some? Tap the circle once for each rep you didn\'t get. Works the same on every set.', rungMissedSettled: 'Missed {n}. Ramp done: working sets at {weight}.', rungMissedTooHeavy: 'Too heavy. Next set {weight}.', rungOk: 'OK', rungQuestionHint: 'Be honest. The next set and your integrity depends on it.', rungAnswerZeroToOne: '0–1', rungAnswerTwoToFour: '2–4', rungAnswerFivePlus: '5+', rungOutcomeNext: 'Next set {weight} (+{jump})', rungOutcomeSettle: 'Done. Working sets at {weight}', rungOr: 'or', rungJumpLabel: 'Specific jump', rungJumpApply: 'Add that', watchEachSide: 'each side', watchMinLeft: '{n} min', watchUnderAMin: '<1 min', watchMinOver: '+{n} min', watchRestUntil: 'till {time}', emptyBar: 'Bar', hints: CopyWorkoutHints(ready: 'Tap the orange circle to start the set.', lifting: 'Tap the circle again when the set is done.', resting: 'Missed reps? Tap that circle once for each.', yapping: 'Rest is over. Tap the next circle to start.', allDone: 'That\'s everything. End the workout when you\'re ready.')), plan: CopyPlan(budget: '{min} min', calibration: 'Calibration session due to new exercise. Go in and try your darndest.', estimate: '~{min} min', longest: '~{min} min · the longest it gets', needs: 'Needs {min} min', ramp: 'Ramp from {weight}', reasons: CopyPlanReasons(maxUp: 'Hit every rep. Max up to {max}.', maxFromMiss: 'Missed a rep. Max back to {max}.', held: 'Max held at {max}.', heldRushed: 'Held at {max}: you missed a set you didn\'t rest for.', heldStoppedEarly: 'Held at {max}: you stopped early.', timeOff: '{days} days off. Max cut to {max}.', firstTime: 'First time. The ramp finds your max.', firstTimeBodyweight: 'First time. Bottom of the range.', userSet: 'Your numbers, from {date}.', setsExtra: '{sets} sets. {muscle} is behind this week.', setsFloor: '{sets} sets. That\'s what the time fits.'), versus: CopyPlanVersus(weightUp: 'Up to {after}', weightDown: 'Down to {after}', repsUpOne: 'One more rep', repsUp: '{n} more reps', repsDownOne: 'One rep fewer', repsDown: '{n} fewer reps', same: 'Same as last time', hit: 'every rep last time', missed: 'missed reps last time', stoppedEarly: 'stopped early last time', rushed: 'you missed a set you didn\'t rest for', sets: '{sets} sets today, {last} last time', timeOff: '{days} days off'), changes: CopyPlanChanges(userAdjust: 'You changed it: {before} → {after}', calibrationStep: 'Ramp: {before} → {after}', calibrationStepDown: 'Too heavy: ramp down to {after}', calibrationSettled: 'Ramp done: {after}', correction: 'Fixed a set: {before} → {after}'), override: CopyPlanOverride(body: 'Your weight and reps. I carry on from here.', weight: 'Weight', reps: 'Reps', sets: 'Sets', setsAuto: 'From the time', save: 'SAVE', remove: 'Let the plan decide', custom: 'yours'), summary: CopyPlanSummary(planned: 'Planned: {plan}')), exercise: CopyExercise(records: 'Records', peakMax: 'Peak max', heaviestSet: 'Heaviest set', mostReps: 'Most reps', biggestSession: 'Biggest session', longestBreak: 'Longest break', breakDays: '{days} days', pace: 'Pace', perWeek: '{n} a week', lastTrained: 'Last trained', today: 'Today', yesterday: 'Yesterday', daysAgo: '{days} days ago', gain: 'Gain', gainSince: 'since {date}', noneInSpan: 'None in the last {span}.', noneHere: 'Nothing in this stretch.', empty: 'No completed sets for this lift yet.', estimatedMax: 'estimated max', heaviestLastTime: 'heaviest set last time', reps: '{n} reps', sessions: 'Sessions', totalSets: 'Total sets', volume: 'Volume', sessionLine: '{sets} sets · {volume}'), yourData: CopyYourData(settingsRow: 'Your data', settingsRowSub: 'Take a copy, or bring one back', title: 'Your data', exportHeading: 'Take a copy', exportBody: 'Everything this phone knows about your training, as one SQLite file, gzipped. Any SQLite tool opens it once it\'s unzipped.', exportDownload: 'Download', exporting: 'Packing it up…', exported: 'Ready: {size}', saved: 'Saved: {size}', importHeading: 'Bring one back', importBody: 'Add what\'s in an export of your account, gzipped or not, to this phone\'s copy. Nothing is removed.', importButton: 'Import a file', importing: 'Bringing it back…', imported: 'Done. Anything this phone was missing from the file is added.', importConfirmTitle: 'Import a file?', importConfirmBody: 'Importing adds anything from the file that this phone and the server are missing, and removes nothing. What\'s there already isn\'t added twice, so the same file again changes nothing.', importConfirm: 'Import', importCancel: 'Cancel', exportFailed: 'EXPORT FAILED: {error}', importFailed: 'IMPORT FAILED: {error}'), endWorkoutDialog: CopyEndWorkoutDialog(title: 'End Workout?', body: 'This will end your current workout.', confirm: 'End Workout', cancel: 'Cancel'), exercisePicker: CopyExercisePicker(title: 'Select exercises', searchHint: 'Search exercises…', all: 'ALL', hideMachines: 'HIDE MACHINES', showMachines: 'SHOW MACHINES', empty: 'No exercises found', save: 'SAVE', discardTitle: 'Discard changes?', discardBody: 'Your selection has not been saved.', discardConfirm: 'Discard', discardCancel: 'Keep editing'), heartRate: CopyHeartRate(title: 'HEART RATE', bpm: 'BPM', zonesByReserve: 'HRR', zonesByMax: '%MAX', resting: 'zzz {bpm}', window5m: '5m', window10m: '10m'), joinRequest: CopyJoinRequest(icon: '🏋️', wants: '{name} wants to train with you', someone: 'A friend', decline: 'Decline', accept: 'Accept', expired: 'Request expired, they may not like you any more.'), multiplayer: CopyMultiplayer(title: 'Multiplayer', scan: 'Scan', scanPrompt: 'Point at your friend’s code', scanCancel: 'Cancel', shareLink: 'Share link', shareText: 'Join my workout on Schlift: {url}', inSession: 'In your session', friends: 'Friends', friendsBody: 'People you’ve trained with. Tap Ask and they get a request to join your session.', friendsEmpty: 'No training partners yet. Do a session with someone (scan their code or open their link) and they’ll show up here to re-invite in one tap.', ask: 'Ask', asked: 'Asked {name} to train. Waiting for them to accept', sessionsOne: '1 session', sessions: '{n} sessions', recently: 'recently', today: 'today', yesterday: 'yesterday', daysAgo: '{n} days ago', weeksAgo: '{n}w ago', monthsAgo: '{n}mo ago'), menu: CopyMenu(workout: 'Workout', progress: 'Progress', history: 'History', learn: 'Learn', logout: 'Logout', settings: 'Settings', multiplayer: 'Multiplayer', openWatch: 'Open watch app', watchMissing: 'No paired watch with Schlift installed', watchAlreadyOpen: 'Schlift is already open on your watch', watchOpening: 'Open Schlift on your wrist to connect'), setLog: CopySetLog(heading: 'Completed sets · {n}', emptyTitle: 'NO SETS YET', emptyBody: 'Get schlifting mate', deleteTitle: 'Delete Completed Set?', deleteBody: 'Remove set {weight} × {reps}? This cannot be undone.', deleteConfirm: 'Delete', deleteCancel: 'Cancel'), plates: CopyPlates(plates: 'Plates', bar: 'Bar', total: 'Total', none: 'None', dumbbells: 'Dumbbells', eachSide: 'each side', loadingOrder: 'Each side, in loading order'), adjustWeight: CopyAdjustWeight(body: 'Changes {name} for the rest of this workout and for next time.', reps: 'Reps', save: 'SAVE', done: 'DONE', removeTooltip: 'Remove from this workout', removeTitle: 'Remove {exercise}?', removeBody: 'This will remove its remaining sets. Sets you already did stay.', removeConfirm: 'Remove', removeCancel: 'Cancel'), templateUpdate: CopyTemplateUpdate(newTitle: 'Save as a template?', newBody: 'Keep this session one tap away next time:', newConfirm: 'Save template', newDecline: 'No thanks', updateTitle: 'Update \'{name}\'?', updateBody: 'This session did not match the template. Make the template match what you did:', updateConfirm: 'Update template', updateDecline: 'Keep as is', nameLabel: 'Template name', nameHint: 'e.g. Push, Tuesday', saveFailed: 'Could not save: {error}'), participant: CopyParticipant(noWorkout: 'No workout yet.'), health: CopyHealth(storeAndroid: 'Health Connect', storeIos: 'Apple Health', uploaded: 'Successfully uploaded to {store}', uploadFailed: 'Failed to sync workout to {store}'), restNotification: CopyRestNotification(channel: 'Rest Timer', channelDescription: 'Rest timer completion alert', title: 'Rest Complete', nextUp: 'Next up: {exercise}, {set}', nextUpWarmup: 'Next up: Warmup {exercise}, {set}', allDone: 'All sets complete!'), invite: CopyInvite(invalid: 'INVALID INVITE CODE', joined: 'JOINED GROUP'), sessionExpired: 'Sign in again to sync this phone with your account.', updateRequired: CopyUpdateRequired(title: 'Update needed', body: 'New app version lovingly crafted for you is ready. Download it to continue.', button: 'UPDATE'), errorDialog: CopyErrorDialog(title: 'Error', ok: 'OK'), templateEditor: CopyTemplateEditor(newTitle: 'New workout', editTitle: 'Edit workout', nameHint: 'Name, e.g. Push, Legs, Tuesday', empty: 'Add exercises. Tap one to set your own weight and reps. They follow the exercise everywhere.', addExercises: 'ADD EXERCISES', save: 'SAVE', saveFailed: 'Could not save: {error}'), history: CopyHistory(title: 'History', empty: 'No completed workouts yet', workouts: 'workouts', thisWeek: 'this week', untitled: 'Workout', sets: '{n} sets', withPartners: 'with {names}', twoNames: '{a} & {b}', friends: 'friends', today: 'Today', yesterday: 'Yesterday', daysAgo: '{days} days ago', lastWeek: 'Last week'), progress: CopyProgress(title: 'Progress', workouts: 'workouts', lifted: '{unit} lifted', since: 'since {date}', noneInSpan: 'No lifts in the last {span}.', max: 'MAX', best: 'BEST', empty: 'No workout history yet', emptyBody: 'Finish a workout and your progress shows up here.'), home: CopyHome(start: 'START', emptyChip: 'Empty', emptyTitle: 'Don\'t tell me what to do', emptyBody: 'I\'ll add exercises as I go. The app still brings the weights, sets and reps for whatever you pick.', edit: 'Edit', deleteTitle: 'Delete {name}?', deleteBody: 'Your weights are safe. They live on the exercises, not the template.', deleteCancel: 'Cancel', deleteConfirm: 'Delete', noTemplates: 'No templates yet', noTemplatesBody: 'A template is just a list of exercises. The app handles the sets, reps and weight.', createOne: 'CREATE ONE'), workoutPage: CopyWorkoutPage(tabWorkout: 'Workout', tabLog: 'Log', tabHeart: 'Heart', noHeartRate: 'No heart rate yet', noHeartRateBody: 'Get the watch app and you can see how hard you are pumping your heart while schlifting.', addExercise: 'Add exercise', weightAndReps: 'Weight and reps'), startup: CopyStartup(exitTitle: 'Exit app?', exitBody: 'Are you sure you want to quit?', exitCancel: 'CANCEL', exitConfirm: 'EXIT', failed: 'Could not finish startup', retry: 'Retry'), summary: CopySummary(title: 'Workout summary', loadFailed: 'Failed to load workout summary.', retry: 'Retry', session: 'Session', duration: 'Duration', volume: 'Volume', sets: 'Sets', reps: 'Reps', max: 'Max', heart: 'Heart', trainedWith: 'Trained with', solo: 'Nobody (solo session)', loading: 'Loading…', exercises: 'Exercises', heaviestSet: 'Heaviest set: {weight}'), settings: CopySettings(title: 'Settings', youHeading: 'You', bodyWeight: 'Body weight', bodyWeightNotSet: 'Not set', bodyWeightSync: 'Sync from health data', bodyWeightSynced: 'Synced body weight to {weight}', bodyWeightNotFound: 'No body weight found in health data', bodyWeightSyncFailed: 'Could not sync body weight', bodyWeightSaveFailed: 'Failed to save body weight', bodyWeightBody: 'Used to estimate calories burned. Stored on your profile.', bodyWeightField: 'Weight', save: 'SAVE', weightUnit: 'Weight unit', pounds: 'Pounds (🦅)', poundsSub: 'Standard US gym loading', kilograms: 'Kilograms (🌍)', kilogramsSub: 'Standard international gym loading', plateColours: 'Plate colours', plateColoursSub: 'Assign colours to plate weights', accountHeading: 'Account', sync: 'Sync', syncUpToDate: 'Up to date', syncSending: 'Sending {n} changes', syncOffline: 'Offline, nothing waiting', syncOfflineWaiting: 'Offline, {n} changes waiting', passkeys: 'Passkeys', passkeysSub: 'Manage your login credentials', soundsHeading: 'Sounds', sound: 'Pick sound', soundSub: 'Choose notification sound', behindHeading: 'Behind the scenes', debug: 'Debug', debugSub: 'Notification debugging', logs: 'App Logs', logsSub: 'View and share diagnostic logs', buildInfo: 'Build info', buildInfoSub: 'Version, device, and watch details'), profileMarker: CopyProfileMarker(title: 'Profile Marker', eyebrow: 'GROUP LOOK', heading: 'Pick your colour and emoji', body: 'This controls the badge and side stripe used for you in group workouts.', previewTitle: 'Group workout preview', previewBody: 'Your emoji replaces the vertical name and your colour owns the sidebar.', emojis: 'EMOJIS', refresh: 'Refresh', colours: 'COLOURS', save: 'SAVE', saveFailed: 'Couldn\'t save your marker. Try again.'), passkeys: CopyPasskeys(title: 'Passkeys', heading: 'Your passkeys', none: 'No passkeys found', add: 'Add passkey', unnamed: 'Passkey {n}', added: 'Added {date}', transportInternal: 'This device', transportUsb: 'USB', transportNfc: 'NFC', transportBle: 'Bluetooth', transportHybrid: 'Phone/Tablet', onlyOne: 'You have one passkey. Add a second in a different password manager, so losing one doesn\'t lock you out.', loadFailed: 'Failed to load passkeys', deleteFailed: 'Failed to delete passkey', deleteTitle: 'Delete Passkey', deleteWarning: 'Make sure you have one of the remaining passkeys before deleting anything. If you don\'t have a valid passkey you cannot recover your account. Your other devices will need to sign in again.', deleteBody: 'Are you sure? This cannot be undone.', deleteCancel: 'Cancel', deleteConfirm: 'Delete'), addPasskey: CopyAddPasskey(title: 'Add Passkey', body: 'Give this passkey a name so you can recognize it later.', name: 'Name', nameHint: 'e.g. Work Phone', nameRequired: 'Name is required.', submit: 'Continue', adding: 'Adding...'), plateColours: CopyPlateColours(title: 'Plate colours', red: 'Red', blue: 'Blue', green: 'Green', yellow: 'Yellow', amber: 'Amber', orange: 'Orange', purple: 'Purple', pink: 'Pink', teal: 'Teal', white: 'White', lightGrey: 'Light Grey', grey: 'Grey', darkGrey: 'Dark Grey', black: 'Black', brown: 'Brown', custom: 'Custom'), learn: CopyLearn(title: 'Learn', tutorial: 'Tutorial', tutorialSub: 'The walkthrough again', science: 'Workout science', scienceSub: 'The papers behind the app', maths: 'Calorie maths', mathsSub: 'How burn is worked out'), science: CopyScience(title: '🧠 Workout science', intro: 'Every number I give you comes from one estimate per lift and the time you said you have. The studies behind it are below.', sections: [CopyScienceSectionsItem(id: 'kinds', title: 'Three kinds of lift', body: 'Barbell compounds are heavy: 5–8 reps, 3:00 rest, warmups first. Every other loaded lift is 8–12 reps with 2:00. Bodyweight and core are 5–15 reps with 1:30. Heavy is better for strength. For size, anything from about 6 to 30 reps works if it\'s hard. Long rest beats short on the big lifts.'), CopyScienceSectionsItem(id: 'max', title: 'Your estimated max', body: 'Each lift has one number: the most I think you could lift once. For bodyweight lifts it\'s the most reps in a set. I work it out from every set you\'ve logged, assuming one rep left in the tank and a bit of fatigue per set. Hit every rep and it goes up a rep\'s worth. Miss one and it drops to what you actually showed. Stop early, or lower the weight yourself, and it stays put.'), CopyScienceSectionsItem(id: 'reps', title: 'Reps and weight', body: 'I keep you at the weight you did last time, for as many reps as your max covers. Past the top of the range, the weight goes up a step. Under the bottom, it comes down to what you can do. So you add a rep a session, then a plate. More reps works about as well as more weight.'), CopyScienceSectionsItem(id: 'sets', title: 'Sets: from your time', body: 'You tell me how long you have on the home screen. Sixty minutes unless you say otherwise. Every lift gets two sets. The rest go one at a time, five at most, to whichever muscle is furthest under ten sets this week. I time your sets and rests, and once I have ten of each I use yours instead of my guesses. If two sets each won\'t fit, I tell you how long it needs.'), CopyScienceSectionsItem(id: 'volume', title: 'Weekly volume: 10–20 sets per muscle', body: 'Ten hard sets a week per muscle beats fewer. Past twenty you\'re mostly just tired. That\'s the band on the home screen.'), CopyScienceSectionsItem(id: 'time_off', title: 'Time off', body: 'Strength holds for about three weeks. Away from a lift longer than that and I cut its max to 90%. Six weeks, 80%. It comes back fast.'), CopyScienceSectionsItem(id: 'first_time', title: 'The first time', body: 'A lift you\'ve never done starts from the weight your emoji picked, or wherever you tell me to start. Sets of 5 from 60% of it, 10% heavier each set, until you miss a rep. Six sets at most. Get all 5 and I ask how many more you had in you. 0–1 and we\'re done there. 2–4, the next set goes up as usual. 5+, it jumps about a fifth, to roughly one rep short of what you showed. Or type exactly how much to add and the next set goes up by that. Don\'t answer and it goes up as usual. Under 3 reps and it was too heavy, which tells me nothing, so the next set is a fifth lighter (never back down to one you already did all 5 of). 3 or 4 reps and we\'re done. The set you got 3 or 4 on, or the one you said 0–1 on, tells me your max, and the rest of the workout comes from that. Bodyweight lifts start at the bottom of the range.'), CopyScienceSectionsItem(id: 'overrides', title: 'Your own numbers', body: 'Tap a lift in a workout\'s editor to give it your own weight and reps, and sets if you want. I work out the max that means and carry on from there. Take them off and I go back to your history.'), CopyScienceSectionsItem(id: 'no_drops', title: 'No automatic drops', body: 'I never lower a weight during a workout. Missed reps? Rest and go again. Cooked? Lower it yourself. I\'ll take the hint next time.'), CopyScienceSectionsItem(id: 'warmups', title: 'Warmups', body: 'Heavy lifts get four warmup sets at about 40, 55, 70 and 85% of the working weight. Everything else warms itself up.'), CopyScienceSectionsItem(id: 'recovery', title: 'Recovery', body: 'Big muscles take about 48 hours, arms and shoulders 36, calves and core 24. The amber marker is a suggestion, not a bouncer.')], honesty: 'Honesty note: the effects in these studies are small and most of them are short. Good programs barely differ. Showing up beats all of it, so I kept it simple.'), maths: CopyMaths(title: 'Calorie maths', estimationLabel: 'CALORIE ESTIMATION', estimationTitle: 'How we estimate calories burned', estimationBody: 'We use the MET (Metabolic Equivalent of Task) formula from the 2011 Compendium of Physical Activities (Ainsworth et al., Med Sci Sports Exerc 43(8):1575–81). Traditional strength training has a MET value of 3.5.', formulaLabel: 'FORMULA', termMet: '3.5 (traditional strength training)', termConstant: 'ml O₂ per kg per min at 1 MET (standard constant)', termWeight: 'your bodyweight in kilograms', termMinutes: 'total workout duration', termDivisor: 'converts ml O₂/min to kcal/min (5 kcal/L O₂ ÷ 1000 × 40)', yourEstimateLabel: 'YOUR ESTIMATE', example: 'EXAMPLE: {min} MIN SESSION', exampleResult: '≈ {kcal} kcal', noWeight: 'Set your bodyweight in Settings → Body weight to get a personalised calorie estimate.', tonnageLabel: 'WHAT ABOUT TONNAGE?', tonnageTitle: 'Volume and calorie burn', tonnageBody: 'Tonnage (sets × reps × weight lifted) does predict calorie expenditure during strength training. A 2006 study by Haddock & Wilkin (Int J Sports Med 27(2):143–8) found that 3-set protocols burned ~2.8× more calories than 1-set protocols of the same exercise.\n\nHowever, when normalised per minute of actual exercise time, calorie rate is roughly constant, meaning total duration already captures most of the tonnage effect. More volume → longer sessions → more calories, which the MET × duration formula handles automatically.\n\nA 2020 regression study found that session time and volume load together explained ~61% of energy expenditure variance (R² = 0.61). The remaining 39% is individual variation in rest periods, exercise selection, and body composition that no formula can capture without direct measurement.', accuracyLabel: 'ACCURACY', accuracyTitle: 'Why this is an estimate', accuracyBody: 'Resistance training has a large anaerobic component (up to 40% of total energy expenditure) that standard indirect calorimetry cannot fully capture, and no phone app can measure it at all. A 2024 systematic review (PMC11393209) found no gold-standard method for resistance training energy expenditure. The MET formula gives a reasonable population-average estimate, accurate to perhaps ±25% for any individual session.\n\nIf no bodyweight is set, we fall back to a flat 5 kcal/min, roughly the midpoint of the 4–10 kcal/min range observed across studies.', referencesLabel: 'REFERENCES', references: ['Ainsworth BE et al. (2011). 2011 Compendium of Physical Activities: A Second Update of Codes and MET Values. Med Sci Sports Exerc, 43(8):1575–81.', 'Haddock CK & Wilkin LD (2006). Resistance training volume and post exercise energy expenditure. Int J Sports Med, 27(2):143–8.', 'Dinyer-McNeely TK et al. (2024). Methods to Assess Energy Expenditure of Resistance Exercise: A Systematic Scoping Review. PMC11393209.']));
