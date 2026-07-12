import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/add_to_playlist_sheet.dart';
import 'package:juzreviz/core/designsystem/components/heat_widgets.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/verse_action_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/selection.dart';

class SurahDrillScreen extends ConsumerWidget {
  const SurahDrillScreen({super.key, required this.surah});
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metasAsync = ref.watch(surahMetasProvider);
    final masteryAsync = ref.watch(masteryControllerProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final mastery = masteryAsync.valueOrNull;
    final settings = settingsAsync.valueOrNull;
    final now = ref.read(clockProvider).nowMs();
    final name = metasAsync.valueOrNull
        ?.where((m) => m.number == surah)
        .firstOrNull
        ?.transliteration;

    return LanternScaffold(
      appBar: AppBar(
        title: Text(name ?? 'Sourate $surah'),
        actions: [
          IconButton(
            tooltip: 'Lire',
            icon: const Icon(Icons.menu_book),
            onPressed: name == null ? null : () => _open(context, ref),
          ),
          IconButton(
            tooltip: 'Ajouter à une playlist',
            icon: const Icon(Icons.playlist_add),
            onPressed: name == null ? null : () => _addToPlaylist(context, ref),
          ),
        ],
      ),
      body: mastery == null || settings == null
          ? masteryAsync.hasError || settingsAsync.hasError
                ? LanternEmpty(
                    message: 'Impossible de charger ta progression.',
                    action: OutlinedButton.icon(
                      onPressed: () {
                        ref
                          ..invalidate(masteryControllerProvider)
                          ..invalidate(settingsControllerProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  )
                : const Center(child: CircularProgressIndicator())
          : metasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => LanternEmpty(
                message:
                    'Impossible de charger cette sourate. Réessaie dans un instant.',
                action: OutlinedButton.icon(
                  onPressed: () => ref.invalidate(surahMetasProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ),
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
                    final f = mastery.fragile[key];
                    final m = mastery.mastered[key];
                    final state = verseHeatState(
                      f,
                      m,
                      settings.masteryProfile,
                      now,
                    );
                    final scarred =
                        hasImplicitScar(f, m) || mastery.scarred.contains(key);
                    return HeatCell(
                      ayah: ayah,
                      state: state,
                      scarred: scarred,
                      onTap: () => context.push(
                        '/read',
                        extra: SelSurah(surah, ayah, meta.ayahCount),
                      ),
                      onLongPress: () =>
                          _capture(context, ref, key, ayah, meta.ayahCount),
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
    await showAddToPlaylist(context, SelSurah(surah, 1, count));
  }

  Future<void> _capture(
    BuildContext context,
    WidgetRef ref,
    String key,
    int ayah,
    int count,
  ) async {
    await showVerseActions(
      context,
      verseKey: key,
      onPlayFrom: () =>
          context.push('/read', extra: SelSurah(surah, ayah, count)),
    );
  }
}
