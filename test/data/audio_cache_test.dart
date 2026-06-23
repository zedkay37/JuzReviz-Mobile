import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:juzreviz/data/audio/audio_cache.dart';

final _mp3 = [0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00]; // "ID3"...

void main() {
  test('isLikelyMp3 : accepte ID3 / frame sync, rejette HTML', () {
    expect(isLikelyMp3(_mp3), isTrue);
    expect(isLikelyMp3([0xFF, 0xFB, 0x90]), isTrue);
    expect(isLikelyMp3('<html>'.codeUnits), isFalse);
    expect(isLikelyMp3([0x00]), isFalse);
  });

  test('surahVerseKeys génère 1..n', () {
    expect(surahVerseKeys(2, 3), ['2:1', '2:2', '2:3']);
  });

  test('downloadSurah écrit, cachedFile lit, deleteSurah nettoie', () async {
    final tmp = await Directory.systemTemp.createTemp('juzreviz_audio');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final client = MockClient((req) async => http.Response.bytes(_mp3, 200));
    final repo = AudioCacheRepository(client: client, root: tmp);
    final keys = surahVerseKeys(1, 2);

    var lastDone = 0;
    final ok = await repo.downloadSurah('ar.alafasy', keys,
        onProgress: (d, t) => lastDone = d);
    expect(ok, isTrue);
    expect(lastDone, 2);
    expect(await repo.areVersesDownloaded('ar.alafasy', keys), isTrue);
    expect(await repo.cachedFile('ar.alafasy', '1:1'), isNotNull);
    expect(await repo.surahBytes('ar.alafasy', 1), greaterThan(0));

    await repo.deleteSurah('ar.alafasy', 1);
    expect(await repo.areVersesDownloaded('ar.alafasy', keys), isFalse);
    expect(await repo.cachedFile('ar.alafasy', '1:1'), isNull);
  });

  test('downloadSurah rejette une réponse non-MP3', () async {
    final tmp = await Directory.systemTemp.createTemp('juzreviz_audio2');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final client = MockClient((req) async => http.Response('<html>err</html>', 200));
    final repo = AudioCacheRepository(client: client, root: tmp);
    final ok = await repo.downloadSurah('ar.alafasy', surahVerseKeys(1, 1));
    expect(ok, isFalse);
  });
}
