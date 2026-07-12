import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/backup/backup_payload.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';
import 'package:juzreviz/data/playlists/playlist.dart';
import 'package:juzreviz/data/settings/settings.dart';

void main() {
  test('encode une sauvegarde versionnée', () {
    final raw = BackupPayload(
      settings: const Settings(),
      mastery: const MasteryState(),
      playlists: const <Playlist>[],
    ).encode();

    final map = jsonDecode(raw) as Map<String, dynamic>;
    expect(map['schema'], BackupPayload.currentSchema);
    expect(map['settings'], isA<Map>());
    expect(map['mastery'], isA<Map>());
    expect(map['playlists'], isEmpty);
  });

  test('reste compatible avec une sauvegarde sans schema', () {
    final backup = BackupPayload.decode(
      jsonEncode({
        'settings': const Settings().toJson(),
        'mastery': const MasteryState().toJson(),
        'playlists': <Object>[],
      }),
    );

    expect(backup.settings, isNotNull);
    expect(backup.mastery, isNotNull);
    expect(backup.playlists, isEmpty);
  });

  test('rejette toutes les sections si une playlist est invalide', () {
    final raw = jsonEncode({
      'schema': 1,
      'settings': const Settings().toJson(),
      'mastery': const MasteryState().toJson(),
      'playlists': [
        {'name': 'Identifiant manquant'},
      ],
    });

    expect(() => BackupPayload.decode(raw), throwsA(isA<FormatException>()));
  });

  test('rejette une version future au lieu de l’importer partiellement', () {
    expect(
      () => BackupPayload.decode('{"schema":2,"settings":{}}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejette une progression tolérable par le stockage mais dangereuse', () {
    final raw = jsonEncode({
      'settings': const Settings().toJson(),
      'mastery': {'fragile': 'oops'},
      'playlists': <Object>[],
    });

    expect(() => BackupPayload.decode(raw), throwsFormatException);
  });

  test('rejette un element de playlist silencieusement recuperable', () {
    final raw = jsonEncode({
      'settings': const Settings().toJson(),
      'mastery': const MasteryState().toJson(),
      'playlists': [
        {
          'id': 'playlist',
          'name': 'Revision',
          'items': [
            {'id': 'casse', 'selection': 'oops'},
          ],
        },
      ],
    });

    expect(() => BackupPayload.decode(raw), throwsFormatException);
  });

  test('schema courant exige les trois sections completes', () {
    expect(
      () => BackupPayload.decode(
        jsonEncode({'schema': 1, 'settings': const Settings().toJson()}),
      ),
      throwsFormatException,
    );
  });

  test('legacy partiel ne peut pas reinitialiser le reste par defaut', () {
    expect(
      () => BackupPayload.decode(
        jsonEncode({
          'settings': {'reciter': 'ar.husary'},
          'mastery': {'fragile': <String, dynamic>{}},
          'playlists': <Object>[],
        }),
      ),
      throwsFormatException,
    );
  });
}
