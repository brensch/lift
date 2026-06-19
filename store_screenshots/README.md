# App Store Screenshots

Captured on the `lift_api34` Android emulator (1080×2400, dark mode) signed in as
the populated dev account `yessum`.

| # | File | Feature shown |
|---|------|---------------|
| 1 | `01_home_smart_program.png` | Home — adaptive program ("Schplanner") with next-workout countdown, recommended lifts + weights, weekly session progress |
| 2 | `02_workout_briefing.png` | Pre-workout briefing — per-exercise plan with coaching notes (e.g. "Squat held at 235 lb — missed target reps") |
| 3 | `03_active_workout.png` | Active workout — warmup + working sets, exercise list with drag-to-reorder, "next up" bar |
| 4 | `04_live_set_logging.png` | Live set logging — rep picker wheel + set/rest timer |
| 5 | `05_progress_charts.png` | Progress — per-exercise weight-over-time charts |
| 6 | `06_workout_history.png` | History — past sessions with dates and durations |
| 7 | `07_session_analytics.png` | Session analytics — duration/volume/work-density/rest-ratio + auto-progression updates |
| 8 | `08_exercise_totals.png` | Per-exercise totals — sets, reps, volume, estimated 1RM |
| 9 | `09_program_picker.png` | Program picker — Stronglifts 5×5 / GZCLP / Wendler 5/3/1 with next-workout + weights |
| 10 | `10_program_details.png` | Program details — at-a-glance stats and "how it works" |

## Wear OS (`watch/`)

Captured on a Wear OS 5 emulator (`lift_watch`, 384×384) at display density 232.

| File | Feature shown |
|------|---------------|
| `watch/watch_01_active_set.png` | Active set — "Complete Squat", 5×235, set timer, workout elapsed, live 132 BPM |
| `watch/watch_02_rest_timer.png` | Rest — countdown to next set, "Start Squat" 5×235, 118 BPM |
| `watch/watch_03_complete.png` | Workout complete — time / sets / total volume summary |

> Note: the watch screens were rendered via a debug-only snapshot-injection hook in the
> wear module (since CLI pairing of two emulators isn't supported). See the wear source
> changes if you want to keep or remove that hook.
