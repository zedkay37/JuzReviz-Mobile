import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

const mushafPageCount = 604;
const _fontBase = 'https://verses.quran.foundation/fonts/quran/hafs/v1/ttf';

bool isLikelyFont(List<int> bytes) {
  if (bytes.length < 4) return false;
  final signature = String.fromCharCodes(bytes.take(4));
  return (bytes[0] == 0 && bytes[1] == 1 && bytes[2] == 0 && bytes[3] == 0) ||
      signature == 'OTTO' ||
      signature == 'true' ||
      signature == 'typ1';
}

/// Pack moushaf téléchargeable : récupère les 604 polices QCF v1 dans le
/// stockage de l'app (offline-first après le 1er téléchargement), puis les
/// charge paresseusement (`FontLoader`) par page. Garde l'APK léger.
class MushafFontStore {
  MushafFontStore({
    http.Client? client,
    Directory? root,
    this.pageCount = mushafPageCount,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _root = root;

  final http.Client _client;
  final int pageCount;
  final Duration requestTimeout;
  Directory? _root;
  final Set<int> _loaded = {};

  Future<Directory> _dir() async {
    final existing = _root;
    if (existing != null) {
      if (!await existing.exists()) await existing.create(recursive: true);
      return existing;
    }
    final base = await getApplicationCacheDirectory();
    final created = Directory('${base.path}/juzreviz/mushaf');
    await _migrateLegacyCache(created);
    if (!await created.exists()) await created.create(recursive: true);
    return _root = created;
  }

  Future<void> _migrateLegacyCache(Directory target) async {
    if (await target.exists()) return;
    final support = await getApplicationSupportDirectory();
    final legacy = Directory('${support.path}/juzreviz/mushaf');
    if (!await legacy.exists()) return;
    try {
      await target.parent.create(recursive: true);
      await legacy.rename(target.path);
    } catch (_) {
      // Le pack est retéléchargeable : une migration impossible ne doit pas
      // empêcher le démarrage ou l'accès aux autres dispositions du lecteur.
    }
  }

  Future<File> _file(int page) async =>
      File('${(await _dir()).path}/p$page.ttf');
  Future<File> _marker() async => File('${(await _dir()).path}/.ok');

  /// Vrai si le marqueur et les 604 polices du pack sont présents et valides.
  Future<bool> isDownloaded() async {
    if (!await (await _marker()).exists()) return false;
    for (var page = 1; page <= pageCount; page++) {
      if (!await _isValidStoredFont(await _file(page))) return false;
    }
    return true;
  }

  Future<int> totalBytes() async {
    final d = await _dir();
    if (!await d.exists()) return 0;
    var total = 0;
    await for (final e in d.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  /// Télécharge les polices manquantes (reprise), écriture atomique.
  Future<bool> download({
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    for (var p = 1; p <= pageCount; p++) {
      if (cancelled?.call() ?? false) return false;
      final f = await _file(p);
      if (!await _isValidStoredFont(f)) {
        try {
          final resp = await _client
              .get(Uri.parse('$_fontBase/p$p.ttf'))
              .timeout(requestTimeout);
          if (resp.statusCode != 200 ||
              resp.bodyBytes.length < 1000 ||
              !isLikelyFont(resp.bodyBytes)) {
            return false;
          }
          await f.parent.create(recursive: true);
          final tmp = File('${f.path}.part');
          await tmp.writeAsBytes(resp.bodyBytes, flush: true);
          await tmp.rename(f.path);
        } catch (_) {
          return false;
        }
      }
      onProgress?.call(p, pageCount);
    }
    await (await _marker()).writeAsString('ok');
    return true;
  }

  Future<void> deleteAll() async {
    final d = await _dir();
    if (await d.exists()) await d.delete(recursive: true);
    _loaded.clear();
  }

  /// Charge (une fois) la police d'une page depuis le stockage → famille `p<n>`.
  Future<void> ensureLoaded(int page) async {
    if (_loaded.contains(page)) return;
    final f = await _file(page);
    if (!await f.exists()) throw StateError('Police moushaf p$page absente.');
    final bytes = await f.readAsBytes();
    final data = ByteData.view(Uint8List.fromList(bytes).buffer);
    final loader = FontLoader('p$page')..addFont(Future.value(data));
    await loader.load();
    _loaded.add(page);
  }

  Future<bool> _isValidStoredFont(File file) async {
    if (!await file.exists() || await file.length() < 1000) return false;
    RandomAccessFile? handle;
    try {
      handle = await file.open();
      return isLikelyFont(await handle.read(4));
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }
}
