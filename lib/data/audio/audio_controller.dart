import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:juzreviz/data/audio/audio_allowlist.dart';
import 'package:juzreviz/data/audio/reciters.dart';

/// `true` une fois `JustAudioBackground.init()` réussi (mis à jour par `main`).
/// Si `false`, on évite les `MediaItem` (qui exigent l'init) → lecture simple.
bool justAudioBackgroundReady = false;

/// Résout un chemin local pour un verset s'il est en cache (offline-first).
typedef AudioLocalResolver =
    Future<String?> Function(String reciterId, String verseKey);

/// Contrôleur audio (just_audio) : lecture d'un verset depuis le cache local
/// si disponible, sinon une source validée par l'allowlist. Émet la clé courante.
class AudioController {
  AudioController({AudioPlayer? player, this.resolver})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  Future<void> _sourceQueue = Future.value();
  int _commandGeneration = 0;

  /// Résolveur de cache offline (injecté par le provider).
  final AudioLocalResolver? resolver;

  String? _currentVerseKey;
  String? get currentVerseKey => _currentVerseKey;

  Stream<bool> get playingStream => _player.playingStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;

  Future<void> setRate(double rate) => _player.setSpeed(rate.clamp(0.5, 2.0));

  /// Joue un verset : cache local d'abord, sinon streaming (URL allowlistée).
  /// [title] alimente la notification de lecture en arrière-plan.
  /// Renvoie `false` si l'URL n'est pas autorisée ou la source indisponible.
  Future<bool> playVerse(
    String reciterId,
    String verseKey, {
    double rate = 1.0,
    String? title,
  }) async {
    final generation = ++_commandGeneration;
    _currentVerseKey = null;
    try {
      final stopped = await _withSourceLock(() async {
        if (generation != _commandGeneration) return false;
        await _player.stop();
        return generation == _commandGeneration;
      });
      if (!stopped) return false;
      final local = await resolver?.call(reciterId, verseKey);
      if (generation != _commandGeneration) return false;
      final url = verseAudioUrl(reciterId, verseKey);
      if (local == null && !isAllowedAudioUrl(url)) return false;
      final uri = local != null ? Uri.file(local) : Uri.parse(url);

      return await _withSourceLock(() async {
        if (generation != _commandGeneration) return false;
        if (justAudioBackgroundReady) {
          await _player.setAudioSource(
            AudioSource.uri(
              uri,
              tag: MediaItem(
                id: verseKey,
                title: title ?? 'Verset $verseKey',
                album: reciterById(reciterId).name,
              ),
            ),
          );
        } else if (local != null) {
          await _player.setFilePath(local);
        } else {
          await _player.setUrl(url);
        }
        if (generation != _commandGeneration) return false;
        await _player.setSpeed(rate.clamp(0.5, 2.0));
        if (generation != _commandGeneration) return false;
        _currentVerseKey = verseKey;
        _startPlayer(generation);
        return true;
      });
    } catch (_) {
      if (generation == _commandGeneration) _currentVerseKey = null;
      return false; // offline / source indisponible → géré en amont
    }
  }

  /// Joue une URL ponctuelle allowlistée (ex. audio d'un mot). L'interface
  /// désactive cette action pendant une séquence de versets.
  Future<bool> playUrl(String url, {double rate = 1.0}) async {
    if (!isAllowedAudioUrl(url)) return false;
    final generation = ++_commandGeneration;
    _currentVerseKey = null;
    try {
      return await _withSourceLock(() async {
        if (generation != _commandGeneration) return false;
        if (justAudioBackgroundReady) {
          await _player.setAudioSource(
            AudioSource.uri(
              Uri.parse(url),
              tag: const MediaItem(id: 'word', title: 'Mot', album: 'JuzReviz'),
            ),
          );
        } else {
          await _player.setUrl(url);
        }
        if (generation != _commandGeneration) return false;
        _currentVerseKey = null;
        await _player.setSpeed(rate.clamp(0.5, 2.0));
        if (generation != _commandGeneration) return false;
        _startPlayer(generation);
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  Future<void> pause() async {
    _commandGeneration++;
    await _player.pause();
  }

  Future<void> resume() async {
    final generation = ++_commandGeneration;
    _startPlayer(generation);
  }

  Future<void> stop() async {
    _commandGeneration++;
    _currentVerseKey = null;
    await _player.stop();
  }

  Future<void> dispose() async {
    _commandGeneration++;
    _currentVerseKey = null;
    await _player.dispose();
  }

  /// Sérialise uniquement l'installation des sources. Ainsi une ancienne
  /// requête lente ne peut pas écraser la source d'une commande plus récente.
  Future<T> _withSourceLock<T>(Future<T> Function() operation) {
    final previous = _sourceQueue;
    final completer = Completer<T>();
    _sourceQueue = () async {
      try {
        await previous;
      } catch (_) {
        // Une commande audio échouée ne bloque pas les suivantes.
      }
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }();
    return completer.future;
  }

  void _startPlayer(int generation) {
    unawaited(
      _player.play().catchError((Object _) {
        if (generation == _commandGeneration) _currentVerseKey = null;
      }),
    );
  }
}
