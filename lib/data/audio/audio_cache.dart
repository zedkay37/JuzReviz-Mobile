import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:juzreviz/data/audio/audio_allowlist.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:path_provider/path_provider.dart';

/// Heuristique « est-ce bien un MP3 » : en-tête ID3 ou frame sync MPEG.
/// Évite d'enregistrer une page d'erreur HTML renvoyée en 200.
bool isLikelyMp3(List<int> b) {
  if (b.length < 3) return false;
  if (b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) return true; // "ID3"
  if (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) return true; // frame sync MPEG
  return false;
}

/// Construit les clés de versets d'une sourate (`s:1`..`s:n`).
List<String> surahVerseKeys(int surah, int ayahCount) =>
    [for (var a = 1; a <= ayahCount; a++) '$surah:$a'];

/// Cache audio offline : téléchargement par sourate/récitateur, écriture
/// atomique (`.part` → rename), validation des octets, lecture hors-ligne.
class AudioCacheRepository {
  AudioCacheRepository({http.Client? client, Directory? root})
      : _client = client ?? http.Client(),
        _root = root;

  final http.Client _client;
  Directory? _root;

  Future<Directory> _baseDir() async {
    if (_root != null) return _root!;
    final base = await getApplicationSupportDirectory();
    return _root = Directory('${base.path}/juzreviz/audio');
  }

  Future<String> _versePath(String reciterId, String verseKey) async {
    final dir = await _baseDir();
    final surah = verseKey.split(':')[0];
    final name = verseKey.replaceAll(':', '_');
    return '${dir.path}/$reciterId/$surah/$name.mp3';
  }

  /// Fichier local si présent et non vide, sinon `null` (→ streaming).
  Future<File?> cachedFile(String reciterId, String verseKey) async {
    final f = File(await _versePath(reciterId, verseKey));
    return f.existsSync() && f.lengthSync() > 0 ? f : null;
  }

  /// Vrai si tous les versets de la liste sont en cache (sourate, juz, Coran…).
  Future<bool> areVersesDownloaded(
      String reciterId, List<String> verseKeys) async {
    if (verseKeys.isEmpty) return false;
    for (final k in verseKeys) {
      final f = File(await _versePath(reciterId, k));
      if (!f.existsSync() || f.lengthSync() == 0) return false;
    }
    return true;
  }

  /// Supprime un ensemble de versets (utile pour un juz à cheval sur sourates).
  Future<void> deleteVerses(String reciterId, List<String> verseKeys) async {
    for (final k in verseKeys) {
      final f = File(await _versePath(reciterId, k));
      if (f.existsSync()) f.deleteSync();
    }
  }

  Future<int> surahBytes(String reciterId, int surah) async {
    final dir = Directory('${(await _baseDir()).path}/$reciterId/$surah');
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final e in dir.listSync()) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }

  Future<int> totalBytes() async {
    final dir = await _baseDir();
    if (!dir.existsSync()) return 0;
    var total = 0;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }

  /// Télécharge les versets manquants. `onProgress(done, total)` après chaque
  /// verset ; `cancelled()` permet d'interrompre proprement. Reprend où elle
  /// s'était arrêtée (saute les fichiers déjà présents).
  Future<bool> downloadSurah(
    String reciterId,
    List<String> verseKeys, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final total = verseKeys.length;
    var done = 0;
    for (final key in verseKeys) {
      if (cancelled?.call() ?? false) return false;
      final path = await _versePath(reciterId, key);
      final f = File(path);
      if (f.existsSync() && f.lengthSync() > 0) {
        done++;
        onProgress?.call(done, total);
        continue;
      }
      final url = verseAudioUrl(reciterId, key);
      if (!isAllowedAudioUrl(url)) return false;
      try {
        final resp = await _client.get(Uri.parse(url));
        if (resp.statusCode != 200 || !isLikelyMp3(resp.bodyBytes)) return false;
        f.parent.createSync(recursive: true);
        final tmp = File('$path.part');
        await tmp.writeAsBytes(resp.bodyBytes, flush: true);
        await tmp.rename(path); // écriture atomique
      } catch (_) {
        return false; // offline / source indisponible
      }
      done++;
      onProgress?.call(done, total);
    }
    return true;
  }

  Future<void> deleteSurah(String reciterId, int surah) async {
    final dir = Directory('${(await _baseDir()).path}/$reciterId/$surah');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  Future<void> clearAll() async {
    final dir = await _baseDir();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
