import 'dart:math';

import 'package:flutter/material.dart';

const defaultProfileEmoji = '🦦';
const defaultProfileColorHex = '#6B7280';

const profileColorHexOptions = <String>[
  '#E85D75',
  '#EF6C5B',
  '#F08A4B',
  '#D39A36',
  '#B7A234',
  '#8FA93A',
  '#59B36B',
  '#2FB08C',
  '#24AAA1',
  '#2E9FC0',
  '#4A90E2',
  '#667EEA',
  '#7A6FF0',
  '#9B5DE5',
  '#C855BC',
  '#8B6B4A',
  '#6B7280',
  '#4B5563',
];

/// The slider's colours are one lightness and one colourfulness in OKLCH,
/// a colour space built to match what the eye sees, so only the hue moves:
/// every colour on it looks as bright and as vivid as the next, and an emoji
/// reads the same on all of them. Where the screen cannot show a hue that
/// vivid (the yellows, the cyans), it is as vivid as it can be.
///
/// Both are the app's signal orange's own, so the slider passes through it.
const double _profileLightness = 0.67;
const double _profileChroma = 0.222;

/// Linear sRGB for an OKLCH colour; outside 0..1 when the screen can't show it.
(double, double, double) _oklchToLinear(double l, double c, double hue) {
  final h = hue * pi / 180;
  final a = c * cos(h);
  final b = c * sin(h);
  final l3 = pow(l + 0.3963377774 * a + 0.2158037573 * b, 3).toDouble();
  final m3 = pow(l - 0.1055613458 * a - 0.0638541728 * b, 3).toDouble();
  final s3 = pow(l - 0.0894841775 * a - 1.2914855480 * b, 3).toDouble();
  return (
    4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
    -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
    -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
  );
}

double _srgbFromLinear(double x) =>
    x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055;

double _linearFromSrgb(double x) =>
    x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4).toDouble();

/// The slider's colour at [hue] (degrees, 0 to 360).
Color profileHueColor(double hue) {
  bool shows((double, double, double) rgb) =>
      rgb.$1 >= 0 &&
      rgb.$1 <= 1 &&
      rgb.$2 >= 0 &&
      rgb.$2 <= 1 &&
      rgb.$3 >= 0 &&
      rgb.$3 <= 1;

  var rgb = _oklchToLinear(_profileLightness, _profileChroma, hue);
  if (!shows(rgb)) {
    // The most colourful this hue gets on a screen at this lightness.
    var low = 0.0;
    var high = _profileChroma;
    for (var i = 0; i < 16; i++) {
      final mid = (low + high) / 2;
      if (shows(_oklchToLinear(_profileLightness, mid, hue))) {
        low = mid;
      } else {
        high = mid;
      }
    }
    rgb = _oklchToLinear(_profileLightness, low, hue);
  }
  int channel(double x) => (_srgbFromLinear(x).clamp(0.0, 1.0) * 255).round();
  return Color.fromARGB(255, channel(rgb.$1), channel(rgb.$2), channel(rgb.$3));
}

/// Where on the slider [color] sits: its hue in OKLCH, 0 to 360.
double profileHueOf(Color color) {
  final r = _linearFromSrgb(color.r);
  final g = _linearFromSrgb(color.g);
  final b = _linearFromSrgb(color.b);
  double cbrt(double x) => pow(x, 1 / 3).toDouble();
  final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  final a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
  final bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
  return (atan2(bb, a) * 180 / pi + 360) % 360;
}

String normalizedProfileEmoji(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? defaultProfileEmoji : trimmed;
}

String normalizedProfileColorHex(String value) {
  final trimmed = value.trim();
  final hex = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  final isValid = hex.length == 6 && RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex);
  return isValid ? '#${hex.toUpperCase()}' : defaultProfileColorHex;
}

Color profileColorFromHex(String? hex) =>
    colorFromHex(normalizedProfileColorHex(hex ?? defaultProfileColorHex))!;

/// The opaque colour "#RRGGBB" (or "RRGGBB") names; null when it names none.
Color? colorFromHex(String hex) {
  final digits = hex.startsWith('#') ? hex.substring(1) : hex;
  if (digits.length != 6) return null;
  final value = int.tryParse(digits, radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}

/// "#RRGGBB" for [color], its alpha dropped.
String colorHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
