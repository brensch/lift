import 'package:flutter/widgets.dart';

/// Every icon the app draws, by what it means: Phosphor (phosphoricons.com,
/// MIT), regular weight. The phosphor_flutter package is a dependency only
/// for its bundled icon fonts; its Dart classes don't compile on current
/// Flutter, so the icons are plain IconData into those fonts. To change the
/// weight, change [_family] (PhosphorLight, PhosphorBold, PhosphorThin, …;
/// the code points are the same in every weight). Widgets use
/// `AppIcons.x`, never `Icons.x`.
abstract final class AppIcons {
  static const _family = 'PhosphorRegular';
  static const _package = 'phosphor_flutter';

  /// Phosphor `plus`.
  static const add = IconData(
    0xe3d4,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `plusCircle`.
  static const addCircle = IconData(
    0xe3d6,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `article`.
  static const article = IconData(
    0xe0a8,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `arrowLeft`.
  static const back = IconData(
    0xe058,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `personSimple`.
  static const bodyWeight = IconData(
    0xe72e,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `personSimpleTaiChi`.
  static const calm = IconData(
    0xed5c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `camera`.
  static const camera = IconData(
    0xe10e,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `check`.
  static const check = IconData(
    0xe182,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `checkCircle`.
  static const checkCircle = IconData(
    0xe184,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `circle`.
  static const circle = IconData(
    0xe18a,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `x`.
  static const close = IconData(
    0xe4f6,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `copy`.
  static const copy = IconData(
    0xe1ca,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `bug`.
  static const debug = IconData(
    0xe5f4,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `trash`.
  static const delete = IconData(
    0xe4a6,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `dotsSixVertical`.
  static const drag = IconData(
    0xeae2,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `pencilSimple`.
  static const edit = IconData(
    0xe3b4,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `caretDown`.
  static const expandDown = IconData(
    0xe136,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `caretUp`.
  static const expandUp = IconData(
    0xe13c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `export`.
  static const export = IconData(
    0xeaf0,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `fingerprint`.
  static const fingerprint = IconData(
    0xe23e,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `caretRight`.
  static const forward = IconData(
    0xe13a,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `heart`.
  static const heart = IconData(
    0xe2a8,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `question`.
  static const help = IconData(
    0xe3e8,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `clockCounterClockwise`.
  static const history = IconData(
    0xe1a0,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `info`.
  static const info = IconData(
    0xe2ce,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `key`.
  static const key = IconData(
    0xe2d6,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `lightning`.
  static const lightning = IconData(
    0xe2de,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `chatCircleDots`: the yapping state.
  static const yapping = IconData(
    0xe16c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `rows`.
  static const lines = IconData(
    0xe5a2,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `signOut`.
  static const logout = IconData(
    0xe42a,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `mathOperations`.
  static const maths = IconData(
    0xe31e,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `list`.
  static const menu = IconData(
    0xe2f0,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `dotsThreeVertical`.
  static const more = IconData(
    0xe208,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `usersThree`.
  static const multiplayer = IconData(
    0xe68e,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `bell`.
  static const notifications = IconData(
    0xe0ce,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `arrowSquareOut`.
  static const openExternal = IconData(
    0xe5de,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `palette`.
  static const palette = IconData(
    0xe6c8,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `user`.
  static const person = IconData(
    0xe4c2,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `smiley`.
  static const profileMarker = IconData(
    0xe436,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `chartBar`.
  static const progress = IconData(
    0xe150,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `arrowsClockwise`.
  static const refresh = IconData(
    0xe094,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `minus`.
  static const remove = IconData(
    0xe32a,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `minusCircle`.
  static const removeCircle = IconData(
    0xe32c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `arrowsDownUp`.
  static const reorder = IconData(
    0xe098,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `brain`.
  static const science = IconData(
    0xe74e,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `magnifyingGlass`.
  static const search = IconData(
    0xe30c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `gear`.
  static const settings = IconData(
    0xe270,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `shareNetwork`.
  static const share = IconData(
    0xe408,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `star`.
  static const star = IconData(
    0xe46a,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `timer`.
  static const timer = IconData(
    0xe492,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `textT`.
  static const title = IconData(
    0xe48a,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `arrowLineDown`.
  static const toBottom = IconData(
    0xe05c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `arrowLineUp`.
  static const toTop = IconData(
    0xe066,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `graduationCap`.
  static const tutorial = IconData(
    0xe62c,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `fire`.
  static const warmup = IconData(
    0xe242,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `watch`.
  static const watch = IconData(
    0xe4e6,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `scales`.
  static const weightUnit = IconData(
    0xe750,
    fontFamily: _family,
    fontPackage: _package,
  );

  /// Phosphor `barbell`.
  static const workout = IconData(
    0xe0b6,
    fontFamily: _family,
    fontPackage: _package,
  );
}
