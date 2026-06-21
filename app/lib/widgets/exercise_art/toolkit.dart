import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Exercise-art toolkit.
///
/// Authored on a **100 x 100 box** (x right, y DOWN). The figure is a skeleton
/// with **fixed bone lengths**, posed by **angles** (forward kinematics). You
/// never place a hand or foot directly — you rotate the limb, and the joint
/// falls where the fixed-length bone reaches. Because animation interpolates
/// the *angles*, every bone keeps its exact length through the whole tween
/// (limbs can't stretch or shrink between frames).
///
/// ## Angles
/// Degrees, screen-space: **0 = right, 90 = down, 180 = left, -90 = up.**
/// A limb is two segments — for arms `(upperArm, forearm)`, for legs
/// `(thigh, shin)` — each an absolute direction the segment points.
///
/// ## Views & equipment
///   • [ExerciseView] picks the barbell rendering (front = wide bar + 2 plates,
///     side = one plate ring).
///   • Machines: `ExerciseArt(machine: true)` greys [Pose.props]/[Pose.propDiscs].

// ── Fixed skeleton proportions (box units) ─────────────────────────────────
const double _torsoLen = 26;
const double _headOffset = 9; // neck → head centre, along the torso line
const double _upperArm = 13;
const double _forearm = 12;
const double _thigh = 19;
const double _shin = 19;

const Color _machineGrey = Color(0xFF9098A3);

Offset _dir(double deg) {
  final r = deg * math.pi / 180.0;
  return Offset(math.cos(r), math.sin(r));
}

double _lerpAngle(double a, double b, double t) {
  var d = (b - a) % 360.0;
  if (d > 180) d -= 360;
  if (d < -180) d += 360;
  return a + d * t;
}

// ── Authoring model ────────────────────────────────────────────────────────

enum ExerciseView { front, side }

class ExerciseArt {
  final List<Pose> frames;
  final bool machine;
  final ExerciseView view;

  const ExerciseArt(
    this.frames, {
    this.machine = false,
    this.view = ExerciseView.side,
  });
}

typedef P = Offset; // brevity: P(x, y)

/// A two-segment limb, authored as the absolute direction each segment points.
/// Arms: (upperArm, forearm). Legs: (thigh, shin).
class Limb {
  final double a;
  final double b;
  const Limb(this.a, this.b);
}

/// The stick figure for one key pose: a root (pelvis) + bone angles. Bone
/// lengths are fixed, so only the root position and the angles vary.
class Figure {
  /// Pelvis (root) position in the 0..100 box.
  final Offset pelvis;

  /// Direction pelvis → neck (the torso line). -90 = standing upright.
  final double torso;

  /// 0–2 arms, hung from the neck.
  final List<Limb> arms;

  /// 0–2 legs, hung from the pelvis.
  final List<Limb> legs;

  final double headR;

  const Figure({
    required this.pelvis,
    required this.torso,
    this.arms = const [],
    this.legs = const [],
    this.headR = 6.5,
  });

  Offset get neck => pelvis + _dir(torso) * _torsoLen;
  Offset get head => neck + _dir(torso) * _headOffset;

  /// [shoulder, elbow, hand] for an arm.
  List<Offset> armPoints(Limb l) {
    final shoulder = neck;
    final elbow = shoulder + _dir(l.a) * _upperArm;
    final hand = elbow + _dir(l.b) * _forearm;
    return [shoulder, elbow, hand];
  }

  /// [hip, knee, ankle] for a leg.
  List<Offset> legPoints(Limb l) {
    final hip = pelvis;
    final knee = hip + _dir(l.a) * _thigh;
    final ankle = knee + _dir(l.b) * _shin;
    return [hip, knee, ankle];
  }

  static Figure lerp(Figure a, Figure b, double t) {
    if (a.arms.length != b.arms.length || a.legs.length != b.legs.length) {
      return t < 0.5 ? a : b;
    }
    return Figure(
      pelvis: Offset.lerp(a.pelvis, b.pelvis, t)!,
      torso: _lerpAngle(a.torso, b.torso, t),
      headR: a.headR + (b.headR - a.headR) * t,
      arms: [
        for (var i = 0; i < a.arms.length; i++)
          Limb(
            _lerpAngle(a.arms[i].a, b.arms[i].a, t),
            _lerpAngle(a.arms[i].b, b.arms[i].b, t),
          ),
      ],
      legs: [
        for (var i = 0; i < a.legs.length; i++)
          Limb(
            _lerpAngle(a.legs[i].a, b.legs[i].a, t),
            _lerpAngle(a.legs[i].b, b.legs[i].b, t),
          ),
      ],
    );
  }
}

/// One key pose: a [Figure] plus its equipment.
class Pose {
  final Figure figure;

  /// Equipment polylines (bench, machine frame, cable).
  final List<List<Offset>> props;

