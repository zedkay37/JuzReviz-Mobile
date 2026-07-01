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
    final s = Settings.fromJsonSanitized({'playbackRate': 9.0, 'veilWords': 99});
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
      focusMode: true,
    );
    final back = Settings.fromJsonSanitized(original.toJson());
    expect(back.reciter, original.reciter);
    expect(back.playbackRate, original.playbackRate);
    expect(back.repeatMode, AudioRepeatMode.range);
    expect(back.contentLang, 'en');
    expect(back.theme, 'rawda');
    expect(back.focusMode, isTrue);
  });
}
