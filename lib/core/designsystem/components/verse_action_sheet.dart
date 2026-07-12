import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/add_to_playlist_sheet.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/features/tafsir/tafsir_panel.dart';

/// Menu d'actions verset unifié (appui long), identique sur toutes les surfaces.
/// Représente une plage si [rangeEnd] est fourni.
class VerseActionSheet extends ConsumerWidget {
  const VerseActionSheet({
    super.key,
    required this.verseKey,
    this.rangeEnd,
    this.arabicPreview,
    this.reference,
    this.onPlaySingle,
    this.onPlayFrom,
    this.onRepeat,
    this.onStop,
    this.onSelectRange,
    this.showDisplay = false,
  });

  final String verseKey;
  final String? rangeEnd; // null = verset unique
  final String? arabicPreview;
  final String? reference;
  final VoidCallback? onPlaySingle;
  final VoidCallback? onPlayFrom;
  final VoidCallback? onRepeat;
  final VoidCallback? onStop;
  final VoidCallback? onSelectRange;

  /// Affiche les bascules d'affichage (mot-à-mot / traduction) — Reader seul.
  final bool showDisplay;

  bool get _isRange => rangeEnd != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final mastery = ref.watch(masteryControllerProvider).valueOrNull;
    final manualScar = mastery?.scarred.contains(verseKey) ?? false;
    final implicitScar = mastery == null
        ? false
        : hasImplicitScar(
            mastery.fragile[verseKey],
            mastery.mastered[verseKey],
          );
    final scarred = manualScar || implicitScar;
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final sctrl = ref.read(settingsControllerProvider.notifier);