  /// Filled equipment discs (machine pulleys/rollers).
  final List<PropDisc> propDiscs;

  /// Barbells, drawn from the one shared model.
  final List<Barbell> barbells;

  /// Dumbbells, each welded to one hand.
  final List<Dumbbell> dumbbells;

  const Pose({
    required this.figure,
    this.props = const [],
    this.propDiscs = const [],
    this.barbells = const [],
    this.dumbbells = const [],
  });
}

class PropDisc {
  final Offset c;
  final double r;
  const PropDisc(this.c, this.r);
}

/// A barbell, drawn from the one shared model. Anchored to the figure so it
/// stays welded to whatever holds it:
///   • `hands: [i]`     — held by arm i's hand (side view → plate ring on it).
///   • `hands: [i, j]`  — spans both hands (front view → bar centred between
///                        them, angled along the line connecting them).
///   • `hips: true`     — rests on the pelvis (e.g. hip thrust).
///   • `center: P(..)`  — a fixed point (rarely needed; overrides anchors).
/// [nudge] offsets the bar from its anchor (box units).
class Barbell {
  final List<int> hands;
  final bool hips;
  final Offset? center;
  final Offset nudge;
  final double length;

  const Barbell({
    this.hands = const [],
    this.hips = false,
    this.center,
    this.nudge = Offset.zero,
    this.length = 40,
  });

  /// Resolve to (centre, angleDegrees) against [fig].
  (Offset, double) resolve(Figure fig) {
    Offset c;
    double angle = 0;
    if (center != null) {
      c = center!;
    } else if (hands.isNotEmpty) {
      final pts = [for (final i in hands) fig.armPoints(fig.arms[i]).last];
      c = pts.reduce((a, b) => a + b) / pts.length.toDouble();
      if (pts.length >= 2) {
        final d = pts[1] - pts[0];
        angle = math.atan2(d.dy, d.dx) * 180 / math.pi;
      }
    } else if (hips) {
      c = fig.pelvis;
    } else {
      c = Offset.zero;
    }
    return (c + nudge, angle);
  }

  static Barbell lerp(Barbell a, Barbell b, double t) => Barbell(
    hands: a.hands,
    hips: a.hips,
    center: (a.center == null || b.center == null)
        ? null
        : Offset.lerp(a.center, b.center, t),
    nudge: Offset.lerp(a.nudge, b.nudge, t)!,
    length: a.length + (b.length - a.length) * t,
  );
}

/// A dumbbell, welded to one hand. Compact: a short handle with a chunky end on
/// each side. [angle] is the handle's tilt (default level).
class Dumbbell {
  final int hand;
  final Offset nudge;
  final double angle;
  const Dumbbell({required this.hand, this.nudge = Offset.zero, this.angle = 0});

  Offset center(Figure fig) => fig.armPoints(fig.arms[hand]).last + nudge;

  static Dumbbell lerp(Dumbbell a, Dumbbell b, double t) => Dumbbell(
    hand: a.hand,
    nudge: Offset.lerp(a.nudge, b.nudge, t)!,
    angle: _lerpAngle(a.angle, b.angle, t),
  );
}

// ── Interpolation ──────────────────────────────────────────────────────────

List<Offset> _lerpLine(List<Offset> a, List<Offset> b, double t) {
  if (a.length != b.length) return t < 0.5 ? a : b;
  return [for (var i = 0; i < a.length; i++) Offset.lerp(a[i], b[i], t)!];
}

Pose _lerpPose(Pose a, Pose b, double t) {
  if (a.props.length != b.props.length ||
      a.propDiscs.length != b.propDiscs.length ||
      a.barbells.length != b.barbells.length ||
      a.dumbbells.length != b.dumbbells.length) {
    return t < 0.5 ? a : b;
  }
  return Pose(
    figure: Figure.lerp(a.figure, b.figure, t),
    props: [
      for (var i = 0; i < a.props.length; i++)
        _lerpLine(a.props[i], b.props[i], t),
    ],
    propDiscs: [
      for (var i = 0; i < a.propDiscs.length; i++)
        PropDisc(
          Offset.lerp(a.propDiscs[i].c, b.propDiscs[i].c, t)!,
          a.propDiscs[i].r + (b.propDiscs[i].r - a.propDiscs[i].r) * t,
        ),
    ],
    barbells: [
      for (var i = 0; i < a.barbells.length; i++)
        Barbell.lerp(a.barbells[i], b.barbells[i], t),
    ],
    dumbbells: [
      for (var i = 0; i < a.dumbbells.length; i++)
        Dumbbell.lerp(a.dumbbells[i], b.dumbbells[i], t),
    ],
  );
}

Pose poseAt(ExerciseArt art, double t) {
  final frames = art.frames;
  if (frames.length == 1) return frames.first;
  final seg = t.clamp(0.0, 1.0) * (frames.length - 1);
  final i = seg.floor().clamp(0, frames.length - 2);
  return _lerpPose(frames[i], frames[i + 1], seg - i);
}

