// ignore_for_file: avoid_print

/// Vérifie et régénère le manifeste des assets corpus/tafsir sans dépendre du
/// dépôt source desktop.
///
/// Usage :
///   dart run tools/build_corpus/verify_manifest.dart
///   dart run tools/build_corpus/verify_manifest.dart --write
library;

import 'dart:convert';
import 'dart:io';

const _schema = 2;
const _expectedSurahCount = 114;
const _expectedVerseCount = 6236;
const _languages = ['fr', 'en'];
const _generatedFrom = 'JuzReviz2 (Tanzil uthmani + words wbw + tafsir)';
const _attribution =
    'Texte uthmani: Tanzil Project (CC BY 3.0, notice embarquee). '
    'Gloses/traductions/tafsirs: corpus desktop; licences et provenance '
    'a documenter avant distribution.';

void main(List<String> args) {
  if (args.any((arg) => arg != '--write') || args.length > 1) {
    stderr.writeln(
      'Usage: dart run tools/build_corpus/verify_manifest.dart [--write]',
    );
    exitCode = 64;
    return;
  }

  try {
    _verifyHasher();
    final scriptDir = File.fromUri(Platform.script).parent;
    final projectRoot = scriptDir.parent.parent;
    final result = _buildManifest(projectRoot);
    final manifestFile = File(
      '${projectRoot.path}/assets/corpus/manifest.json',
    );
    final canonical = jsonEncode(result.manifest);

    if (args.contains('--write')) {
      manifestFile.writeAsStringSync(canonical, flush: true);
      print('Manifeste régénéré : ${manifestFile.path}');
    } else {
      if (!manifestFile.existsSync()) {
        _fail('Manifest absent : ${manifestFile.path}');
      }
      final committed = manifestFile.readAsStringSync();
      if (committed != canonical) {
        _fail(
          'Manifest obsolète ou non canonique. Régénérer avec :\n'
          'dart run tools/build_corpus/verify_manifest.dart --write',
        );
      }
    }

    final tafsir = result.manifest['tafsir']! as Map<String, Object>;
    print(
      'OK : ${result.manifest['surahCount']} sourates, '
      '${result.manifest['verseCount']} versets, '
      '${result.manifest['wordCount']} mots ; '
      '${tafsir['files']} tafsirs '
      '(${tafsir['rawBytes']} octets bruts, ${tafsir['gzBytes']} gzip).',
    );
  } on Object catch (error) {
    stderr.writeln('ERREUR : $error');
    exitCode = 1;
  }
}

