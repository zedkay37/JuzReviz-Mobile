import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/plural.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/selection.dart';

/// Sous-sheet « Ajouter à une playlist » : reste dans le contexte courant,
/// toggle d'appartenance immédiat, création inline en un geste.
class AddToPlaylistSheet extends ConsumerStatefulWidget {
  const AddToPlaylistSheet({super.key, required this.selection});
  final Selection selection;

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  final _newCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      await ref.read(playlistsControllerProvider.future);
      await ref
          .read(playlistsControllerProvider.notifier)
          .createWithPassage(name, widget.selection);
      HapticFeedback.selectionClick();
      _newCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer la playlist.')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final playlistsAsync = ref.watch(playlistsControllerProvider);
    final playlists = playlistsAsync.valueOrNull;
    if (playlists == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajouter à une playlist',
            style: TextStyle(
              color: t.ink,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: LanternSpace.md),
          if (playlistsAsync.hasError)
            Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(playlistsControllerProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer le chargement'),
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Ajouter à une playlist',
          style: TextStyle(
            color: t.ink,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: LanternSpace.md),
        // Création inline : nom + ajout en un geste.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newCtrl,
                style: TextStyle(color: t.ink),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
                decoration: InputDecoration(
                  hintText: 'Nouvelle playlist',
                  hintStyle: TextStyle(color: t.inkFaint),
                  filled: true,
                  fillColor: t.surfaceHigh,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: LanternSpace.sm),
            IconButton(
              tooltip: 'Créer la playlist',
              onPressed: _creating ? null : _create,
              icon: Icon(Icons.add_circle, color: t.accent),
            ),
          ],
        ),
        const SizedBox(height: LanternSpace.sm),
        if (playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: LanternSpace.md),
            child: Text(
              'Aucune playlist pour l’instant.',
              style: TextStyle(color: t.inkSoft, fontSize: 13),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length,
              itemBuilder: (_, i) {
                final p = playlists[i];
                final inIt = playlistHasPassage(p, widget.selection);
                return ListTile(
                  selected: inIt,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    inIt ? Icons.check_circle : Icons.circle_outlined,
                    color: inIt ? t.accent : t.inkSoft,
                  ),
                  title: Text(p.name, style: TextStyle(color: t.ink)),
                  subtitle: Text(
                    passageCount(p.items.length),
                    style: TextStyle(color: t.inkSoft, fontSize: 12),
                  ),
                  onTap: () async {
                    await ref
                        .read(playlistsControllerProvider.notifier)
                        .togglePassage(p.id, widget.selection);
                    HapticFeedback.selectionClick();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          inIt ? 'Retiré de ${p.name}' : 'Ajouté à ${p.name}',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Ouvre le sous-sheet d'ajout playlist au-dessus du contexte courant.
Future<void> showAddToPlaylist(BuildContext context, Selection selection) {
  return showLanternSheet<void>(
    context,
    builder: (_) => AddToPlaylistSheet(selection: selection),
  );
}
