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
List<String> surahVerseKeys(int surah, int ayahCount) => [
  for (var a = 1; a <= ayahCount; a++) '$surah:$a',
];

/// Cache audio offline : téléchargement par sourate/récitateur, écriture
/// atomique (`.part` → rename), validation des octets, lecture hors-ligne.
class AudioCacheRepository {
  AudioCacheRepository({
    http.Client? client,
    Directory? root,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _root = root;

  final http.Client _client;
  final Duration requestTimeout;
  Directory? _root;

  Future<Directory> _baseDir() async {
    if (_root != null) return _root!;
    final base = await getApplicationCacheDirectory();
    final target = Directory('${base.path}/juzreviz/audio');
    await _migrateLegacyCache(target);
    return _root = target;
  }

  Future<void> _migrateLegacyCache(Directory target) async {
    if (await target.exists()) return;
    final support = await getApplicationSupportDirectory();
    final legacy = Directory('${support.path}/juzreviz/audio');
    if (!await legacy.exists()) return;
    try {
      await target.parent.create(recursive: true);
      await legacy.rename(target.path);
    } catch (_) {
      // Une migration impossible ne doit pas bloquer l'app. Le nouveau cache
      // repart vide et les fichiers pourront être retéléchargés.
    }
  }

  Future<String> _versePath(String reciterId, String verseKey) async {
    final dir = await _baseDir();
    final parts = verseKey.split(':');
    if (parts.length != 2) {
      throw const FormatException('Clé de verset invalide');
    }
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null ||
        ayah == null ||
        surah < 1 ||
        surah > 114 ||
        ayah < 1 ||
        ayah > 286) {
      throw const FormatException('Clé de verset invalide');
    }
    final safeReciter = reciterById(reciterId).id;
    return '${dir.path}/$safeReciter/$surah/${surah}_$ayah.mp3';
  }

  /// Fichier local si présent et non vide, sinon `null` (→ streaming).
  Future<File?> cachedFile(String reciterId, String verseKey) async {
    try {
      final f = File(await _versePath(reciterId, verseKey));
      return await _isValidCachedFile(f) ? f : null;
    } on FormatException {
      return null;
    }
  }

  /// Vrai si tous les versets de la liste sont en cache (sourate, juz, Coran…).
  Future<bool> areVersesDownloaded(
    String reciterId,
    List<String> verseKeys,
  ) async {
    if (verseKeys.isEmpty) return false;
    for (final k in verseKeys) {
      try {
        final f = File(await _versePath(reciterId, k));
        if (!await _isValidCachedFile(f)) return false;
      } on FormatException {
        return false;
      }
    }
    return true;
  }

  /// Supprime un ensemble de versets (utile pour un juz à cheval sur sourates).
  Future<void> deleteVerses(String reciterId, List<String> verseKeys) async {
    for (final k in verseKeys) {
      try {
        final f = File(await _versePath(reciterId, k));
        if (await f.exists()) await f.delete();
      } on FormatException {
        // Une sauvegarde importée invalide ne doit jamais sortir du cache.
      }
    }
  }

  Future<int> surahBytes(String reciterId, int surah) async {
    if (surah < 1 || surah > 114) return 0;
    final safeReciter = reciterById(reciterId).id;
    final dir = Directory('${(await _baseDir()).path}/$safeReciter/$surah');
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  Future<int> totalBytes() async {
    final dir = await _baseDir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list(recursive: true)) {
      if (e is File) total += await e.length();
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
      if (await _isValidCachedFile(f)) {
        done++;
        onProgress?.call(done, total);
        continue;
      }
      final url = verseAudioUrl(reciterId, key);
      if (!isAllowedAudioUrl(url)) return false;
      try {
        final resp = await _client.get(Uri.parse(url)).timeout(requestTimeout);
        if (resp.statusCode != 200 || !isLikelyMp3(resp.bodyBytes)) {
          return false;
        }
        await f.parent.create(recursive: true);
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
    if (surah < 1 || surah > 114) return;
    final safeReciter = reciterById(reciterId).id;
    final dir = Directory('${(await _baseDir()).path}/$safeReciter/$surah');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<void> clearAll() async {
    final dir = await _baseDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<bool> _isValidCachedFile(File file) async {
    if (!await file.exists() || await file.length() < 3) return false;
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      return isLikelyMp3(await handle.read(3));
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }
}
