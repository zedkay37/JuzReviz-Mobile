import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juzreviz/data/mushaf/mushaf_font_store.dart';

List<int> _fontBytes() => [0, 1, 0, 0, ...List<int>.filled(1200, 0)];

void main() {
  test('valide les signatures OpenType/TrueType', () {
    expect(isLikelyFont(_fontBytes()), isTrue);
    expect(isLikelyFont('OTTO${'x' * 1200}'.codeUnits), isTrue);
    expect(isLikelyFont('<html>${'x' * 1200}'.codeUnits), isFalse);
  });

  test('le pack peut être retéléchargé après suppression', () async {
    final root = await Directory.systemTemp.createTemp('juzreviz_mushaf');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final client = MockClient(
      (_) async => http.Response.bytes(_fontBytes(), 200),
    );
    final store = MushafFontStore(client: client, root: root, pageCount: 2);

    expect(await store.download(), isTrue);
    expect(await store.isDownloaded(), isTrue);

    await store.deleteAll();
    expect(await store.isDownloaded(), isFalse);
    expect(await store.download(), isTrue);
    expect(await store.isDownloaded(), isTrue);
  });

  test('le marqueur ne masque pas une police locale corrompue', () async {
    final root = await Directory.systemTemp.createTemp('juzreviz_mushaf_bad');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    await File('${root.path}/.ok').writeAsString('ok');
    await File('${root.path}/p1.ttf').writeAsString('<html>corrompu</html>');
    final client = MockClient(
      (_) async => http.Response.bytes(_fontBytes(), 200),
    );
    final store = MushafFontStore(client: client, root: root, pageCount: 1);

    expect(await store.isDownloaded(), isFalse);
    expect(await store.download(), isTrue);
    expect(await store.isDownloaded(), isTrue);
  });
}
