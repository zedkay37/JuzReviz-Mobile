// ignore_for_file: avoid_print
//
// Pipeline corpus JuzReviz Mobile (Dart pur, zéro dépendance).
//
// Lit les données du desktop JuzReviz2 :
//   - src/data/quran-data.xml      (métadonnées sourates + juz + sajdas, Tanzil)
//   - src/data/tanzil-uthmani.txt  (texte uthmani par verset : `surah|ayah|texte`)
//   - public/data/words/{1..114}.json (mots ar/en/tr/fr + traductions verset en/fr)
//
// Produit, dans assets/corpus/ :
//   - surah_meta.json   (114 métadonnées, avec juzStart calculé)
//   - surah/{n}.json     (versets normalisés : arabe + mots + gloses + traductions)
//   - manifest.json      (compteurs, hash FNV-1a, tailles → vérif intégrité/idempotence)
//
// Déterministe & idempotent : même entrée → mêmes octets → même hash.
//
// Usage : dart run tools/build_corpus/build_corpus.dart [--source <JuzReviz2 dir>]

import 'dart:convert';
import 'dart:io';

const _defaultSource = r'C:\Users\isabu\Documents\GitHub\JuzReviz2';

void main(List<String> args) {
  final sourceDir = _argValue(args, '--source') ?? _defaultSource;
  final scriptDir = File(Platform.script.toFilePath()).parent;
  // tools/build_corpus -> racine projet
  final projectRoot = scriptDir.parent.parent.path;
  final outDir = Directory('$projectRoot/assets/corpus');

  print('Source : $sourceDir');
  print('Sortie : ${outDir.path}');

  final xmlPath = '$sourceDir/src/data/quran-data.xml';
  final tanzilPath = '$sourceDir/src/data/tanzil-uthmani.txt';
  final wordsDir = '$sourceDir/public/data/words';

  for (final p in [xmlPath, tanzilPath, wordsDir]) {
    if (!FileSystemEntity.typeSync(p).toString().contains('Type')) {}
  }
  if (!File(xmlPath).existsSync()) _fail('Introuvable : $xmlPath');
  if (!File(tanzilPath).existsSync()) _fail('Introuvable : $tanzilPath');
  if (!Directory(wordsDir).existsSync()) _fail('Introuvable : $wordsDir');

  final xml = File(xmlPath).readAsStringSync();
  final surahs = _parseSurahs(xml);
  final juzStarts = _parseJuzStarts(xml, surahs);
  final sajdas = _parseSajdas(xml);

  // Texte uthmani par verset.
  final arabicByKey = <String, String>{};
  for (final line in File(tanzilPath).readAsLinesSync()) {
    final m = RegExp(r'^(\d+)\|(\d+)\|(.+)$').firstMatch(line.trim());
    if (m == null) continue;
    arabicByKey['${m[1]}:${m[2]}'] = m[3]!;
  }

  // Index absolu pour le mapping juz (réplique quranData.ts).
  int juzForAbsolute(int absoluteIndex) {
    var current = 1;
    for (final j in juzStarts) {
      if (absoluteIndex >= j.absoluteVerseIndex) {
        current = j.index;
      } else {
        break;
      }
    }
    return current;
  }

  if (outDir.existsSync()) outDir.deleteSync(recursive: true);
  Directory('${outDir.path}/surah').createSync(recursive: true);

  final manifestFiles = <Map<String, Object>>[];
  var totalVerses = 0;
  var totalWords = 0;

  // surah_meta.json
  final metaList = <Map<String, Object>>[];
  var absoluteIndex = 0;
  final absoluteStart = <int, int>{}; // surah -> absolute index du verset 1

  for (final s in surahs) {
    absoluteStart[s.number] = absoluteIndex;
    absoluteIndex += s.ayahCount;
  }

  for (final s in surahs) {
    metaList.add({
      'number': s.number,
      'ayahCount': s.ayahCount,
      'arabicName': s.arabicName,
      'transliteration': s.transliteration,
      'englishName': s.englishName,
      'revelation': s.revelation,
      'hasSajda': sajdas.contains(s.number),
      'juzStart': juzForAbsolute(absoluteStart[s.number]!),
    });
  }
  final metaBytes = _writeJson('${outDir.path}/surah_meta.json', metaList);
  manifestFiles.add(_fileEntry('surah_meta.json', metaBytes));

  // surah/{n}.json
  for (final s in surahs) {
    final wordsFile = File('$wordsDir/${s.number}.json');
    if (!wordsFile.existsSync()) _fail('Mots manquants : ${wordsFile.path}');
    final wordsJson =
        jsonDecode(wordsFile.readAsStringSync()) as Map<String, dynamic>;

    final verses = <Map<String, Object>>[];
    for (var ayah = 1; ayah <= s.ayahCount; ayah++) {
      final key = '${s.number}:$ayah';
      final entry = wordsJson[key] as Map<String, dynamic>?;
      final wList = (entry?['w'] as List?) ?? const [];
      final words = <Map<String, Object>>[];
      for (var i = 0; i < wList.length; i++) {
        final w = wList[i] as Map<String, dynamic>;
        words.add({
          'position': i + 1,
          'ar': (w['ar'] ?? '').toString(),
          'fr': (w['fr'] ?? '').toString(),
          'en': (w['en'] ?? '').toString(),
          'tr': (w['tr'] ?? '').toString(),
          'isWaqf': false,
        });
      }
      totalWords += words.length;
      verses.add({
        'ayah': ayah,
        'verseKey': key,
        'juz': juzForAbsolute(absoluteStart[s.number]! + ayah - 1),
        'arabic': arabicByKey[key] ?? _joinArabic(words),
        'fr': (entry?['fr'] ?? '').toString(),
        'en': (entry?['en'] ?? '').toString(),
        'words': words,
      });
    }
    totalVerses += verses.length;
    final name = 'surah/${s.number}.json';
    final bytes = _writeJson('${outDir.path}/$name', verses);
    manifestFiles.add(_fileEntry(name, bytes));
  }

  // Tafsir : minifié + gzip déterministe par sourate/langue (lazy à l'app).
  final tafsirOut = Directory('$projectRoot/assets/tafsir');
  if (tafsirOut.existsSync()) tafsirOut.deleteSync(recursive: true);
  final tafsirFiles = <Map<String, Object>>[];
  var tafsirRaw = 0;
  var tafsirGz = 0;
  for (final lang in const ['fr', 'en']) {
    final srcDir = Directory('$sourceDir/public/tafsir/$lang');
    if (!srcDir.existsSync()) continue;
    Directory('${tafsirOut.path}/$lang').createSync(recursive: true);
    for (final s in surahs) {
      final src = File('${srcDir.path}/${s.number}.json');
      if (!src.existsSync()) continue;
      final map = (jsonDecode(src.readAsStringSync()) as Map)
          .cast<String, dynamic>();
      final minified = utf8.encode(jsonEncode(map));
      final gz = _gzipDeterministic(minified);
      final name = 'tafsir/$lang/${s.number}.json.gz';
      File('${tafsirOut.path}/$lang/${s.number}.json.gz').writeAsBytesSync(gz);
      tafsirRaw += minified.length;
      tafsirGz += gz.length;
      tafsirFiles.add({
        'path': name,
        'rawBytes': minified.length,
        'gzBytes': gz.length,
        'hash': _fnv1a(minified), // hash du contenu décompressé (idempotence)
      });
    }
  }

  // manifest.json
  final manifest = <String, Object>{
    'schema': 2,
    'generatedFrom': 'JuzReviz2 (Tanzil uthmani + words wbw + tafsir)',
    'attribution':
        'Texte uthmani: Tanzil Project (CC BY 3.0, notice embarquee). '
        'Gloses/traductions/tafsirs: corpus desktop; licences et provenance '
        'a documenter avant distribution.',
    'surahCount': surahs.length,
    'verseCount': totalVerses,
    'wordCount': totalWords,
    'tafsir': {
      'files': tafsirFiles.length,
      'rawBytes': tafsirRaw,
      'gzBytes': tafsirGz,
    },
    'files': [...manifestFiles, ...tafsirFiles],
  };
  _writeJson('${outDir.path}/manifest.json', manifest);

  final mb = (tafsirGz / 1048576).toStringAsFixed(1);
  final raw = (tafsirRaw / 1048576).toStringAsFixed(1);
  print(
    'OK : ${surahs.length} sourates, $totalVerses versets, $totalWords mots.',
  );
  print('Tafsir : ${tafsirFiles.length} fichiers, $raw Mo -> $mb Mo gzip.');
  if (totalVerses != 6236) {
    stderr.writeln('ATTENTION : attendu 6236 versets, obtenu $totalVerses.');
  }
}

