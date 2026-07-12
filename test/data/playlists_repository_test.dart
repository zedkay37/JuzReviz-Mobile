import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/playlists/playlists_repository.dart';
import 'package:juzreviz/domain/model/selection.dart';

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

  test('Annuler restaure un passage à sa position d’origine', () async {
    final container = ProviderContainer(
      overrides: [jsonStoreProvider.overrideWithValue(MemoryJsonStore())],
    );
    addTearDown(container.dispose);
    await container.read(playlistsControllerProvider.future);
    final controller = container.read(playlistsControllerProvider.notifier);
    final playlist = await controller.create('Test');
    await controller.addItem(playlist.id, const SelSurah(1, 1, 7));
    await controller.addItem(playlist.id, const SelJuz(30));

    final before = container
        .read(playlistsControllerProvider)
        .requireValue
        .single;
    final removed = before.items.first;
    await controller.removeItem(playlist.id, removed.id);
    await controller.restoreItem(playlist.id, removed, 0);

    final after = container
        .read(playlistsControllerProvider)
        .requireValue
        .single;
    expect(
      after.items.map((item) => item.id),
      before.items.map((item) => item.id),
    );
  });
}
