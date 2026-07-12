import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/playlists/playlist.dart';

class PlaylistsRepository {
  PlaylistsRepository(this._store);
  final JsonStore _store;
  static const _name = 'playlists';

  Future<List<Playlist>> load() async {
    final raw = await _store.read(_name);
    final list = (raw?['playlists'] as List?) ?? const [];
    final playlists = <Playlist>[];
    for (final entry in list) {
      if (entry is! Map) continue;
      try {
        playlists.add(Playlist.fromJson(entry.cast<String, dynamic>()));
      } on FormatException {
        // Ignore seulement l'entree invalide et conserve les autres listes.
      }
    }
    return playlists;
  }

  Future<void> save(List<Playlist> playlists) => _store.write(_name, {
    'playlists': playlists.map((p) => p.toJson()).toList(),
  });
}
