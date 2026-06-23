import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';

String formatBytes(int b) {
  if (b <= 0) return '0 Mo';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} Ko';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

/// Gestionnaire de téléchargement audio (récitation offline).
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  String? _reciter;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final reciter = _reciter ?? settings.reciter;
    final metasAsync = ref.watch(surahMetasProvider);
    final total = ref.watch(totalCacheBytesProvider).valueOrNull ?? 0;

    return LanternScaffold(
      appBar: AppBar(title: const Text('Téléchargements')),
      body: Column(
        children: [
          ChoiceRow<String>(
            title: 'Récitateur',
            subtitle: 'La récitation hors-ligne dépend du récitateur choisi.',
            value: reciterById(reciter).id,
            options: [for (final r in reciters) (r.id, r.name)],
            onChanged: (v) => setState(() => _reciter = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LanternSpace.md, vertical: LanternSpace.sm),
            child: Row(
              children: [
                Icon(Icons.sd_storage_outlined, color: t.inkSoft, size: 18),
                const SizedBox(width: 8),
                Text('Cache audio : ${formatBytes(total)}',
                    style: TextStyle(color: t.inkSoft, fontSize: 13)),
                const Spacer(),
                if (total > 0)
                  TextButton(
                    onPressed: () =>
                        ref.read(downloadsControllerProvider.notifier).clearAll(),
                    child: const Text('Tout supprimer'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: metasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
              data: (metas) => ListView.builder(
                itemCount: metas.length,
                itemBuilder: (_, i) =>
                    _SurahRow(reciter: reciter, meta: metas[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends ConsumerWidget {
  const _SurahRow({required this.reciter, required this.meta});
  final String reciter;
  final SurahMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final downloads = ref.watch(downloadsControllerProvider);
    final status = ref
        .watch(surahDownloadStatusProvider((reciter: reciter, surah: meta.number)))
        .valueOrNull;
    final active = downloads.active == meta.number;
    final progress = downloads.progress[meta.number] ?? 0;
    final done = status?.done ?? false;
    final bytes = status?.bytes ?? 0;
    final ctrl = ref.read(downloadsControllerProvider.notifier);

    Widget trailing;
    if (active) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                value: progress == 0 ? null : progress,
                strokeWidth: 2.5,
                color: t.accent),
          ),
          const SizedBox(width: 4),
          Text('${(progress * 100).round()}%',
              style: TextStyle(color: t.inkSoft, fontSize: 12)),
          IconButton(
            icon: Icon(Icons.close, color: t.inkSoft),
            onPressed: ctrl.cancel,
          ),
        ],
      );
    } else if (done) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatBytes(bytes),
              style: TextStyle(color: t.inkSoft, fontSize: 12)),
          IconButton(
            icon: Icon(Icons.delete_outline, color: t.inkSoft),
            onPressed: () => ctrl.delete(reciter, meta.number),
          ),
        ],
      );
    } else {
      trailing = IconButton(
        icon: Icon(Icons.download_outlined, color: t.accent),
        onPressed: downloads.active != null
            ? null
            : () => ctrl.download(reciter, meta.number, meta.ayahCount),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.surfaceHigh,
        child: Text('${meta.number}',
            style: TextStyle(color: t.accent, fontSize: 13)),
      ),
      title: Text(meta.transliteration, style: TextStyle(color: t.ink)),
      subtitle: Text('${meta.ayahCount} versets',
          style: TextStyle(color: t.inkSoft, fontSize: 12)),
      trailing: trailing,
    );
  }
}
