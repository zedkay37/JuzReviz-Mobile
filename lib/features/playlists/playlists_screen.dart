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
      appBar: AppBar(title: const Text('Playlists')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: t.accent,
        foregroundColor: t.accentInk,
        onPressed: () => _createDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: playlists.isEmpty
          ? LanternEmpty(
              message:
                  'Crée une playlist pour regrouper tes passages de lecture ou de révision.',
              icon: Icons.queue_music,
              action: FilledButton.icon(
                onPressed: () => _createDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle playlist'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                LanternSpace.md,
                LanternSpace.md,
                LanternSpace.md,
                96,
              ),
              itemCount: playlists.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: LanternSpace.sm),
              itemBuilder: (context, i) {
                final p = playlists[i];
                return Material(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(LanternSpace.radius),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(LanternSpace.radius),
                      border: Border.all(color: t.border),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.only(
                        left: LanternSpace.md,
                        right: LanternSpace.sm,
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.ink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        passageCount(p.items.length),
                        style: TextStyle(color: t.inkSoft),
                      ),
                      trailing: PopupMenuButton<String>(
                        color: t.surfaceHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: t.border),
                        ),
                        icon: Icon(Icons.more_vert, color: t.inkSoft),
                        onSelected: (v) {
                          if (v == 'rename') {
                            _renameDialog(context, ref, p.id, p.name);
                          }
                          if (v == 'delete') {
                            ref
                                .read(playlistsControllerProvider.notifier)
                                .delete(p.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Renommer'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Supprimer'),
                          ),
                        ],
                      ),
                      onTap: () => context.push('/playlists/${p.id}'),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = await promptText(
      context,
      title: 'Nouvelle playlist',
      hint: 'Nom de la playlist',
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(playlistsControllerProvider.notifier).create(name.trim());
    }
  }

  Future<void> _renameDialog(
    BuildContext context,
    WidgetRef ref,
    String id,
    String current,
  ) async {
    final name = await promptText(context, title: 'Renommer', initial: current);
    if (name != null && name.trim().isNotEmpty) {
      await ref
          .read(playlistsControllerProvider.notifier)
          .rename(id, name.trim());
    }
  }
}
