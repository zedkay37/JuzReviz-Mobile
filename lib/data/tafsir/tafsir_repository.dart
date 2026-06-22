import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Accès au tafsir (assets gzip par sourate/langue, lazy + cache, décompressé
/// à la lecture). ~9 Mo embarqués pour 78 Mo de texte → offline complet.
class TafsirRepository {
  TafsirRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  final Map<String, Map<String, String>> _cache = {};

  String _norm(String lang) => lang == 'en' ? 'en' : 'fr';

  /// Tafsir d'une sourate entière : `verseKey -> texte`.
  Future<Map<String, String>> surahTafsir(String lang, int surah) async {
    final l = _norm(lang);
    final cacheKey = '$l:$surah';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;
    try {
      final data = await _bundle.load('assets/tafsir/$l/$surah.json.gz');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final json = utf8.decode(gzip.decode(bytes));
      final map = (jsonDecode(json) as Map).map(
        (k, v) => MapEntry(k as String, v?.toString() ?? ''),
      );
      return _cache[cacheKey] = map;
    } catch (_) {
      return _cache[cacheKey] = const {};
    }
  }

  /// Tafsir d'un verset (chaîne vide si absent).
  Future<String> verseTafsir(String lang, String verseKey) async {
    final surah = int.tryParse(verseKey.split(':').first);
    if (surah == null) return '';
    final map = await surahTafsir(lang, surah);
    return map[verseKey] ?? '';
  }
}
