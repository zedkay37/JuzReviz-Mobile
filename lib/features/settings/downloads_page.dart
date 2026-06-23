import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/audio_cache.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/usecase/juz_index.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';

String formatBytes(int b) {
  if (b <= 0) return '0 Mo';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} Ko';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
}

enum _Scope { surah, juz }

/// Gestionnaire de téléchargement audio (récitation offline) : sourate / juz / Coran.
class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  String? _reciter;
  _Scope _scope = _Scope.surah;

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
          metasAsync.when(
            loading: () => const Expanded(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Expanded(child: LanternEmpty(message: 'Erreur : $e')),
            data: (metas) => Expanded(
              child: Column(
                children: [
                  _QuranTile(reciter: reciter, metas: metas),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        LanternSpace.md, 0, LanternSpace.md, LanternSpace.sm),
                    child: SegmentedButton<_Scope>(
                      segments: const [
                        ButtonSegment(value: _Scope.surah, label: Text('Par sourate')),
                        ButtonSegment(value: _Scope.juz, label: Text('Par juz')),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (s) => setState(() => _scope = s.first),
                    ),
                  ),
                  Expanded(
                    child: _scope == _Scope.surah
                        ? ListView.builder(
                            itemCount: metas.length,
                            itemBuilder: (_, i) =>
                                _SurahRow(reciter: reciter, meta: metas[i]),
                          )
                        : ListView.builder(
                            itemCount: 30,
                            itemBuilder: (_, i) => _JuzRow(
                                reciter: reciter, juz: i + 1, metas: metas),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rangée d'action de téléchargement réutilisable.
class _DownloadTrailing extends StatelessWidget {
  const _DownloadTrailing({
    required this.active,
    required this.progress,
    required this.done,
    required this.busy,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    this.sizeLabel,
  });

  final bool active;
  final double progress;
  final bool done;
  final bool busy; // un autre téléchargement est en cours
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final String? sizeLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    if (active) {
      return Row(
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
          IconButton(icon: Icon(Icons.close, color: t.inkSoft), onPressed: onCancel),
        ],
      );
    }
    if (done) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sizeLabel != null)
            Text(sizeLabel!, style: TextStyle(color: t.inkSoft, fontSize: 12)),
          IconButton(
              icon: Icon(Icons.delete_outline, color: t.inkSoft),
              onPressed: onDelete),
        ],
      );
    }
    return IconButton(
      icon: Icon(Icons.download_outlined, color: busy ? t.inkFaint : t.accent),
      onPressed: busy ? null : onDownload,
    );
  }
}

class _QuranTile extends ConsumerWidget {
  const _QuranTile({required this.reciter, required this.metas});
  final String reciter;
  final List<SurahMeta> metas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final dl = ref.watch(downloadsControllerProvider);
    final done = ref.watch(quranDownloadStatusProvider(reciter)).valueOrNull ?? false;
    final ctrl = ref.read(downloadsControllerProvider.notifier);
    final keys = quranVerseKeys(metas);
    return Container(
      margin: const EdgeInsets.fromLTRB(
          LanternSpace.md, LanternSpace.sm, LanternSpace.md, LanternSpace.sm),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        border: Border.all(color: t.border),
      ),
      child: ListTile(
        leading: Icon(Icons.menu_book, color: t.accent),
        title: Text('Tout le Coran', style: TextStyle(color: t.ink)),
        subtitle: Text('${keys.length} versets',
            style: TextStyle(color: t.inkSoft, fontSize: 12)),
        trailing: _DownloadTrailing(
          active: dl.active == 'quran',
          progress: dl.progress,
          done: done,
          busy: dl.active != null && dl.active != 'quran',
          onDownload: () => ctrl.download(reciter, 'quran', keys),
          onCancel: ctrl.cancel,
          onDelete: () => ctrl.deleteKeys(reciter, keys),
        ),
      ),
    );
  }
}

class _JuzRow extends ConsumerWidget {
  const _JuzRow({required this.reciter, required this.juz, required this.metas});
  final String reciter;
  final int juz;
  final List<SurahMeta> metas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final dl = ref.watch(downloadsControllerProvider);
    final done = ref
            .watch(juzDownloadStatusProvider((reciter: reciter, juz: juz)))
            .valueOrNull ??
        false;
    final ctrl = ref.read(downloadsControllerProvider.notifier);
    final keys = juzVerseKeys(juz, metas);
    final id = 'j$juz';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.surfaceHigh,
        child: Text('$juz', style: TextStyle(color: t.accent, fontSize: 13)),
      ),
      title: Text('Juz $juz', style: TextStyle(color: t.ink)),
      subtitle: Text('${keys.length} versets',
          style: TextStyle(color: t.inkSoft, fontSize: 12)),
      trailing: _DownloadTrailing(
        active: dl.active == id,
        progress: dl.progress,
        done: done,
        busy: dl.active != null && dl.active != id,
        onDownload: () => ctrl.download(reciter, id, keys),
        onCancel: ctrl.cancel,
        onDelete: () => ctrl.deleteKeys(reciter, keys),
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
    final dl = ref.watch(downloadsControllerProvider);
    final status = ref
        .watch(surahDownloadStatusProvider((reciter: reciter, surah: meta.number)))
        .valueOrNull;
    final ctrl = ref.read(downloadsControllerProvider.notifier);
    final keys = surahVerseKeys(meta.number, meta.ayahCount);
    final id = 's${meta.number}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.surfaceHigh,
        child: Text('${meta.number}',
            style: TextStyle(color: t.accent, fontSize: 13)),
      ),
      title: Text(meta.transliteration, style: TextStyle(color: t.ink)),
      subtitle: Text('${meta.ayahCount} versets',
          style: TextStyle(color: t.inkSoft, fontSize: 12)),
      trailing: _DownloadTrailing(
        active: dl.active == id,
        progress: dl.progress,
        done: status?.done ?? false,
        busy: dl.active != null && dl.active != id,
        sizeLabel: (status?.bytes ?? 0) > 0 ? formatBytes(status!.bytes) : null,
        onDownload: () => ctrl.download(reciter, id, keys),
        onCancel: ctrl.cancel,
        onDelete: () => ctrl.deleteKeys(reciter, keys),
      ),
    );
  }
}
