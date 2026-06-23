import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:juzreviz/data/mushaf/mushaf_page.dart';

/// Accès aux données de pages du moushaf (assets QPC), chargées paresseusement.
///
/// Les assets (`assets/mushaf/pages.json` + polices `qcf_p{n}.ttf`) sont
/// produits par `tools/build_mushaf`. En leur absence, [isAvailable] renvoie
/// `false` et l'app retombe sur les dispositions Flexible / Verset par verset.
class MushafRepository {
  MushafRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  Map<String, dynamic>? _root;
  final Map<int, List<MushafLine>> _cache = {};

  Future<void> _ensureLoaded() async {
    if (_root != null) return;
    final raw = await _bundle.loadString('assets/mushaf/pages.json');
    _root = (jsonDecode(raw) as Map).cast<String, dynamic>();
  }

  /// Nombre de pages (604 pour le moushaf Madani standard).
  Future<int> pageCount() async {
    await _ensureLoaded();
    final pages = (_root!['pages'] as Map?) ?? const {};
    return pages.length;
  }

  /// Lignes d'une page (1-indexée), depuis le cache.
  Future<List<MushafLine>> linesForPage(int page) async {
    if (_cache.containsKey(page)) return _cache[page]!;
    await _ensureLoaded();
    final pages = (_root!['pages'] as Map).cast<String, dynamic>();
    final raw = (pages['$page'] as List?) ?? const [];
    return _cache[page] = parseMushafPage(raw);
  }

  /// Page de départ pour une clé de verset (`"2:255"`), si l'index existe.
  Future<int?> pageForVerse(String verseKey) async {
    await _ensureLoaded();
    final index = (_root!['verseToPage'] as Map?)?.cast<String, dynamic>();
    final v = index?[verseKey];
    return (v as num?)?.toInt();
  }
}
