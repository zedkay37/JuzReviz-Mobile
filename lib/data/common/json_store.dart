import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Stockage clé→JSON. Une implémentation fichier (prod) et mémoire (tests).
abstract class JsonStore {
  Future<Map<String, dynamic>?> read(String name);
  Future<void> write(String name, Map<String, dynamic> data);
}

class FileJsonStore implements JsonStore {
  FileJsonStore({this.subdir = 'juzreviz'});
  final String subdir;
  Directory? _dir;

  Future<Directory> _ensureDir() async {
    if (_dir != null) return _dir!;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$subdir');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return _dir = dir;
  }

  File _file(Directory dir, String name) => File('${dir.path}/$name.json');

  @override
  Future<Map<String, dynamic>?> read(String name) async {
    final dir = await _ensureDir();
    final f = _file(dir, name);
    if (!f.existsSync()) return null;
    try {
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return null; // fichier corrompu → défauts
    }
  }

  @override
  Future<void> write(String name, Map<String, dynamic> data) async {
    final dir = await _ensureDir();
    final tmp = File('${dir.path}/$name.json.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(_file(dir, name).path); // écriture atomique
  }
}

class MemoryJsonStore implements JsonStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String name) async => _data[name];

  @override
  Future<void> write(String name, Map<String, dynamic> data) async =>
      _data[name] = data;
}
