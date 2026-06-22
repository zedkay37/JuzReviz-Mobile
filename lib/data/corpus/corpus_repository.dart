import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/model/verse.dart';

/// Accès read-only au corpus (assets JSON normalisés, lazy + cache).
class CorpusRepository {
  CorpusRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  List<SurahMeta>? _metaCache;
  final Map<int, List<Verse>> _surahCache = {};

  Future<List<SurahMeta>> surahMetas() async {
    if (_metaCache != null) return _metaCache!;
    final raw = await _bundle.loadString('assets/corpus/surah_meta.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => SurahMeta.fromMap((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return _metaCache = list;
  }

  Future<SurahMeta> surahMeta(int number) async {
    final metas = await surahMetas();
    return metas.firstWhere((m) => m.number == number);
  }

  Future<List<Verse>> versesBySurah(int surah) async {
    final cached = _surahCache[surah];
    if (cached != null) return cached;
    final raw = await _bundle.loadString('assets/corpus/surah/$surah.json');
    final list = (jsonDecode(raw) as List)
        .map((e) => Verse.fromMap((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return _surahCache[surah] = list;
  }

  Future<Verse?> verseByKey(String verseKey) async {
    final parts = verseKey.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return null;
    final verses = await versesBySurah(surah);
    for (final v in verses) {
      if (v.ayah == ayah) return v;
    }
    return null;
  }

  Future<List<Verse>> versesByJuz(int juz) async {
    final metas = await surahMetas();
    final out = <Verse>[];
    for (final m in metas) {
      if (m.juzStart > juz) break;
      final verses = await versesBySurah(m.number);
      out.addAll(verses.where((v) => v.juz == juz));
    }
    return out;
  }

  /// Résout une [Selection] en liste de versets ordonnée.
  Future<List<Verse>> versesForSelection(Selection selection) async {
    switch (selection) {
      case SelJuz(:final juz):
        return versesByJuz(juz);
      case SelSurah(:final surah, :final from, :final to):
        final verses = await versesBySurah(surah);
        return verses
            .where((v) => v.ayah >= from && v.ayah <= to)
            .toList(growable: false);
      case SelReview(:final verseKeys):
        final out = <Verse>[];
        for (final k in verseKeys) {
          final v = await verseByKey(k);
          if (v != null) out.add(v);
        }
        return out;
    }
  }
}
