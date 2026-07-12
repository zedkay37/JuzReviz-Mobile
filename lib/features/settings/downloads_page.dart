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

Future<void> showDownloadOutcome(
  BuildContext context,
  Future<DownloadOutcome> operation,
) async {
  final outcome = await operation;
  if (!context.mounted || outcome != DownloadOutcome.failed) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Téléchargement interrompu. Vérifie la connexion et l’espace libre, '
        'puis réessaie.',
      ),
    ),
  );
}

Future<bool> _confirmDelete(BuildContext context, String what) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Supprimer $what de cet appareil ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    ) ??
    false;

Future<bool> _confirmQuranDownload(
  BuildContext context,
  int verseCount,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Télécharger tout le Coran ?'),
        content: Text(
          '$verseCount fichiers audio seront téléchargés. Selon le récitateur, '
          'cela représente plusieurs centaines de Mo et peut dépasser 1 Go.\n\n'
          'Utilise de préférence le Wi-Fi et vérifie l’espace libre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Télécharger'),
          ),
        ],
      ),
    ) ??
    false;

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
    final downloads = ref.watch(downloadsControllerProvider);
    final metas = metasAsync.valueOrNull;

    return LanternScaffold(
      contentMaxWidth: 840,
      appBar: AppBar(title: const Text('Téléchargements')),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _MushafPackTile()),
          SliverToBoxAdapter(
            child: ChoiceRow<String>(
              title: 'Récitateur',
              subtitle: 'La récitation hors-ligne dépend du récitateur choisi.',
              value: reciterById(reciter).id,
              options: [for (final r in reciters) (r.id, r.name)],
              onChanged: (v) => setState(() => _reciter = v),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: LanternSpace.md,
                vertical: LanternSpace.sm,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: LanternSpace.md,
                runSpacing: LanternSpace.xs,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sd_storage_outlined,
                        color: t.inkSoft,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cache audio : ${formatBytes(total)}',
                        style: TextStyle(color: t.inkSoft, fontSize: 13),
                      ),
                    ],
                  ),
                  if (total > 0)
                    TextButton(
                      onPressed: downloads.active != null
                          ? null
                          : () async {
                              if (!await _confirmDelete(
                                context,
                                'tout le cache audio',
                              )) {
                                return;
                              }
                              await ref
                                  .read(downloadsControllerProvider.notifier)
                                  .clearAll();
                            },
                      child: const Text('Tout supprimer'),
                    ),
                ],
              ),
            ),
          ),
          if (metas == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: metasAsync.hasError
                  ? LanternEmpty(
                      message: 'Impossible de charger les téléchargements.',
                      action: TextButton.icon(
                        onPressed: () => ref.invalidate(surahMetasProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          if (metas != null) ...[
            SliverToBoxAdapter(
              child: _QuranTile(reciter: reciter, metas: metas),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  LanternSpace.md,
                  0,
                  LanternSpace.md,
                  LanternSpace.sm,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_Scope>(
                    segments: const [
                      ButtonSegment(
                        value: _Scope.surah,
                        label: Text('Par sourate'),
                      ),
                      ButtonSegment(value: _Scope.juz, label: Text('Par juz')),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (s) => setState(() => _scope = s.first),
                  ),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: _scope == _Scope.surah ? metas.length : 30,
              itemBuilder: (_, i) => _scope == _Scope.surah
                  ? _SurahRow(reciter: reciter, meta: metas[i])
                  : _JuzRow(reciter: reciter, juz: i + 1, metas: metas),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: LanternSpace.lg)),
          ],
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
    required this.subject,
    this.sizeLabel,
    this.loading = false,
    this.failed = false,
    this.onRetry,
  });

  final bool active;
  final double progress;
  final bool done;
  final bool busy; // un autre téléchargement est en cours
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;
  final String subject;
  final String? sizeLabel;
  final bool loading;
  final bool failed;
  final VoidCallback? onRetry;

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
              semanticsLabel: 'Téléchargement de $subject',
              strokeWidth: 2.5,
              color: t.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(color: t.inkSoft, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Annuler le téléchargement de $subject',
            icon: Icon(Icons.close, color: t.inkSoft),
            onPressed: onCancel,
          ),
        ],
      );
    }
    if (loading) {
      return Semantics(
        label: 'Vérification de $subject',
        child: const SizedBox.square(
          dimension: 48,
          child: Padding(
            padding: EdgeInsets.all(13),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    if (failed) {
      return IconButton(
        tooltip: 'Revérifier $subject',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      );
    }
    if (done) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sizeLabel != null)
            Text(sizeLabel!, style: TextStyle(color: t.inkSoft, fontSize: 12)),
          IconButton(
            tooltip: 'Supprimer $subject',
            icon: Icon(Icons.delete_outline, color: t.inkSoft),
            onPressed: onDelete,
          ),
        ],
      );
    }
    return IconButton(
      tooltip: 'Télécharger $subject',
      icon: Icon(Icons.download_outlined, color: busy ? t.inkFaint : t.accent),
      onPressed: busy ? null : onDownload,
    );
  }
}

