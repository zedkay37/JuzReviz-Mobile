import 'package:just_audio/just_audio.dart';
import 'package:juzreviz/data/audio/audio_allowlist.dart';
import 'package:juzreviz/data/audio/reciters.dart';

/// Contrôleur audio (just_audio) : lecture d'un verset depuis une source
/// validée par l'allowlist. Émet la clé du verset courant.
class AudioController {
  AudioController({AudioPlayer? player}) : _player = player ?? AudioPlayer();
  final AudioPlayer _player;

  String? _currentVerseKey;
  String? get currentVerseKey => _currentVerseKey;

  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  Future<void> setRate(double rate) =>
      _player.setSpeed(rate.clamp(0.5, 2.0));

  /// Joue un verset. Renvoie `false` si l'URL n'est pas autorisée.
  Future<bool> playVerse(String reciterId, String verseKey,
      {double rate = 1.0}) async {
    final url = verseAudioUrl(reciterId, verseKey);
    if (!isAllowedAudioUrl(url)) return false;
    _currentVerseKey = verseKey;
    try {
      await _player.setUrl(url);
      await _player.setSpeed(rate.clamp(0.5, 2.0));
      await _player.play();
      return true;
    } catch (_) {
      return false; // offline / source indisponible → géré en amont
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}
