import 'package:juzreviz/domain/model/selection.dart';

class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.selection,
    required this.label,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final rawSelection = j['selection'];
    if (id is! String || id.isEmpty || rawSelection is! Map) {
      throw const FormatException('Element de playlist invalide');
    }
    return PlaylistItem(
      id: id,
      selection: Selection.fromJson(rawSelection.cast<String, dynamic>()),
      label: j['label'] is String ? j['label'] as String : '',
    );
  }

  final String id;
  final Selection selection;
  final String label;

  Map<String, dynamic> toJson() => {
    'id': id,
    'selection': selection.toJson(),
    'label': label,
  };
}

class Playlist {
  const Playlist({required this.id, required this.name, this.items = const []});

  factory Playlist.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Playlist invalide');
    }
    final items = <PlaylistItem>[];
    final rawItems = j['items'];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        try {
          items.add(PlaylistItem.fromJson(raw.cast<String, dynamic>()));
        } on FormatException {
          // Une entree corrompue ne doit pas rendre toute la playlist illisible.
        }
      }
    }
    return Playlist(
      id: id,
      name: j['name'] is String ? j['name'] as String : '',
      items: List.unmodifiable(items),
    );
  }

  final String id;
  final String name;
  final List<PlaylistItem> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
  };

  Playlist copyWith({String? name, List<PlaylistItem>? items}) =>
      Playlist(id: id, name: name ?? this.name, items: items ?? this.items);
}
