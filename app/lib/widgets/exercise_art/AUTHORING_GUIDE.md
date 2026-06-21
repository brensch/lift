# Exercise-art authoring guide

You are drawing a looping stick-figure animation of a gym exercise. Each
exercise is one Dart file named after its proto enum (snake_case), exporting one
function. Keep it **simple and roughly accurate** — it must read as the movement
next to a label, nothing more.

## The canvas
- A **100 × 100 box**. `x` grows right, `y` grows **DOWN** (screen coords).
- Figure drawn side-on facing right, OR front-on (see Views).
- Floor is around `y = 90`. Standing head around `y = 8`.

## The figure is a skeleton with FIXED bone lengths, posed by ANGLES
You never place a hand/foot directly. You set the pelvis position and the angle
each limb segment points; the joint falls where the fixed-length bone reaches.
This guarantees limbs never stretch between the two frames.

Angles are **degrees, screen-space**: `0 = right, 90 = down, 180 = left, -90 = up`.

```dart
Figure(
  pelvis: P(50, 52),   // root position
  torso: -90,          // direction pelvis -> neck. -90 = standing upright.
  arms: [Limb(upper, fore), ...],  // 0–2 arms, hung from the neck
  legs: [Limb(thigh, shin), ...],  // 0–2 legs, hung from the pelvis
  headR: 6.5,          // optional, default 6.5
)
```
- `Limb(a, b)`: `a` = direction of the upper segment (upperArm / thigh),
  `b` = direction of the lower segment (forearm / shin).
- A straight leg standing is `Limb(90, 90)` (both point down). A straight arm
  hanging is `Limb(90, 90)`.
- Fixed lengths (box units): torso 26, head offset 9, upperArm 13, forearm 12,
  thigh 19, shin 19. Forward kinematics:
  `neck = pelvis + dir(torso)*26`, `elbow = neck + dir(upper)*13`,
  `hand = elbow + dir(fore)*12`, `knee = pelvis + dir(thigh)*19`,
  `ankle = knee + dir(shin)*19`.

For a **side view**, two arms/legs nearly overlap — give the far one slightly
different angles (e.g. legs `[Limb(91,91), Limb(89,89)]`) so both are visible.

## Views
`ExerciseArt(view: ExerciseView.front, [...])` or `.side` (default).
- **front** — for bars seen head-on (squat, OHP, front squat). Barbell renders as
  a wide bar with a plate at each end.
- **side** — bars seen end-on render as a single plate **ring** on the hand.

## Equipment (welded to the figure — never hand-placed)
- **Barbell** held in hands:
  - `Barbell(hands: [0])` — one hand (side view → ring on that hand).
  - `Barbell(hands: [0, 1], length: 44)` — spans both hands (front view → wide bar).
  - `Barbell(hips: true, nudge: P(0, -6))` — rests on the pelvis (hip thrust).
- **Dumbbell** welded to one hand: `Dumbbell(hand: 0)` (optional `angle`, `nudge`).
- **Machine / bench / cable** — plain polylines in `props` and discs in
  `propDiscs` (pulleys, ankle rollers). Set `ExerciseArt(machine: true, ...)` to
  render all props/discs **grey** (machines). Benches for free-weight moves are
  NOT machines — leave `machine` false so they match the figure colour.
  - A prop polyline: `[P(x1,y1), P(x2,y2), ...]`. A disc: `PropDisc(P(x,y), r)`.

## THE ONE RULE
Both key frames of an exercise must have the **same counts**: same number of
arms, legs, props, propDiscs, barbells, dumbbells (and same points per prop
polyline). Only the angles/positions change between them. Otherwise the tween
falls back to a hard cut.

## Frames
Author exactly **2 poses** normally: start → end. The toolkit tweens + loops
them. Order: frame 0 is the "stretched/loaded" position, frame 1 the
"contracted/finished" position (it doesn't strictly matter — it loops both ways).

## File shape (copy this)
```dart
import 'toolkit.dart';

/// <Name> — <equipment>, <view> view. <start> → <end>.
ExerciseArt <camelName>Art() => const ExerciseArt([
  Pose(
    figure: Figure(pelvis: P(50, 52), torso: -90,
      arms: [Limb(90, 90)], legs: [Limb(91, 91), Limb(89, 89)]),
    dumbbells: [Dumbbell(hand: 0)],
  ),
  Pose(
    figure: Figure(pelvis: P(50, 52), torso: -90,
      arms: [Limb(90, -60)], legs: [Limb(91, 91), Limb(89, 89)]),
    dumbbells: [Dumbbell(hand: 0)],
  ),
]);
```

## Study these already-done examples before you start
- `squat.dart` (front, barbell both hands), `overhead_press.dart` (front press)
- `bench_press.dart` (side, lying, ring on hand), `deadlift.dart` (side hinge)
- `barbell_curl.dart` / `dumbbell_curl.dart` (standing curl: elbow pinned,
  forearm rotates `90 -> -60`)
- `leg_press.dart`, `lat_pulldown.dart`, `leg_curl.dart` (machines, grey props)
- `glute_bridge.dart`, `crunch.dart` (floor / supine)

## YOU MUST VISUALLY AUDIT YOUR WORK (this is the most important step)
For your family, write ONE throwaway test (give it a UNIQUE filename like
`test/_audit_<family>_test.dart`) that paints each of your art functions at
t = 0, .25, .5, .75, 1 in a row, to a golden PNG, then **Read the PNG and judge
whether each reads as the movement**. Iterate the angles until it does. Template:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schlift/widgets/exercise_art/toolkit.dart';
import 'package:schlift/widgets/exercise_art/<file>.dart';
// ...import each of your files

void main() {
  final arts = <String, ExerciseArt Function()>{
    'incline_bench_press': inclineBenchPressArt,
    // ...all of yours
  };
  testWidgets('audit', (tester) async {
    tester.view.physicalSize = Size(840, 170.0 * arts.length);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr,
      child: RepaintBoundary(key: const ValueKey('a'),
        child: Container(color: const Color(0xFF16181D), padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in arts.entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final t in [0.0,0.25,0.5,0.75,1.0])
                  SizedBox(width: 160, height: 160, child: CustomPaint(
                    painter: ExerciseArtPainter(art: e.value(),
                      figureColor: const Color(0xFFEDEFF2),
                      t: Curves.easeInOut.transform(t)))),
              ]),
          ])))));
    await tester.pump();
    await expectLater(find.byKey(const ValueKey('a')),
      matchesGoldenFile('goldens/_audit_<family>.png'));
  });
}
```
Run: `flutter test --update-goldens test/_audit_<family>_test.dart` (run from the
`app/` dir). Then Read `test/goldens/_audit_<family>.png` and fix what looks
wrong. Repeat until each row reads correctly.

## Optional: check against a real photo
Reference stills are public-domain at:
`https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/<Name>/0.jpg`
(and `/1.jpg`). Names use Title_Case_With_Underscores, e.g. `Pushups`,
`Barbell_Shrug`, `Dumbbell_Bicep_Curl`. `curl` it to /tmp and Read it if unsure
of a movement's shape. Not all names exist; don't block on it.

## When done
- Run `flutter analyze lib/widgets/exercise_art` — it must be clean.
- **Delete your throwaway `test/_audit_<family>_test.dart` and its golden.**
- Do NOT edit `registry.dart` or `exercise_art_preview_test.dart` (the parent
  wires those up to avoid conflicts).
- Report back: for each exercise, the proto enum name, the function name, and the
  file name, plus one line on how confident you are it reads correctly.
```
