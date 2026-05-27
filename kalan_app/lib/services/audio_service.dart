import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  final AudioPlayer _player = AudioPlayer();

  factory AudioService() => _instance;
  AudioService._internal();

  /// Joue un son si le paramètre "sound_enabled" est vrai.
  /// Les sons doivent être placés dans `assets/audio/`.
  Future<void> play(String soundName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isEnabled = prefs.getBool('sound_enabled') ?? true;

      if (!isEnabled) return;

      await _player.stop();

      final resolvedSoundName = switch (soundName) {
        'flip' => 'swipe',
        'quiz_victory' => 'victory',
        'quiz_complete' => 'complete',
        _ => soundName,
      };

      // Essayer de jouer le fichier avec l'extension appropriée
      // On vérifie les extensions courantes
      final extensions = ['mp3', 'wav'];

      for (final ext in extensions) {
        try {
          await _player.play(AssetSource('audio/$resolvedSoundName.$ext'));
          return; // Si ça marche, on arrête
        } catch (_) {
          // Sinon on essaie l'extension suivante
          continue;
        }
      }
    } catch (e) {
      // Audio error silenced
    }
  }
}
