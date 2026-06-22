import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/tafsir/tafsir_repository.dart';

class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);
  final Map<String, List<int>> files;

  @override
  Future<ByteData> load(String key) async {
    final bytes = files[key];
    if (bytes == null) throw Exception('asset introuvable: $key');
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

void main() {
  test('décompresse + parse le tafsir gzip et résout un verset', () async {
    final json = jsonEncode({'2:1': 'Alif Lam Mim', '2:2': 'Ce Livre…'});
    final gz = gzip.encode(utf8.encode(json));
    final repo = TafsirRepository(
      bundle: _FakeBundle({'assets/tafsir/fr/2.json.gz': gz}),
    );

    expect(await repo.verseTafsir('fr', '2:1'), 'Alif Lam Mim');
    expect(await repo.verseTafsir('fr', '2:2'), 'Ce Livre…');
    expect(await repo.verseTafsir('fr', '2:99'), '');
    // langue/sourate absente → vide, sans crash
    expect(await repo.verseTafsir('en', '2:1'), '');
  });
}
