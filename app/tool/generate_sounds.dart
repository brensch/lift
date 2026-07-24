// Generates WAV files for all sound presets as Android raw resources.
// Run once from app/: dart run tool/generate_sounds.dart
//
// This duplicates the WAV generation logic from lib/logic/audio.dart
// because that file imports Flutter-dependent packages (just_audio).

// This is a command-line generator, not app code — printing is its output.
// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

enum WaveType { sine, triangle, square, sawtooth }

class SoundNote {
  final double freq;
  final WaveType type;
  final double delay;
  final double duration;
  const SoundNote({
    required this.freq,
    required this.type,
    this.delay = 0.0,
    this.duration = 2.0,
  });
}

class SoundDef {
  final String name;
  final List<SoundNote> notes;
  const SoundDef({required this.name, required this.notes});
}

// Keep in sync with lib/logic/audio.dart soundPresets
const Map<String, SoundDef> soundPresets = {
  'chord_strum': SoundDef(
    name: 'Esoteric Strum',
    notes: [
      SoundNote(freq: 233.08, type: WaveType.triangle, delay: 0.00),
      SoundNote(freq: 329.63, type: WaveType.sine, delay: 0.04),
      SoundNote(freq: 440.00, type: WaveType.sine, delay: 0.08),
      SoundNote(freq: 587.33, type: WaveType.triangle, delay: 0.12),
      SoundNote(freq: 739.99, type: WaveType.sine, delay: 0.16),
      SoundNote(freq: 987.77, type: WaveType.sine, delay: 0.20),
    ],
  ),
  'bell_high': SoundDef(
    name: 'High Bell',
    notes: [
      SoundNote(freq: 1320, type: WaveType.sine, duration: 0.8),
      SoundNote(freq: 2640, type: WaveType.sine, duration: 0.8),
    ],
  ),
  'classic_beep': SoundDef(
    name: 'Classic Beep',
    notes: [
      SoundNote(freq: 880, type: WaveType.square, duration: 0.1, delay: 0.0),
      SoundNote(freq: 880, type: WaveType.square, duration: 0.1, delay: 0.2),
      SoundNote(freq: 880, type: WaveType.square, duration: 0.1, delay: 0.4),
    ],
  ),
  'success_rise': SoundDef(
    name: 'Success Rise',
    notes: [
      SoundNote(freq: 523.25, type: WaveType.sine, duration: 0.5, delay: 0.0),
      SoundNote(freq: 659.25, type: WaveType.sine, duration: 0.5, delay: 0.1),
      SoundNote(freq: 783.99, type: WaveType.sine, duration: 0.5, delay: 0.2),
      SoundNote(freq: 1046.50, type: WaveType.sine, duration: 1.0, delay: 0.3),
    ],
  ),
  'boxing_bell': SoundDef(
    name: 'Boxing Bell',
    notes: [
      SoundNote(freq: 440, type: WaveType.sine, duration: 1.0, delay: 0.0),
      SoundNote(freq: 440, type: WaveType.sine, duration: 1.0, delay: 0.2),
      SoundNote(freq: 440, type: WaveType.sine, duration: 1.0, delay: 0.4),
    ],
  ),
  'elevator_ding': SoundDef(
    name: 'Elevator Ding',
    notes: [
      SoundNote(freq: 783.99, type: WaveType.sine, duration: 1.5, delay: 0.0),
    ],
  ),
  'dojo_gong': SoundDef(
    name: 'Dojo Gong',
    notes: [
      SoundNote(
        freq: 98.00,
        type: WaveType.triangle,
        duration: 3.0,
        delay: 0.0,
      ),
      SoundNote(
        freq: 146.83,
        type: WaveType.triangle,
        duration: 2.5,
        delay: 0.05,
      ),
      SoundNote(freq: 196.00, type: WaveType.sine, duration: 2.0, delay: 0.1),
    ],
  ),
  'retro_arcade': SoundDef(
    name: 'Retro Arcade',
    notes: [
      SoundNote(freq: 440, type: WaveType.square, duration: 0.05, delay: 0.0),
      SoundNote(freq: 523, type: WaveType.square, duration: 0.05, delay: 0.05),
      SoundNote(freq: 659, type: WaveType.square, duration: 0.05, delay: 0.1),
      SoundNote(freq: 880, type: WaveType.square, duration: 0.05, delay: 0.15),
      SoundNote(freq: 1046, type: WaveType.square, duration: 0.2, delay: 0.2),
    ],
  ),
  'crystal_shine': SoundDef(
    name: 'Crystal Shine',
    notes: [
      SoundNote(freq: 2093, type: WaveType.sine, duration: 0.8, delay: 0.0),
      SoundNote(freq: 2637, type: WaveType.sine, duration: 0.8, delay: 0.05),
      SoundNote(freq: 3135, type: WaveType.sine, duration: 0.8, delay: 0.1),
    ],
  ),
  'morning_dew': SoundDef(
    name: 'Morning Dew',
    notes: [
      SoundNote(freq: 1760, type: WaveType.sine, duration: 0.4, delay: 0.0),
      SoundNote(freq: 1975, type: WaveType.sine, duration: 0.4, delay: 0.1),
      SoundNote(freq: 2093, type: WaveType.sine, duration: 0.4, delay: 0.2),
    ],
  ),
};

