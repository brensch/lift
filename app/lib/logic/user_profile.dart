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
