import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/capture_bar.dart';
import 'package:juzreviz/core/designsystem/components/heat_widgets.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/tafsir/tafsir_panel.dart';

class SurahDrillScreen extends ConsumerWidget {
  const SurahDrillScreen({super.key, required this.surah});
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(surahMetasProvider);
    final mastery = ref.watch(masteryControllerProvider).valueOrNull;
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final now = ref.read(clockProvider).nowMs();

    return LanternScaffold(
      appBar: AppBar(
        title: Text('Sourate $surah'),
        actions: [
          IconButton(
            tooltip: 'Lire',
            icon: const Icon(Icons.menu_book),
            onPressed: () => _open(context, ref),
          ),
          IconButton(
            tooltip: 'Ajouter à une playlist',
            icon: const Icon(Icons.playlist_add),
            onPressed: () => _addToPlaylist(context, ref),
          ),
        ],
      ),
      body: metasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
        data: (metas) {
          final meta = metas.firstWhere((m) => m.number == surah);
          return GridView.builder(
            padding: const EdgeInsets.all(LanternSpace.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 56,
              childAspectRatio: 1,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: meta.ayahCount,
            itemBuilder: (context, i) {
              final ayah = i + 1;
              final key = '$surah:$ayah';
              final f = mastery?.fragile[key];
              final m = mastery?.mastered[key];
              final state =
                  verseHeatState(f, m, settings.masteryProfile, now);
              final flag = verseFlag(f, m);
              return HeatCell(
                ayah: ayah,
                state: state,
                scarred: flag.scarred,
                onTap: () => context.push('/read',
                    extra: SelSurah(surah, ayah, meta.ayahCount)),
                onLongPress: () => _capture(context, ref, key),
              );
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    final metas = ref.read(surahMetasProvider).valueOrNull;
    final count = metas?.firstWhere((m) => m.number == surah).ayahCount ?? 1;
    context.push('/read', extra: SelSurah(surah, 1, count));
  }

  Future<void> _addToPlaylist(BuildContext context, WidgetRef ref) async {
    final metas = ref.read(surahMetasProvider).valueOrNull;
    final count = metas?.firstWhere((m) => m.number == surah).ayahCount ?? 1;
    final playlists = ref.read(playlistsControllerProvider).valueOrNull ?? [];
    await showLanternSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Crée d’abord une playlist dans l’onglet Playlists.'),
            ),
          for (final p in playlists)
            ListTile(
              title: Text(p.name),
              onTap: () {
                ref
                    .read(playlistsControllerProvider.notifier)
                    .addItem(p.id, SelSurah(surah, 1, count));
                Navigator.of(ctx).pop();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _capture(BuildContext context, WidgetRef ref, String key) async {
    await showLanternSheet<void>(
      context,
      builder: (ctx) => CaptureBar(
        verseKey: key,
        onFragile: () {
          ref.read(masteryControllerProvider.notifier).markFragile(key);
          Navigator.of(ctx).pop();
        },
        onMastered: () {
          ref.read(masteryControllerProvider.notifier).markMastered(key);
          Navigator.of(ctx).pop();
        },
        onTafsir: () {
          Navigator.of(ctx).pop();
          showTafsir(context, ref, key);
        },
      ),
    );
  }
}
