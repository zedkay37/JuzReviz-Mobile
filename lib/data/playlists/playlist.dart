import 'package:juzreviz/domain/model/selection.dart';

class PlaylistItem {
  const PlaylistItem({
    required this.id,
    required this.selection,
    required this.label,
  });

  factory PlaylistItem.fromJson(Map<String, dynamic> j) => PlaylistItem(
        id: j['id'] as String,
        selection:
            Selection.fromJson((j['selection'] as Map).cast<String, dynamic>()),
        label: (j['label'] ?? '') as String,
      );

  final String id;
  final Selection selection;
  final String label;

  Map<String, dynamic> toJson() =>
      {'id': id, 'selection': selection.toJson(), 'label': label};
}

class Playlist {
  const Playlist({required this.id, required this.name, this.items = const []});

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        items: ((j['items'] as List?) ?? const [])
            .map((e) => PlaylistItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(growable: false),
      );

  final String id;
  final String name;
  final List<PlaylistItem> items;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'items': items.map((e) => e.toJson()).toList()};

  Playlist copyWith({String? name, List<PlaylistItem>? items}) =>
      Playlist(id: id, name: name ?? this.name, items: items ?? this.items);
}