/// Gestion du pack moushaf (polices QCF) : lecture façon mushaf hors-ligne.
class _MushafPackTile extends ConsumerWidget {
  const _MushafPackTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final availableAsync = ref.watch(mushafAvailableProvider);
    final downloaded = availableAsync.valueOrNull;
    final progress = ref.watch(mushafDownloadProvider); // 0..1 ou null
    final bytes = ref.watch(mushafCacheBytesProvider).valueOrNull ?? 0;
    final ctrl = ref.read(mushafDownloadProvider.notifier);

    Widget trailing;
    if (progress != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: progress == 0 ? null : progress,
              strokeWidth: 2.5,
              color: t.accent,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(color: t.inkSoft, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Annuler le téléchargement du pack Mushaf',
            icon: Icon(Icons.close, color: t.inkSoft),
            onPressed: ctrl.cancel,
          ),
        ],
      );
    } else if (downloaded == null) {
      trailing = availableAsync.hasError
          ? IconButton(
              tooltip: 'Revérifier le pack Mushaf',
              onPressed: () {
                ref
                  ..invalidate(mushafAvailableProvider)
                  ..invalidate(mushafCacheBytesProvider);
              },
              icon: const Icon(Icons.refresh),
            )
          : const SizedBox.square(
              dimension: 48,
              child: Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            );
    } else if (downloaded) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatBytes(bytes),
            style: TextStyle(color: t.inkSoft, fontSize: 12),
          ),
          IconButton(
            tooltip: 'Supprimer le pack Mushaf',
            icon: Icon(Icons.delete_outline, color: t.inkSoft),
            onPressed: () async {
              if (await _confirmDelete(context, 'le pack Mushaf')) {
                await ctrl.delete();
              }
            },
          ),
        ],
      );
    } else {
      trailing = IconButton(
        tooltip: 'Télécharger le pack Mushaf',
        icon: Icon(Icons.download_outlined, color: t.accent),
        onPressed: () => showDownloadOutcome(context, ctrl.download()),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(
        LanternSpace.md,
        LanternSpace.md,
        LanternSpace.md,
        LanternSpace.sm,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        border: Border.all(color: t.border),
      ),
      child: ListTile(
        leading: Icon(Icons.auto_stories, color: t.accent),
        title: Text(
          'Pack Mushaf (lecture moushaf)',
          style: TextStyle(color: t.ink),
        ),
        subtitle: Text(
          'Polices QCF · ~90 Mo · active les dispositions Mushaf',
          style: TextStyle(color: t.inkSoft, fontSize: 12),
        ),
        trailing: trailing,
      ),
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
    final statusAsync = ref.watch(quranDownloadStatusProvider(reciter));
    final ctrl = ref.read(downloadsControllerProvider.notifier);
    final keys = quranVerseKeys(metas);
    return Container(
      margin: const EdgeInsets.fromLTRB(
        LanternSpace.md,
        LanternSpace.sm,
        LanternSpace.md,
        LanternSpace.sm,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        border: Border.all(color: t.border),
      ),
      child: ListTile(
        leading: Icon(Icons.menu_book, color: t.accent),
        title: Text('Tout le Coran', style: TextStyle(color: t.ink)),
        subtitle: Text(
          '${keys.length} versets',
          style: TextStyle(color: t.inkSoft, fontSize: 12),
        ),
        trailing: _DownloadTrailing(
          subject: 'tout le Coran',
          active: dl.active == 'quran',
          progress: dl.progress,
          done: statusAsync.valueOrNull ?? false,
          loading: !statusAsync.hasValue && !statusAsync.hasError,
          failed: statusAsync.hasError,
          onRetry: () => ref.invalidate(quranDownloadStatusProvider(reciter)),
          busy: dl.active != null && dl.active != 'quran',
          onDownload: () async {
            if (!await _confirmQuranDownload(context, keys.length) ||
                !context.mounted) {
              return;
            }
            await showDownloadOutcome(
              context,
              ctrl.download(reciter, 'quran', keys),
            );
          },
          onCancel: ctrl.cancel,
          onDelete: () async {
            if (await _confirmDelete(context, 'tout l’audio du Coran')) {
              await ctrl.deleteKeys(reciter, keys);
            }
          },
        ),
      ),
    );
  }
}

