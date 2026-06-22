import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/playlists/playlist.dart';

class PlaylistsRepository {
  PlaylistsRepository(this._store);
  final JsonStore _store;
  static const _name = 'playlists';

  Future<List<Playlist>> load() async {
    final raw = await _store.read(_name);
    final list = (raw?['playlists'] as List?) ?? const [];
    return list
        .map((e) => Playlist.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> save(List<Playlist> playlists) =>
      _store.write(_name, {'playlists': playlists.map((p) => p.toJson()).toList()});
}
