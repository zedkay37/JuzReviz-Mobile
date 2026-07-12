import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';

/// Sélecteur de disposition du lecteur (façon « concurrent »).
class ReaderLayoutSheet extends ConsumerWidget {
  const ReaderLayoutSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final s =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final current = readerLayoutFromString(s.readerLayout);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    // Le pack de polices moushaf est téléchargeable à la demande.
    final mushafReady = ref.watch(mushafAvailableProvider).valueOrNull ?? false;
    final dlProgress = ref.watch(mushafDownloadProvider); // 0..1 ou null

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choisis ta disposition',
            style: TextStyle(
              color: t.ink,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: LanternSpace.md),
          for (final layout in ReaderLayout.values)
            Builder(
              builder: (context) {
                final isMushaf = !layout.available;
                final downloading = isMushaf && dlProgress != null;
                final needsDownload = isMushaf && !mushafReady && !downloading;
                final statusLabel = downloading
                    ? 'Téléchargement ${((dlProgress) * 100).round()}%'
                    : needsDownload
                    ? 'Télécharger ~90 Mo'
                    : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: LanternSpace.sm),
                  child: _LayoutCard(
                    layout: layout,
                    dim: downloading,
                    selected: current == layout,
                    statusLabel: statusLabel,
                    onTap: () async {
                      if (downloading) return;
                      if (needsDownload) {
                        HapticFeedback.selectionClick();
                        final outcome = await ref
                            .read(mushafDownloadProvider.notifier)
                            .download();
                        if (context.mounted &&
                            outcome == DownloadOutcome.failed) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Pack Mushaf indisponible. Vérifie la connexion '
                                'et l’espace libre, puis réessaie.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      HapticFeedback.selectionClick();
                      // Préréglage : Flexible = arabe seul, Verset = mot-à-mot +
                      // traduction (ajustables ensuite via le menu verset).
                      ctrl.edit((p) {
                        if (layout == ReaderLayout.flexible) {
                          return p.copyWith(
                            readerLayout: layout.id,
                            readerWordByWord: false,
                            readerTranslation: false,
                          );
                        }
                        if (layout == ReaderLayout.verseByVerse) {
                          return p.copyWith(
                            readerLayout: layout.id,
                            readerWordByWord: true,
                            readerTranslation: true,
                          );
                        }
                        return p.copyWith(readerLayout: layout.id);
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                );
              },
            ),
          const SizedBox(height: LanternSpace.sm),
          // Taille du texte arabe (Flexible / Verset par verset).
          Row(
            children: [
              Text('Aa', style: TextStyle(color: t.inkSoft, fontSize: 13)),
              Expanded(
                child: Slider(
                  value: s.fontScale.clamp(0.7, 1.8),
                  min: 0.7,
                  max: 1.8,
                  divisions: 11,
                  activeColor: t.accent,
                  label: '${(s.fontScale * 100).round()}%',
                  onChanged: (v) => ctrl.edit((p) => p.copyWith(fontScale: v)),
                ),
              ),
              Text('Aa', style: TextStyle(color: t.inkSoft, fontSize: 22)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.layout,
    required this.dim,
    required this.selected,
    required this.onTap,
    this.statusLabel,
  });
  final ReaderLayout layout;
  final bool dim;
  final bool selected;
  final VoidCallback onTap;
  final String? statusLabel;

  IconData get _icon => switch (layout) {
    ReaderLayout.mushaf => Icons.menu_book,
    ReaderLayout.flexible => Icons.text_fields,
    ReaderLayout.verseByVerse => Icons.auto_stories_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final enabled = !dim;
    final semanticValue = [layout.description, ?statusLabel].join('. ');
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      label: layout.label,
      value: semanticValue,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Container(
              padding: const EdgeInsets.all(LanternSpace.md),
              decoration: BoxDecoration(
                color: selected ? t.accent.withValues(alpha: 0.10) : t.surface,
                borderRadius: BorderRadius.circular(LanternSpace.radius),
                border: Border.all(
                  color: selected ? t.accent : t.border,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.surfaceHigh,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _icon,
                      color: dim
                          ? t.inkFaint
                          : (selected ? t.accent : t.inkSoft),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: LanternSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layout.label,
                          style: TextStyle(
                            color: dim ? t.inkSoft : t.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (statusLabel != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              statusLabel!,
                              style: TextStyle(
                                color: t.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          layout.description,
                          style: TextStyle(
                            color: t.inkSoft,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: t.accent, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showReaderLayout(BuildContext context) =>
    showLanternSheet<void>(context, builder: (_) => const ReaderLayoutSheet());