// ── Painter ────────────────────────────────────────────────────────────────

class ExerciseArtPainter extends CustomPainter {
  final ExerciseArt art;
  final Color figureColor;

  /// Drives the animation: the painter repaints the canvas whenever this ticks
  /// (passed to `super(repaint:)`), with no widget rebuild. Its value is the
  /// eased progress 0→1.
  final Animation<double> progress;

  ExerciseArtPainter({
    required this.art,
    required this.figureColor,
    required this.progress,
  }) : super(repaint: progress);

  double get t => progress.value;

  // Reused across every frame and every instance — Flutter paints on a single
  // thread, so sharing these avoids allocating Paints/Paths ~thousands of times
  // a second while the thumbnails loop.
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    Offset sc(Offset o) => Offset(o.dx * s, o.dy * s);

    final equipColor = art.machine ? _machineGrey : figureColor;

    void drawPolyline(List<Offset> pts) {
      if (pts.length < 2) return;
      _path.reset();
      _path.moveTo(pts.first.dx * s, pts.first.dy * s);
      for (var i = 1; i < pts.length; i++) {
        _path.lineTo(pts[i].dx * s, pts[i].dy * s);
      }
      canvas.drawPath(_path, _stroke);
    }

    final pose = poseAt(art, t);
    final fig = pose.figure;

    // Equipment behind the figure.
    _stroke
      ..color = equipColor
      ..strokeWidth = 4.2 * s;
    for (final pl in pose.props) {
      drawPolyline(pl);
    }
    _fill.color = equipColor;
    for (final d in pose.propDiscs) {
      canvas.drawCircle(sc(d.c), d.r * s, _fill);
    }

    // Figure (forward kinematics from fixed bone lengths).
    _stroke
      ..color = figureColor
      ..strokeWidth = 5.0 * s;
    drawPolyline([fig.pelvis, fig.neck]); // spine
    canvas.drawCircle(sc(fig.head), fig.headR * s, _stroke);
    for (final arm in fig.arms) {
      drawPolyline(fig.armPoints(arm));
    }
    for (final leg in fig.legs) {
      drawPolyline(fig.legPoints(leg));
    }

    // Barbells on top — resolved against the interpolated figure, so they stay
    // welded to the hand/hip that holds them.
    for (final bar in pose.barbells) {
      final (center, angle) = bar.resolve(fig);
      canvas.save();
      canvas.translate(center.dx * s, center.dy * s);
      canvas.rotate(angle * math.pi / 180.0);
      _drawBarbell(canvas, bar.length * s, s, figureColor, art.view);
      canvas.restore();
    }

    // Dumbbells, welded to a hand.
    for (final db in pose.dumbbells) {
      final center = db.center(fig);
      canvas.save();
      canvas.translate(center.dx * s, center.dy * s);
      canvas.rotate(db.angle * math.pi / 180.0);
      _drawDumbbell(canvas, s, figureColor);
      canvas.restore();
    }
  }

  /// Compact dumbbell: a short handle with a chunky end each side. Centred on
  /// the gripping hand.
  static void _drawDumbbell(Canvas canvas, double s, Color color) {
    _stroke
      ..color = color
      ..strokeWidth = 2.4 * s;
    _fill.color = color;
    canvas.drawLine(Offset(-4.5 * s, 0), Offset(4.5 * s, 0), _stroke);
    for (final sign in const [-1.0, 1.0]) {
      final rect = Rect.fromCenter(
        center: Offset(sign * 5.0 * s, 0),
        width: 4.2 * s,
        height: 9.5 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(1.8 * s)),
        _fill,
      );
    }
  }

  static void _drawBarbell(
    Canvas canvas,
    double lengthPx,
    double s,
    Color color,
    ExerciseView view,
  ) {
    if (view == ExerciseView.side) {
      _stroke
        ..color = color
        ..strokeWidth = 3.6 * s;
      canvas.drawCircle(Offset.zero, 8.5 * s, _stroke);
      return;
    }

    _stroke
      ..color = color
      ..strokeWidth = 2.4 * s;
    _fill.color = color;
    final half = lengthPx / 2;
    canvas.drawLine(Offset(-half, 0), Offset(half, 0), _stroke);
    const plateW = 4.6;
    const plateH = 17.0;
    final inset = 1.4 * s;
    for (final sign in const [-1.0, 1.0]) {
      final cx = sign * (half - inset);
      final rect = Rect.fromCenter(
        center: Offset(cx, 0),
        width: plateW * s,
        height: plateH * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(2.0 * s)),
        _fill,
      );
    }
  }

  @override
  bool shouldRepaint(ExerciseArtPainter old) =>
      old.progress != progress ||
      old.figureColor != figureColor ||
      old.art != art;
}
