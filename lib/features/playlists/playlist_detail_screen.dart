import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/data/playlists/playlist.dart';
import 'package:juzreviz/domain/model/selection.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsControllerProvider);
    final playlists = playlistsAsync.valueOrNull;
    if (playlists == null) {
      return LanternScaffold(
        contentMaxWidth: 760,
        appBar: AppBar(title: const Text('Playlist')),
        body: playlistsAsync.hasError
            ? LanternEmpty(
                message: 'Impossible de charger cette playlist.',
                action: TextButton.icon(
                  onPressed: () => ref.invalidate(playlistsControllerProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final p = playlists.where((x) => x.id == playlistId).firstOrNull;
    if (p == null) {
      return LanternScaffold(
        contentMaxWidth: 760,
        appBar: AppBar(title: const Text('Playlist')),
        body: LanternEmpty(
          message: 'Cette playlist n’existe plus.',
          action: FilledButton.icon(
            onPressed: () => context.go('/playlists'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Revenir aux playlists'),
          ),
        ),
      );
    }
    return LanternScaffold(
      contentMaxWidth: 760,
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: 'Réciter (auto-avance)',
            icon: const Icon(Icons.graphic_eq),
            onPressed: p.items.isEmpty ? null : () => _playAll(context, ref, p),
          ),
        ],
      ),
      body: p.items.isEmpty
          ? LanternEmpty(
              message:
                  'Cette playlist est vide. Appuie longuement sur un verset pour l’ajouter, ou parcours l’Atlas.',
              icon: Icons.playlist_add,
              action: FilledButton.icon(
                onPressed: () => context.go('/coran'),
                icon: const Icon(Icons.grid_view),
                label: const Text('Ajouter des passages'),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: p.items.length,
              onReorder: (o, n) => ref
                  .read(playlistsControllerProvider.notifier)
                  .reorderItems(p.id, o, n),
              itemBuilder: (context, i) {
                final item = p.items[i];
                return ListTile(
                  key: ValueKey(item.id),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(item.label),
                  subtitle: Text(item.selection.label),
                  trailing: IconButton(
                    tooltip: 'Retirer ${item.label}',
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeWithUndo(context, ref, p, item, i),
                  ),
                  onTap: () => context.push('/read', extra: item.selection),
                );
              },
            ),
    );
  }

  Future<void> _removeWithUndo(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
    PlaylistItem item,
    int index,
  ) async {
    final controller = ref.read(playlistsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await controller.removeItem(playlist.id, item.id);
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('« ${item.label} » retiré de la playlist.'),
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () {
              controller.restoreItem(playlist.id, item, index);
            },
          ),
        ),
      );
  }

  Future<void> _playAll(BuildContext context, WidgetRef ref, Playlist p) async {
    final corpus = ref.read(corpusRepositoryProvider);
    final keys = <String>[];
    for (final item in p.items) {
      final verses = await corpus.versesForSelection(item.selection);
      keys.addAll(verses.map((v) => v.verseKey));
    }
    if (!context.mounted) return;
    context.push('/recite', extra: SelReview(p.name, keys));
  }
}