({Map<String, Object> manifest}) _buildManifest(Directory projectRoot) {
  final corpusDir = Directory('${projectRoot.path}/assets/corpus');
  final tafsirDir = Directory('${projectRoot.path}/assets/tafsir');
  if (!corpusDir.existsSync()) {
    _fail('Dossier corpus absent : ${corpusDir.path}');
  }
  if (!tafsirDir.existsSync()) {
    _fail('Dossier tafsir absent : ${tafsirDir.path}');
  }

  final manifestFiles = <Map<String, Object>>[];
  final metaFile = File('${corpusDir.path}/surah_meta.json');
  final metaBytes = _readBytes(metaFile);
  final metaList = _asList(
    _decodeJson(metaBytes, 'surah_meta.json'),
    'surah_meta.json',
  );
  if (metaList.length != _expectedSurahCount) {
    _fail(
      'surah_meta.json : ${metaList.length} sourates, '
      '$_expectedSurahCount attendues.',
    );
  }
  manifestFiles.add(_corpusEntry('surah_meta.json', metaBytes));

  final ayahCounts = <int, int>{};
  for (var i = 0; i < metaList.length; i++) {
    final meta = _asMap(metaList[i], 'surah_meta.json[$i]');
    final number = _asInt(meta['number'], 'surah_meta.json[$i].number');
    final ayahCount = _asInt(
      meta['ayahCount'],
      'surah_meta.json[$i].ayahCount',
    );
    if (number != i + 1) {
      _fail('surah_meta.json[$i] : sourate ${i + 1} attendue, obtenu $number.');
    }
    if (ayahCount <= 0) {
      _fail('Sourate $number : ayahCount doit être strictement positif.');
    }
    ayahCounts[number] = ayahCount;
  }

  final expectedCorpusFiles = <String>{'surah_meta.json'};
  var verseCount = 0;
  var wordCount = 0;
  for (var surah = 1; surah <= _expectedSurahCount; surah++) {
    final relativePath = 'surah/$surah.json';
    expectedCorpusFiles.add(relativePath);
    final bytes = _readBytes(File('${corpusDir.path}/$relativePath'));
    final verses = _asList(_decodeJson(bytes, relativePath), relativePath);
    final expectedAyahs = ayahCounts[surah]!;
    if (verses.length != expectedAyahs) {
      _fail(
        '$relativePath : ${verses.length} versets, $expectedAyahs attendus.',
      );
    }

    for (var i = 0; i < verses.length; i++) {
      final label = '$relativePath[$i]';
      final verse = _asMap(verses[i], label);
      final expectedAyah = i + 1;
      final ayah = _asInt(verse['ayah'], '$label.ayah');
      final verseKey = verse['verseKey'];
      if (ayah != expectedAyah || verseKey != '$surah:$expectedAyah') {
        _fail(
          '$label : attendu $surah:$expectedAyah, '
          'obtenu verseKey=$verseKey, ayah=$ayah.',
        );
      }
      final juz = _asInt(verse['juz'], '$label.juz');
      if (juz < 1 || juz > 30) _fail('$label.juz hors bornes : $juz.');
      final words = _asList(verse['words'], '$label.words');
      for (var w = 0; w < words.length; w++) {
        final word = _asMap(words[w], '$label.words[$w]');
        final position = _asInt(word['position'], '$label.words[$w].position');
        if (position != w + 1) {
          _fail(
            '$label.words[$w] : position ${w + 1} attendue, obtenu $position.',
          );
        }
      }
      wordCount += words.length;
    }
    verseCount += verses.length;
    manifestFiles.add(_corpusEntry(relativePath, bytes));
  }

  if (verseCount != _expectedVerseCount) {
    _fail('$verseCount versets trouvés, $_expectedVerseCount attendus.');
  }
  _checkFileSet(
    label: 'corpus',
    expected: expectedCorpusFiles,
    actual: _relativeFiles(corpusDir)..remove('manifest.json'),
  );

  final tafsirFiles = <Map<String, Object>>[];
  final expectedTafsirFiles = <String>{};
  var tafsirRawBytes = 0;
  var tafsirGzBytes = 0;
  for (final language in _languages) {
    for (var surah = 1; surah <= _expectedSurahCount; surah++) {
      final diskPath = '$language/$surah.json.gz';
      final manifestPath = 'tafsir/$diskPath';
      expectedTafsirFiles.add(diskPath);
      final compressed = _readBytes(File('${tafsirDir.path}/$diskPath'));
      if (compressed.length < 10) _fail('$manifestPath : gzip trop court.');
      if (compressed[4] != 0 ||
          compressed[5] != 0 ||
          compressed[6] != 0 ||
          compressed[7] != 0 ||
          compressed[9] != 0xff) {
        _fail('$manifestPath : en-tête gzip non déterministe (MTIME/OS).');
      }

      late final List<int> raw;
      try {
        raw = gzip.decode(compressed);
      } on Object catch (error) {
        _fail('$manifestPath : gzip invalide ($error).');
      }
      _asMap(_decodeJson(raw, manifestPath), manifestPath);

      tafsirRawBytes += raw.length;
      tafsirGzBytes += compressed.length;
      tafsirFiles.add({
        'path': manifestPath,
        'rawBytes': raw.length,
        'gzBytes': compressed.length,
        'hash': _fnv1a(raw),
      });
    }
  }
  _checkFileSet(
    label: 'tafsir',
    expected: expectedTafsirFiles,
    actual: _relativeFiles(tafsirDir),
  );

  final manifest = <String, Object>{
    'schema': _schema,
    'generatedFrom': _generatedFrom,
    'attribution': _attribution,
    'surahCount': ayahCounts.length,
    'verseCount': verseCount,
    'wordCount': wordCount,
    'tafsir': <String, Object>{
      'files': tafsirFiles.length,
      'rawBytes': tafsirRawBytes,
      'gzBytes': tafsirGzBytes,
    },
    'files': <Map<String, Object>>[...manifestFiles, ...tafsirFiles],
  };
  return (manifest: manifest);
}

