import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';

/// Ensemencement au premier lancement : « Coche ce que tu connais déjà ».
/// Multi-sélection des 114 sourates → seedKnownSurahs (maîtrise + mémorisées).
Future<void> showKnownSurahsSheet(BuildContext context) =>
    showLanternSheet<void>(context, builder: (_) => const _KnownSurahsSheet());

class _KnownSurahsSheet extends ConsumerStatefulWidget {
  const _KnownSurahsSheet();

  @override
  ConsumerState<_KnownSurahsSheet> createState() => _KnownSurahsSheetState();
}

class _KnownSurahsSheetState extends ConsumerState<_KnownSurahsSheet> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Que connais-tu déjà par cœur ?',
          style: TextStyle(
              color: t.ink, fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'Coche tes sourates mémorisées : tes révisions commencent dès '
          'aujourd’hui, par petites vagues quotidiennes — pas tout d’un coup.',
          style: TextStyle(color: t.inkSoft, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: LanternSpace.md),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 120,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: metas.length,
            itemBuilder: (context, i) {
              final m = metas[i];
              final on = _selected.contains(m.number);
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  HapticFeedback.selectionClick();
                  on ? _selected.remove(m.number) : _selected.add(m.number);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? t.accent.withValues(alpha: 0.16) : t.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: on ? t.accent : t.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${m.number} · ${m.transliteration}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: on ? t.accent : t.ink,
                          fontSize: 12,
                          fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      Text(
                        '${m.ayahCount} v.',
                        style: TextStyle(color: t.inkFaint, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: LanternSpace.md),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () async {
                  final byNum = {for (final m in metas) m.number: m.ayahCount};
                  final n = _selected.length;
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(masteryControllerProvider.notifier)
                      .seedKnownSurahs({
                    for (final s in _selected) s: byNum[s] ?? 1,
                  });
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  messenger.showSnackBar(SnackBar(
                    content: Text(
                        '$n sourate${n > 1 ? 's' : ''} au programme — tes '
                        'premières révisions t’attendent.'),
                  ));
                },
          child: Text(_selected.isEmpty
              ? 'Coche au moins une sourate'
              : 'Valider (${_selected.length})'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Je pars de zéro'),
        ),
      ],
    );
  }
}
