import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/playlists/playlists_repository.dart';

void main() {
  test(
    'le chargement conserve les playlists valides autour des entrees cassees',
    () async {
      final store = MemoryJsonStore();
      await store.write('playlists', {
        'playlists': [
          {
            'id': 'ok',
            'name': 'Revision',
            'items': [
              {
                'id': 'valid',
                'label': 'Al-Fatiha',
                'selection': {'mode': 'surah', 'surah': 1, 'from': 1, 'to': 7},
              },
              {'id': 'broken', 'selection': 'pas un objet'},
            ],
          },
          {'name': 'sans identifiant'},
          'pas un objet',
        ],
      });

      final playlists = await PlaylistsRepository(store).load();
      expect(playlists.single.id, 'ok');
      expect(playlists.single.items.single.id, 'valid');
    },
  );
}