Map<String, Object> _corpusEntry(String path, List<int> bytes) => {
  'path': path,
  'bytes': bytes.length,
  'hash': _fnv1a(bytes),
};

List<int> _readBytes(File file) {
  if (!file.existsSync()) _fail('Fichier absent : ${file.path}');
  return file.readAsBytesSync();
}

Object? _decodeJson(List<int> bytes, String label) {
  try {
    return jsonDecode(utf8.decode(bytes));
  } on Object catch (error) {
    _fail('$label : JSON/UTF-8 invalide ($error).');
  }
}

List<Object?> _asList(Object? value, String label) {
  if (value is! List) _fail('$label : liste JSON attendue.');
  return value.cast<Object?>();
}

Map<String, Object?> _asMap(Object? value, String label) {
  if (value is! Map) _fail('$label : objet JSON attendu.');
  try {
    return value.cast<String, Object?>();
  } on Object catch (error) {
    _fail('$label : clés JSON invalides ($error).');
  }
}

int _asInt(Object? value, String label) {
  if (value is! num || value.toInt() != value) {
    _fail('$label : entier attendu, obtenu $value.');
  }
  return value.toInt();
}

Set<String> _relativeFiles(Directory directory) {
  final prefixLength = directory.path.length + 1;
  return {
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    ))
      if (entity is File)
        entity.path.substring(prefixLength).replaceAll(r'\', '/'),
  };
}

void _checkFileSet({
  required String label,
  required Set<String> expected,
  required Set<String> actual,
}) {
  final missing = expected.difference(actual).toList()..sort();
  final unexpected = actual.difference(expected).toList()..sort();
  if (missing.isEmpty && unexpected.isEmpty) return;
  _fail(
    '$label : ensemble de fichiers invalide.'
    '${missing.isEmpty ? '' : '\nManquants : ${missing.join(', ')}'}'
    '${unexpected.isEmpty ? '' : '\nInattendus : ${unexpected.join(', ')}'}',
  );
}

/// FNV-1a 64 bits via deux mots de 32 bits.
///
/// `prime = 0x00000100_000001b3`; cette forme évite une allocation [BigInt]
/// par octet tout en restant exacte modulo 2^64.
String _fnv1a(List<int> bytes) {
  var high = 0xcbf29ce4;
  var low = 0x84222325;
  for (final byte in bytes) {
    low ^= byte;
    final lowProduct = low * 0x1b3;
    final carry = lowProduct >> 32;
    high = (high * 0x1b3 + low * 0x100 + carry) & 0xffffffff;
    low = lowProduct & 0xffffffff;
  }
  return '${high.toRadixString(16).padLeft(8, '0')}'
      '${low.toRadixString(16).padLeft(8, '0')}';
}

void _verifyHasher() {
  if (_fnv1a(const []) != 'cbf29ce484222325' ||
      _fnv1a(utf8.encode('hello')) != 'a430d84680aabd0b') {
    _fail('Auto-test FNV-1a échoué.');
  }
}

Never _fail(String message) => throw FormatException(message);