class _JuzRow extends ConsumerWidget {
  const _JuzRow({
    required this.reciter,
    required this.juz,
    required this.metas,
  });
  final String reciter;
  final int juz;
  final List<SurahMeta> metas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final dl = ref.watch(downloadsControllerProvider);
    final statusArg = (reciter: reciter, juz: juz);
    final statusAsync = ref.watch(juzDownloadStatusProvider(statusArg));
    final ctrl = ref.read(downloadsControllerProvider.notifier);
    final keys = juzVerseKeys(juz, metas);
    final id = 'j$juz';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.surfaceHigh,
        child: Text('$juz', style: TextStyle(color: t.accent, fontSize: 13)),
      ),
      title: Text('Juz $juz', style: TextStyle(color: t.ink)),
      subtitle: Text(
        '${keys.length} versets',
        style: TextStyle(color: t.inkSoft, fontSize: 12),
      ),
      trailing: _DownloadTrailing(
        subject: 'Juz $juz',
        active: dl.active == id,
        progress: dl.progress,
        done: statusAsync.valueOrNull ?? false,
        loading: !statusAsync.hasValue && !statusAsync.hasError,
        failed: statusAsync.hasError,
        onRetry: () => ref.invalidate(juzDownloadStatusProvider(statusArg)),
        busy: dl.active != null && dl.active != id,
        onDownload: () =>
            showDownloadOutcome(context, ctrl.download(reciter, id, keys)),
        onCancel: ctrl.cancel,
        onDelete: () async {
          if (await _confirmDelete(context, 'l’audio du juz $juz')) {
            await ctrl.deleteKeys(reciter, keys);
          }
        },
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
    final statusArg = (reciter: reciter, surah: meta.number);
    final statusAsync = ref.watch(surahDownloadStatusProvider(statusArg));
    final status = statusAsync.valueOrNull;
    final ctrl = ref.read(downloadsControllerProvider.notifier);
    final keys = surahVerseKeys(meta.number, meta.ayahCount);
    final id = 's${meta.number}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: t.surfaceHigh,
        child: Text(
          '${meta.number}',
          style: TextStyle(color: t.accent, fontSize: 13),
        ),
      ),
      title: Text(meta.transliteration, style: TextStyle(color: t.ink)),
      subtitle: Text(
        '${meta.ayahCount} versets',
        style: TextStyle(color: t.inkSoft, fontSize: 12),
      ),
      trailing: _DownloadTrailing(
        subject: meta.transliteration,
        active: dl.active == id,
        progress: dl.progress,
        done: status?.done ?? false,
        loading: !statusAsync.hasValue && !statusAsync.hasError,
        failed: statusAsync.hasError,
        onRetry: () => ref.invalidate(surahDownloadStatusProvider(statusArg)),
        busy: dl.active != null && dl.active != id,
        sizeLabel: (status?.bytes ?? 0) > 0 ? formatBytes(status!.bytes) : null,
        onDownload: () =>
            showDownloadOutcome(context, ctrl.download(reciter, id, keys)),
        onCancel: ctrl.cancel,
        onDelete: () async {
          if (await _confirmDelete(
            context,
            'l’audio de ${meta.transliteration}',
          )) {
            await ctrl.deleteKeys(reciter, keys);
          }
        },
      ),
    );
  }
}
