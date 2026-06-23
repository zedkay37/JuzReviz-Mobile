import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const mushafPageCount = 604;
const _fontBase = 'https://verses.quran.foundation/fonts/quran/hafs/v1/ttf';

/// Pack moushaf téléchargeable : récupère les 604 polices QCF v1 dans le
/// stockage de l'app (offline-first après le 1er téléchargement), puis les
/// charge paresseusement (`FontLoader`) par page. Garde l'APK léger.
class MushafFontStore {
  MushafFontStore({http.Client? client, Directory? root})
      : _client = client ?? http.Client(),
        _root = root;

  final http.Client _client;
  Directory? _root;
  final Set<int> _loaded = {};

  Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/juzreviz/mushaf');
    if (!d.existsSync()) d.createSync(recursive: true);
    return _root = d;
  }

  Future<File> _file(int page) async => File('${(await _dir()).path}/p$page.ttf');
  Future<File> _marker() async => File('${(await _dir()).path}/.ok');

  /// Vrai si le pack est intégralement téléchargé.
  Future<bool> isDownloaded() async => (await _marker()).existsSync();

  Future<int> totalBytes() async {
    final d = await _dir();
    if (!d.existsSync()) return 0;
    var total = 0;
    for (final e in d.listSync()) {
      if (e is File) total += e.lengthSync();
    }
    return total;
  }

  /// Télécharge les polices manquantes (reprise), écriture atomique.
  Future<bool> download({
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    for (var p = 1; p <= mushafPageCount; p++) {
      if (cancelled?.call() ?? false) return false;
      final f = await _file(p);
      if (!(f.existsSync() && f.lengthSync() > 0)) {
        try {
          final resp = await _client.get(Uri.parse('$_fontBase/p$p.ttf'));
          if (resp.statusCode != 200 || resp.bodyBytes.length < 1000) {
            return false;
          }
          final tmp = File('${f.path}.part');
          await tmp.writeAsBytes(resp.bodyBytes, flush: true);
          await tmp.rename(f.path);
        } catch (_) {
          return false;
        }
      }
      onProgress?.call(p, mushafPageCount);
    }
    await (await _marker()).writeAsString('ok');
    return true;
  }

  Future<void> deleteAll() async {
    final d = await _dir();
    if (d.existsSync()) d.deleteSync(recursive: true);
    _loaded.clear();
  }

  /// Charge (une fois) la police d'une page depuis le stockage → famille `p<n>`.
  Future<void> ensureLoaded(int page) async {
    if (_loaded.contains(page)) return;
    final f = await _file(page);
    if (!f.existsSync()) throw StateError('Police moushaf p$page absente.');
    final bytes = await f.readAsBytes();
    final data = ByteData.view(Uint8List.fromList(bytes).buffer);
    final loader = FontLoader('p$page')..addFont(Future.value(data));
    await loader.load();
    _loaded.add(page);
  }
}
