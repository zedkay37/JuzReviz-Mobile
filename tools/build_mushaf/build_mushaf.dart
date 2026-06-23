// Pipeline d'ingestion du pack moushaf (QPC v1) → assets de l'app.
//
// ENTRÉE (à placer par l'utilisateur) :
//   tools/build_mushaf/source/words.json   — liste de mots de mise en page
//   tools/build_mushaf/source/fonts/*.ttf  — polices QCF par page (qcf_p1.ttf …)
//
// Format attendu de words.json (un objet par mot, dans l'ordre de lecture) :
//   { "page": 1, "line": 3, "key": "1:1", "code": "ﭑ", "type": "word" }
//   type ∈ { "word", "surah", "basmalah", "end" }
//     - "surah"    : en-tête de sourate (key = "<n>:0" ou champ "surah")
//     - "basmalah" : ligne basmala
//     - "end"      : marqueur de fin d'ayah (rendu comme un mot-glyphe)
//
// SORTIE :
//   assets/mushaf/pages.json   — { pages: { "<p>": [lignes] }, verseToPage: {...} }
//
// Puis : copier source/fonts/*.ttf dans assets/mushaf/fonts/ et déclarer les
// familles `qcf_p1`..`qcf_p604` + l'asset pages.json dans pubspec.yaml
// (le script imprime le bloc à coller).

import 'dart:convert';
import 'dart:io';

void main() {
  final root = Directory.current.path;
  final srcFile = File('$root/tools/build_mushaf/source/words.json');
  if (!srcFile.existsSync()) {
    stderr.writeln('Source absente : ${srcFile.path}');
    stderr.writeln('Place le pack QPC v1 puis relance.');
    exitCode = 1;
    return;
  }

  final words = (jsonDecode(srcFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  // page -> line -> liste de mots ; on conserve type/surah par ligne.
  final pages = <int, Map<int, Map<String, dynamic>>>{};
  final verseToPage = <String, int>{};

  for (final w in words) {
    final page = (w['page'] as num).toInt();
    final line = (w['line'] as num).toInt();
    final type = (w['type'] ?? 'word') as String;
    final key = (w['key'] ?? '') as String;

    final byLine = pages.putIfAbsent(page, () => {});
    final l = byLine.putIfAbsent(line, () => {'line': line, 'words': <Map>[]});

    if (type == 'surah') {
      l['type'] = 'surah';
      l['surah'] = (w['surah'] as num?)?.toInt() ??
          int.tryParse(key.split(':').first) ??
          0;
    } else if (type == 'basmalah') {
      l['type'] = 'basmalah';
    } else {
      l['type'] = (l['type'] ?? 'ayah');
      (l['words'] as List).add({'c': w['code'] ?? '', 'k': key});
      if (key.isNotEmpty && !verseToPage.containsKey(key)) {
        verseToPage[key] = page;
      }
    }
  }

  final out = <String, dynamic>{
    'version': 'qpc-v1',
    'pages': {
      for (final p in (pages.keys.toList()..sort()))
        '$p': [
          for (final l in (pages[p]!.keys.toList()..sort())) pages[p]![l],
        ],
    },
    'verseToPage': verseToPage,
  };

  final dst = File('$root/assets/mushaf/pages.json');
  dst.parent.createSync(recursive: true);
  dst.writeAsStringSync(jsonEncode(out));
  stdout.writeln('✓ ${dst.path} (${pages.length} pages, ${verseToPage.length} versets)');

  // Bloc pubspec à coller.
  final fontsDir = Directory('$root/tools/build_mushaf/source/fonts');
  final fonts = fontsDir.existsSync()
      ? (fontsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.ttf')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  stdout.writeln('\n# À ajouter dans pubspec.yaml :');
  stdout.writeln('  assets:\n    - assets/mushaf/pages.json');
  stdout.writeln('  fonts:');
  for (final f in fonts) {
    final name = f.uri.pathSegments.last.replaceAll('.ttf', '');
    stdout.writeln('    - family: $name');
    stdout.writeln('      fonts:\n        - asset: assets/mushaf/fonts/${f.uri.pathSegments.last}');
  }
  if (fonts.isEmpty) {
    stdout.writeln('  # (aucune police trouvée dans source/fonts/ — famille attendue : qcf_p<page>)');
  }
}
