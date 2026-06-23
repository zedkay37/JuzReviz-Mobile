// Récupère le pack QCF v1 (polices + mise en page) UNE FOIS, pour produire des
// assets 100 % offline. Après ce script + build_mushaf.dart, l'app n'utilise
// plus jamais le réseau pour le moushaf.
//
//   dart run tools/build_mushaf/fetch_qpc.dart            # tout
//   dart run tools/build_mushaf/fetch_qpc.dart --layout   # données seules
//   dart run tools/build_mushaf/fetch_qpc.dart --fonts    # polices seules
//
// Sorties :
//   tools/build_mushaf/source/fonts/p{1..604}.ttf
//   tools/build_mushaf/source/words.json
//
// Sources publiques :
//   Polices : https://verses.quran.foundation/fonts/quran/hafs/v1/ttf/p{n}.ttf
//   Layout  : https://api.quran.com/api/v4/verses/by_page/{n} (mushaf=2 = QCF v1)

import 'dart:convert';
import 'dart:io';

const _fontUrl = 'https://verses.quran.foundation/fonts/quran/hafs/v1/ttf';
const _layoutUrl = 'https://api.quran.com/api/v4/verses/by_page';
const _pages = 604;

Future<void> main(List<String> args) async {
  final doFonts = args.isEmpty || args.contains('--fonts');
  final doLayout = args.isEmpty || args.contains('--layout');
  final root = Directory.current.path;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);

  if (doFonts) await _fetchFonts(client, root);
  if (doLayout) await _fetchLayout(client, root);
  client.close();
  stdout.writeln('\nTerminé. Puis : dart run tools/build_mushaf/build_mushaf.dart');
}

Future<void> _fetchFonts(HttpClient client, String root) async {
  final dir = Directory('$root/tools/build_mushaf/source/fonts')
    ..createSync(recursive: true);
  for (var p = 1; p <= _pages; p++) {
    final out = File('${dir.path}/p$p.ttf');
    if (out.existsSync() && out.lengthSync() > 0) continue;
    final bytes = await _getBytes(client, '$_fontUrl/p$p.ttf');
    if (bytes == null) {
      stderr.writeln('Police p$p : échec (à réessayer)');
      continue;
    }
    await out.writeAsBytes(bytes, flush: true);
    if (p % 50 == 0) stdout.writeln('Polices : $p / $_pages');
  }
  stdout.writeln('✓ Polices dans ${dir.path}');
}

Future<void> _fetchLayout(HttpClient client, String root) async {
  final words = <Map<String, dynamic>>[];
  final seenSurah = <int>{};
  for (var p = 1; p <= _pages; p++) {
    final url =
        '$_layoutUrl/$p?words=true&per_page=300&word_fields=code_v1,line_number,page_number,char_type_name';
    final json = await _getJson(client, url);
    if (json == null) {
      stderr.writeln('Page $p : échec layout');
      continue;
    }
    final verses = (json['verses'] as List?) ?? const [];
    var minLine = 99;
    for (final v in verses) {
      for (final w in ((v as Map)['words'] as List? ?? const [])) {
        final line = ((w as Map)['line_number'] as num?)?.toInt() ?? 0;
        if (line < minLine) minLine = line;
      }
    }
    for (final v in verses) {
      final key = ((v as Map)['verse_key'] ?? '') as String;
      final surah = int.tryParse(key.split(':').first) ?? 0;
      final ayah = int.tryParse(key.split(':').last) ?? 0;
      // En-tête de sourate + basmala synthétisés au début d'une nouvelle sourate.
      if (ayah == 1 && surah > 1 && !seenSurah.contains(surah)) {
        words.add({'page': p, 'line': minLine - 2, 'type': 'surah', 'surah': surah, 'key': '$surah:0'});
        if (surah != 9) {
          words.add({'page': p, 'line': minLine - 1, 'type': 'basmalah', 'key': '$surah:0'});
        }
      }
      seenSurah.add(surah);
      for (final w in (v['words'] as List? ?? const [])) {
        final m = (w as Map);
        words.add({
          'page': p,
          'line': (m['line_number'] as num?)?.toInt() ?? 0,
          'key': key,
          'code': m['code_v1'] ?? '',
          'type': 'word',
        });
      }
    }
    if (p % 50 == 0) stdout.writeln('Layout : $p / $_pages');
  }
  final out = File('$root/tools/build_mushaf/source/words.json')
    ..parent.createSync(recursive: true);
  out.writeAsStringSync(jsonEncode(words));
  stdout.writeln('✓ ${out.path} (${words.length} entrées)');
}

Future<List<int>?> _getBytes(HttpClient client, String url) async {
  try {
    final req = await client.getUrl(Uri.parse(url));
    final resp = await req.close();
    if (resp.statusCode != 200) return null;
    final b = <int>[];
    await for (final chunk in resp) {
      b.addAll(chunk);
    }
    return b;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> _getJson(HttpClient client, String url) async {
  final b = await _getBytes(client, url);
  if (b == null) return null;
  try {
    return (jsonDecode(utf8.decode(b)) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}