Uint8List generateWav(String presetId) {
  final def = soundPresets[presetId]!;
  const sampleRate = 44100;

  double maxEnd = 0;
  for (final note in def.notes) {
    final end = note.delay + note.duration;
    if (end > maxEnd) maxEnd = end;
  }
  maxEnd += 0.1;

  final numSamples = (maxEnd * sampleRate).toInt();
  final samples = Float64List(numSamples);

  for (final note in def.notes) {
    final startSample = (note.delay * sampleRate).toInt();
    final durationSamples = (note.duration * sampleRate).toInt();
    final endSample = (startSample + durationSamples).clamp(0, numSamples);

    for (int i = startSample; i < endSample; i++) {
      final t = (i - startSample) / sampleRate;
      final phase = 2 * pi * note.freq * t;

      double value;
      switch (note.type) {
        case WaveType.sine:
          value = sin(phase);
        case WaveType.triangle:
          value =
              2 * (2 * (note.freq * t - (note.freq * t + 0.5).floor())).abs() -
              1;
        case WaveType.square:
          value = sin(phase) >= 0 ? 1.0 : -1.0;
        case WaveType.sawtooth:
          value = 2 * (note.freq * t - (note.freq * t + 0.5).floor());
      }

      final attackTime = 0.05;
      double envelope;
      if (t < attackTime) {
        envelope = t / attackTime;
      } else {
        envelope = exp(-(t - attackTime) * 3 / note.duration);
      }

      samples[i] += value * envelope * 0.2;
    }
  }

  final dataSize = numSamples * 2;
  final fileSize = 44 + dataSize;
  final bytes = ByteData(fileSize);

  void writeString(int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      bytes.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  writeString(0, 'RIFF');
  bytes.setUint32(4, fileSize - 8, Endian.little);
  writeString(8, 'WAVE');
  writeString(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  writeString(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    final clamped = samples[i].clamp(-1.0, 1.0);
    final sample = (clamped * 32767).toInt().clamp(-32768, 32767);
    bytes.setInt16(44 + i * 2, sample, Endian.little);
  }

  return bytes.buffer.asUint8List();
}

void main() {
  final outDir = Directory('android/app/src/main/res/raw');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  for (final id in soundPresets.keys) {
    final wav = generateWav(id);
    final file = File('${outDir.path}/sound_$id.wav');
    file.writeAsBytesSync(wav);
    print('Wrote ${file.path} (${wav.length} bytes)');
  }

  print('Done - ${soundPresets.length} files generated.');
}
