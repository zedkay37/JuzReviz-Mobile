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
    final playlistsAsync = ref.watch(playlistsControllerProvider);
    final playlists = playlistsAsync.valueOrNull;
    if (playlists == null) {
      return LanternScaffold(
        contentMaxWidth: 760,
        appBar: AppBar(title: const Text('Playlists')),
        body: playlistsAsync.hasError
            ? LanternEmpty(
                message: 'Impossible de charger les playlists.',
                action: TextButton.icon(
                  onPressed: () => ref.invalidate(playlistsControllerProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final t = context.lantern;
    return LanternScaffold(
      contentMaxWidth: 760,
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
                        onSelected: (v) async {
                          if (v == 'rename') {
                            await _renameDialog(context, ref, p.id, p.name);
                            return;
                          }
                          if (v == 'delete') {
                            final confirmed = await confirmDestructiveAction(
                              context,
                              title: 'Supprimer « ${p.name} » ?',
                              message:
                                  'Elle contient '
                                  '${passageCount(p.items.length).toLowerCase()}. '
                                  'Tes données de révision ne seront pas modifiées.',
                            );
                            if (!confirmed || !context.mounted) return;
                            await ref
                                .read(playlistsControllerProvider.notifier)
                                .delete(p.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Playlist supprimée.'),
                              ),
                            );
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
