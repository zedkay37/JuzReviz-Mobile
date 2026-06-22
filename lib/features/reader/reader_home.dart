import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/reader/reader_screen.dart';

/// Onglet « Lire » : reprend là où on s'est arrêté (`currentVerseKey`).
class ReaderHome extends ConsumerWidget {
  const ReaderHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final metasAsync = ref.watch(surahMetasProvider);
    return metasAsync.when(
      loading: () =>
          const LanternScaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => LanternScaffold(body: LanternEmpty(message: 'Erreur : $e')),
      data: (metas) {
        final surah = int.tryParse(s.currentVerseKey.split(':').first) ?? 1;
        final meta = metas.where((m) => m.number == surah).firstOrNull;
        final count = meta?.ayahCount ?? 7;
        return ReaderScreen(selection: SelSurah(surah, 1, count));
      },
    );
  }
}