/// gzip déterministe : MTIME et OS du header forcés (idempotence cross-run).
List<int> _gzipDeterministic(List<int> data) {
  final out = gzip.encode(data);
  if (out.length >= 10) {
    out[4] = 0;
    out[5] = 0;
    out[6] = 0;
    out[7] = 0; // MTIME = 0
    out[9] = 0xFF; // OS = inconnu
  }
  return out;
}

// --- Parsing XML (regex, tags simples et bien formés) ---

class _Surah {
  _Surah(
    this.number,
    this.ayahCount,
    this.arabicName,
    this.transliteration,
    this.englishName,
    this.revelation,
  );
  final int number;
  final int ayahCount;
  final String arabicName;
  final String transliteration;
  final String englishName;
  final String revelation; // meccan | medinan
}

class _JuzStart {
  _JuzStart(this.index, this.absoluteVerseIndex);
  final int index;
  final int absoluteVerseIndex;
}

List<_Surah> _parseSurahs(String xml) {
  final out = <_Surah>[];
  final re = RegExp(r'<sura\s+([^>]*?)/?>');
  for (final m in re.allMatches(xml)) {
    final attrs = _attrs(m[1]!);
    final type = (attrs['type'] ?? '').toLowerCase();
    out.add(
      _Surah(
        int.parse(attrs['index']!),
        int.parse(attrs['ayas']!),
        attrs['name'] ?? '',
        attrs['tname'] ?? '',
        attrs['ename'] ?? '',
        type == 'medinan' ? 'medinan' : 'meccan',
      ),
    );
  }
  out.sort((a, b) => a.number.compareTo(b.number));
  return out;
}

