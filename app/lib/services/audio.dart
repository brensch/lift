import 'dart:io' show Directory, File, Platform;
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../gen/copy.dart';
import '../gen/sounds.dart';

/// A rest-over sound's bundled WAV, as a Flutter asset path. The presets
/// are copy.sounds, in picker order, from app/copy.yaml; the files live in
/// assets/sounds and are mirrored to Android and iOS by `make sounds`.
String soundAsset(String id) => 'assets/sounds/sound_$id.wav';

/// The first listed preset; also what an unknown stored id falls back to.
final String defaultSoundPreset = copy.sounds.first.id;

/// [id] if it is a preset, otherwise the default.
String knownSoundPreset(String? id) =>
    id != null && copy.sounds.any((s) => s.id == id) ? id : defaultSoundPreset;

class SoundPlayer {
  final _players = <String, AudioPlayer>{};
  bool _sessionConfigured = false;

  /// Configure the shared audio session so our short notification "ding"
  /// mixes with any background music instead of interrupting/stopping it.
  Future<void> _ensureSession() async {
    if (_sessionConfigured) return;
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        // Ambient + mixWithOthers: play alongside other audio, respect the
        // mute switch, and never take exclusive playback focus on iOS.
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        // Play on the MEDIA stream (audible alongside music) rather than the
        // sonification/system stream, which is often silenced. We avoid pausing
        // other apps by simply not requesting audio focus on Android (see the
        // player's handleAudioSessionActivation below).
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
    _sessionConfigured = true;
  }

  /// The clip as a file the player can open. just_audio's own asset cache
  /// is keyed by asset path alone and never refreshed, so a re-cut sound
  /// kept playing its old bytes after an update; this copy is keyed by the
  /// bundled sounds' revision instead, and the stale cache is dropped once.
  static bool _staleCacheCleared = false;
  Future<String> _fileFor(String id) async {
    if (!_staleCacheCleared) {
      _staleCacheCleared = true;
      await AudioPlayer.clearAssetCache();
    }
    final dir = Directory(
      '${(await getTemporaryDirectory()).path}/schlift_sounds_$soundsRevision',
    );
    final file = File('${dir.path}/sound_$id.wav');
    if (!file.existsSync()) {
      await dir.create(recursive: true);
      final data = await rootBundle.load(soundAsset(id));
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return file.path;
  }

  Future<void> play(String presetId) async {
    try {
      await _ensureSession();
      var player = _players[presetId];
      if (player == null) {
        // iOS needs the audio session active or nothing is output, and the
        // ambient + mixWithOthers config means activating it still mixes with
        // music. Android plays without activation and we deliberately skip it
        // so we never request audio focus / pause the user's music.
        player = AudioPlayer(handleAudioSessionActivation: Platform.isIOS);
        final id = knownSoundPreset(presetId);
        await player.setFilePath(await _fileFor(id));
        _players[presetId] = player;
      }
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // Silently fail - audio is not critical
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}
