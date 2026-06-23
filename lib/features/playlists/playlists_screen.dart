import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/plural.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/prompt_dialog.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final playlists = ref.watch(playlistsControllerProvider).valueOrNull ?? [];
    return LanternScaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            tooltip: 'Playlist vide',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _createDialog(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.accent,
        foregroundColor: t.accentInk,
        onPressed: () => context.push('/compose'),
        icon: const Icon(Icons.library_add),
        label: const Text('Composer'),
      ),
      body: playlists.isEmpty
          ? const LanternEmpty(
              message: 'Aucune playlist. Compose tes passages favoris.',
              icon: Icons.queue_music)
          : ListView.separated(
              padding: const EdgeInsets.all(LanternSpace.md),
              itemCount: playlists.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = playlists[i];
                return Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(LanternSpace.radius),
                    border: Border.all(color: t.border),
                  ),
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text(passageCount(p.items.length),
                        style: TextStyle(color: t.inkSoft)),
                    trailing: PopupMenuButton<String>(
                      color: t.surfaceHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: t.border),
                      ),
                      icon: Icon(Icons.more_vert, color: t.inkSoft),
                      onSelected: (v) {
                        if (v == 'rename') _renameDialog(context, ref, p.id, p.name);
                        if (v == 'delete') {
                          ref.read(playlistsControllerProvider.notifier).delete(p.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Renommer')),
                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                    onTap: () => context.push('/playlists/${p.id}'),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = await promptText(context,
        title: 'Nouvelle playlist', hint: 'Nom de la playlist');
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(playlistsControllerProvider.notifier).create(name.trim());
    }
  }

  Future<void> _renameDialog(
      BuildContext context, WidgetRef ref, String id, String current) async {
    final name = await promptText(context, title: 'Renommer', initial: current);
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(playlistsControllerProvider.notifier).rename(id, name.trim());
    }
  }
}