List<_JuzStart> _parseJuzStarts(String xml, List<_Surah> surahs) {
  // start absolu de chaque sourate
  final starts = <int, int>{};
  var acc = 0;
  for (final s in surahs) {
    starts[s.number] = acc;
    acc += s.ayahCount;
  }
  final out = <_JuzStart>[];
  final re = RegExp(r'<juz\s+([^>]*?)/?>');
  for (final m in re.allMatches(xml)) {
    final attrs = _attrs(m[1]!);
    final sura = int.parse(attrs['sura']!);
    final aya = int.parse(attrs['aya']!);
    out.add(
      _JuzStart(int.parse(attrs['index']!), (starts[sura] ?? 0) + aya - 1),
    );
  }
  out.sort((a, b) => a.index.compareTo(b.index));
  return out;
}

Set<int> _parseSajdas(String xml) {
  final out = <int>{};
  final re = RegExp(r'<sajda\s+([^>]*?)/?>');
  for (final m in re.allMatches(xml)) {
    final attrs = _attrs(m[1]!);
    final sura = attrs['sura'];
    if (sura != null) out.add(int.parse(sura));
  }
  return out;
}

Map<String, String> _attrs(String raw) {
  final out = <String, String>{};
  final re = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
  for (final m in re.allMatches(raw)) {
    out[m[1]!] = m[2]!;
  }
  return out;
}

String _joinArabic(List<Map<String, Object>> words) =>
    words.map((w) => w['ar']).join(' ');

// --- IO + hashing déterministe ---

List<int> _writeJson(String path, Object data) {
  final bytes = utf8.encode(jsonEncode(data));
  File(path).writeAsBytesSync(bytes);
  return bytes;
}

Map<String, Object> _fileEntry(String name, List<int> bytes) => {
  'path': name,
  'bytes': bytes.length,
  'hash': _fnv1a(bytes),
};

/// FNV-1a 64-bit (hex) — déterministe, sans dépendance (vérif idempotence).
String _fnv1a(List<int> bytes) {
  var hash = BigInt.parse('14695981039346656037');
  final prime = BigInt.parse('1099511628211');
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final b in bytes) {
    hash = (hash ^ BigInt.from(b)) & mask;
    hash = (hash * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

String? _argValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return null;
}

Never _fail(String msg) {
  stderr.writeln('ERREUR : $msg');
  exit(1);
}