    void close() => Navigator.of(context).pop();

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: LanternSpace.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : aperçu + référence.
          if (arabicPreview != null)
            Text(
              arabicPreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                color: t.ink,
                fontSize: 20,
                fontFamily: t.arabicFamily,
              ),
            ),
          Text(
            reference ?? (_isRange ? '$verseKey – $rangeEnd' : verseKey),
            style: TextStyle(color: t.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: LanternSpace.sm),

          if (showDisplay) ...[
            _SectionLabel('Affichage'),
            _ToggleRow(
              icon: Icons.translate,
              label: 'Mot à mot',
              value: settings.readerWordByWord,
              onChanged: (v) =>
                  sctrl.edit((p) => p.copyWith(readerWordByWord: v)),
            ),
            _ToggleRow(
              icon: Icons.subtitles_outlined,
              label: 'Traduction',
              value: settings.readerTranslation,
              onChanged: (v) =>
                  sctrl.edit((p) => p.copyWith(readerTranslation: v)),
            ),
          ],

          if (onSelectRange != null && !_isRange)
            _ActionRow(
              icon: Icons.expand,
              label: 'Sélectionner jusqu’à…',
              accent: true,
              onTap: () {
                close();
                onSelectRange!();
              },
            ),

          _SectionLabel('Mémorisation'),
          _ActionRow(
            icon: Icons.bolt,
            label: _isRange ? 'Marquer la plage fragile' : 'Marquer fragile',
            color: t.fragile,
            onTap: () async {
              HapticFeedback.mediumImpact();
              close();
              await ref
                  .read(masteryControllerProvider.notifier)
                  .markFragileMany(_keys());
            },
          ),
          _ActionRow(
            icon: Icons.spa,
            label: _isRange ? 'Marquer la plage maîtrisée' : 'Marquer maîtrisé',
            color: t.fresh,
            onTap: () async {
              HapticFeedback.lightImpact();
              close();
              await ref
                  .read(masteryControllerProvider.notifier)
                  .markMasteredMany(_keys());
            },
          ),
          if (!_isRange)
            _ActionRow(
              icon: scarred ? Icons.healing : Icons.healing_outlined,
              label: 'Cicatrice',
              color: t.scar,
              trailing: scarred
                  ? Icon(Icons.check, color: t.accent, size: 18)
                  : null,
              onTap: () {
                ref
                    .read(masteryControllerProvider.notifier)
                    .toggleScar(verseKey);
                HapticFeedback.selectionClick();
                close();
              },
            ),
          if (!_isRange && mastery?.fragile.containsKey(verseKey) == true)
            _ActionRow(
              icon: Icons.undo,
              label: 'Effacer la difficulté',
              onTap: () async {
                await ref
                    .read(masteryControllerProvider.notifier)
                    .clearDifficulty(verseKey);
                if (context.mounted) close();
              },
            ),
          if (!_isRange &&
              mastery != null &&
              (mastery.fragile.containsKey(verseKey) ||
                  mastery.mastered.containsKey(verseKey) ||
                  mastery.scarred.contains(verseKey)))
            _ActionRow(
              icon: Icons.restart_alt,
              label: 'Réinitialiser ce verset…',
              color: t.fragile,
              onTap: () async {
                final confirmed =
                    await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Réinitialiser ce verset ?'),
                        content: const Text(
                          'La difficulté, la maîtrise et la cicatrice seront '
                          'effacées pour ce verset.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Réinitialiser'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (!confirmed) return;
                await ref
                    .read(masteryControllerProvider.notifier)
                    .resetVerse(verseKey);
                if (context.mounted) close();
              },
            ),

          _SectionLabel('Organiser'),
          _ActionRow(
            icon: Icons.playlist_add,
            label: 'Ajouter à une playlist…',
            onTap: () {
              close();
              showAddToPlaylist(context, passageSelection(verseKey, rangeEnd));
            },
          ),
          if (!_isRange)
            _ActionRow(
              icon: Icons.menu_book,
              label: 'Lire le tafsir',
              onTap: () {
                close();
                showTafsir(context, ref, verseKey);
              },
            ),

          if (onPlaySingle != null ||
              onPlayFrom != null ||
              onRepeat != null ||
              onStop != null) ...[
            _SectionLabel('Écouter'),
            if (onPlaySingle != null && !_isRange)
              _ActionRow(
                icon: Icons.volume_up_outlined,
                label: 'Lire cette âyah',
                onTap: () {
                  close();
                  onPlaySingle!();
                },
              ),
            if (onPlayFrom != null)
              _ActionRow(
                icon: Icons.play_arrow,
                label: _isRange ? 'Lire la plage' : 'Lire à partir d’ici',
                onTap: () {
                  close();
                  onPlayFrom!();
                },
              ),
            if (onRepeat != null)
              _ActionRow(
                icon: Icons.repeat,
                label: _isRange ? 'Répéter la plage' : 'Répéter ce passage',
                onTap: () {
                  close();
                  onRepeat!();
                },
              ),
            if (onStop != null)
              _ActionRow(
                icon: Icons.stop_circle_outlined,
                label: 'Arrêter la lecture',
                color: t.fragile,
                onTap: () {
                  close();
                  onStop!();
                },
              ),
          ],
        ],
      ),
    );
  }

  List<String> _keys() {
    if (!_isRange) return [verseKey];
    final surah = int.parse(verseKey.split(':')[0]);
    final from = int.parse(verseKey.split(':')[1]);
    final to = int.parse(rangeEnd!.split(':')[1]);
    return [for (var a = from; a <= to; a++) '$surah:$a'];
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: t.inkSoft, size: 21),
          const SizedBox(width: LanternSpace.md),
          Expanded(
            child: Text(label, style: TextStyle(color: t.ink, fontSize: 15)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: t.inkFaint,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final fg = accent ? t.accent : t.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                icon,
                color: color ?? (accent ? t.accent : t.inkSoft),
                size: 21,
              ),
              const SizedBox(width: LanternSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: accent ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Ouvre le menu d'actions verset unifié.
Future<void> showVerseActions(
  BuildContext context, {
  required String verseKey,
  String? rangeEnd,
  String? arabicPreview,
  String? reference,
  VoidCallback? onPlaySingle,
  VoidCallback? onPlayFrom,
  VoidCallback? onRepeat,
  VoidCallback? onStop,
  VoidCallback? onSelectRange,
  bool showDisplay = false,
}) {
  return showLanternSheet<void>(
    context,
    builder: (_) => VerseActionSheet(
      verseKey: verseKey,
      rangeEnd: rangeEnd,
      arabicPreview: arabicPreview,
      reference: reference,
      onPlaySingle: onPlaySingle,
      onPlayFrom: onPlayFrom,
      onRepeat: onRepeat,
      onStop: onStop,
      onSelectRange: onSelectRange,
      showDisplay: showDisplay,
    ),
  );
}
