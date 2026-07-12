import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';

void main() {
  test('défauts garantis sur JSON vide', () {
    final s = Settings.fromJsonSanitized({});
    expect(s.reciter, 'ar.alafasy');
    expect(s.readerWordByWord, isTrue);
    expect(s.masteryProfile, MasteryProfile.serenity);
    expect(s.veilMode, VeilMode.full);
    expect(s.hasReadingProgress, isFalse);
  });

  test('clé inconnue ignorée, clés valides conservées', () {
    final s = Settings.fromJsonSanitized({
      'reciter': 'ar.husary',
      'playbackRate': 1.5,
      'inconnue': 42,
      'veilMode': 'firstWords',
      'masteryProfile': 'excellence',
    });
    expect(s.reciter, 'ar.husary');
    expect(s.playbackRate, 1.5);
    expect(s.veilMode, VeilMode.firstWords);
    expect(s.masteryProfile, MasteryProfile.excellence);
  });

  test('valeurs hors bornes clampées', () {
    final s = Settings.fromJsonSanitized({
      'playbackRate': 9.0,
      'veilWords': 99,
    });
    expect(s.playbackRate, 2.0);
    expect(s.veilWords, 10);
  });

  test('round-trip toJson/fromJsonSanitized', () {
    const original = Settings(
      reciter: 'ar.sudais',
      playbackRate: 1.25,
      repeatMode: AudioRepeatMode.range,
      contentLang: 'en',
      theme: 'rawda',
      latinAyahNumbers: true,
      currentVerseKey: '2:42',
      hasReadingProgress: true,
    );
    final back = Settings.fromJsonSanitized(original.toJson());
    expect(back.reciter, original.reciter);
    expect(back.playbackRate, original.playbackRate);
    expect(back.repeatMode, AudioRepeatMode.range);
    expect(back.contentLang, 'en');
    expect(back.theme, 'rawda');
    expect(back.latinAyahNumbers, isTrue);
    expect(back.currentVerseKey, '2:42');
    expect(back.hasReadingProgress, isTrue);
  });

  test('migration des anciens layouts mushaf', () {
    expect(readerLayoutFromString('mushafTajweed'), ReaderLayout.mushaf);
    expect(readerLayoutFromString('mushafMadni'), ReaderLayout.mushaf);
    expect(readerLayoutFromString('inconnu'), ReaderLayout.flexible);
  });

  test('une ancienne position non initiale restaure la reprise', () {
    final migrated = Settings.fromJsonSanitized({'currentVerseKey': '36:12'});
    expect(migrated.hasReadingProgress, isTrue);
  });

  test('valeurs persistantes invalides reviennent a des valeurs sures', () {
    final s = Settings.fromJsonSanitized({
      'reciter': '../../hors-cache',
      'contentLang': 'de',
      'theme': 'inconnu',
      'reminderTime': '27:99',
      'currentVerseKey': '../1:999',
      'readerLayout': 'inconnu',
    });

    expect(s.reciter, 'ar.alafasy');
    expect(s.contentLang, 'fr');
    expect(s.theme, 'lanterne');
    expect(s.reminderTime, '08:00');
    expect(s.currentVerseKey, '1:1');
    expect(s.readerLayout, ReaderLayout.flexible.id);
  });
}
