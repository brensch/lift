import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logic/audio.dart';

class SoundProvider extends ChangeNotifier {
  static String get defaultPreset => defaultSoundPreset;
  String _currentPreset = defaultSoundPreset;
  final SoundPlayer _player = SoundPlayer();

  String get currentPreset => _currentPreset;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // An id from before the sound set changed falls back to the default.
    _currentPreset = knownSoundPreset(prefs.getString('schlift-rest-sound'));
    notifyListeners();
  }

  Future<void> setPreset(String preset) async {
    _currentPreset = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('schlift-rest-sound', preset);
    notifyListeners();
  }

  Future<void> reset() async {
    _currentPreset = defaultPreset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('schlift-rest-sound');
    notifyListeners();
  }

  Future<void> playCurrentSound() async {
    await _player.play(_currentPreset);
  }

  Future<void> playPreview(String preset) async {
    await _player.play(preset);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
