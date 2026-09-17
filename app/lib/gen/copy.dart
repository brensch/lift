// GENERATED FROM app/copy.yaml BY scripts/gen_copy.py — DO NOT EDIT.
// Edit the YAML, then run `make copy`.
// ignore_for_file: type=lint

class Copy {
  final CopyTutorial tutorial;
  const Copy({
    required this.tutorial,
  });
}

class CopyTutorial {
  final String skip;
  final String next;
  final String finish;
  final String papersButton;
  final List<CopyTutorialPagesItem> pages;
  const CopyTutorial({
    required this.skip,
    required this.next,
    required this.finish,
    required this.papersButton,
    required this.pages,
  });
}

class CopyTutorialPagesItem {
  final String key;
  final String title;
  final String body;
  const CopyTutorialPagesItem({
    required this.key,
    required this.title,
    required this.body,
  });
}

const copy = Copy(tutorial: CopyTutorial(skip: 'SKIP', next: 'NEXT', finish: 'LET\'S LIFT', papersButton: 'READ THE PAPERS', pages: [CopyTutorialPagesItem(key: 'volume', title: 'Your muscles, tracked', body: 'Hard sets this week, per muscle. Aim for the band. Yellow means still recovering, a tick means you\'ve done enough.'), CopyTutorialPagesItem(key: 'suggested', title: 'Pick a workout', body: 'The star is today\'s suggestion, picked from whatever is furthest behind. Tap any template to pick it instead. They\'re yours to edit.'), CopyTutorialPagesItem(key: 'plan', title: 'The numbers are handled', body: 'Sets × reps @ weight, all prescribed. The flame means warmups are included.'), CopyTutorialPagesItem(key: 'start', title: 'Start from here', body: 'One tap and the session is on. You can add, remove or reorder exercises once you\'re in.'), CopyTutorialPagesItem(key: 'current_set', title: 'Your current set', body: 'The weight and the reps to hit. Change the weight from here if the bar feels wrong.'), CopyTutorialPagesItem(key: 'timer', title: 'Elapsed · heart rate', body: 'How long you\'ve been going, and your heart rate from the watch if you\'re wearing one.'), CopyTutorialPagesItem(key: 'complete', title: 'Tap when the set is done', body: 'The rest timer starts on its own and tells you when to stop yapping.'), CopyTutorialPagesItem(key: 'progression', title: 'Progress happens by itself', body: 'Clear every set and next time it\'s one more rep. Top of the range and the weight goes up, reps reset. Miss twice and it backs off ten percent.')]));
