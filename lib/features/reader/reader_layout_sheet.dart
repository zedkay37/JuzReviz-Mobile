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
    final s = ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final current = readerLayoutFromString(s.readerLayout);
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choisissez votre disposition',
              style: TextStyle(
                  color: t.ink, fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: LanternSpace.md),
          for (final layout in ReaderLayout.values)
            Padding(
              padding: const EdgeInsets.only(bottom: LanternSpace.sm),
              child: _LayoutCard(
                layout: layout,
                selected: current == layout,
                onTap: () {
                  if (!layout.available) {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Disposition Mushaf à venir (nécessite le pack de pages).'),
                    ));
                    return;
                  }
                  HapticFeedback.selectionClick();
                  ctrl.edit((p) => p.copyWith(readerLayout: layout.id));
                  Navigator.of(context).pop();
                },
              ),
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
    required this.selected,
    required this.onTap,
  });
  final ReaderLayout layout;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (layout) {
        ReaderLayout.mushafTajweed => Icons.palette_outlined,
        ReaderLayout.mushafMadni => Icons.menu_book,
        ReaderLayout.flexible => Icons.text_fields,
        ReaderLayout.verseByVerse => Icons.auto_stories_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final dim = !layout.available;
    return GestureDetector(
      onTap: onTap,
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
              child: Icon(_icon,
                  color: dim ? t.inkFaint : (selected ? t.accent : t.inkSoft),
                  size: 20),
            ),
            const SizedBox(width: LanternSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(layout.label,
                            style: TextStyle(
                                color: dim ? t.inkSoft : t.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (dim)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('· à venir',
                              style:
                                  TextStyle(color: t.inkFaint, fontSize: 11)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(layout.description,
                      style: TextStyle(
                          color: t.inkSoft, fontSize: 12, height: 1.35)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: t.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

Future<void> showReaderLayout(BuildContext context) =>
    showLanternSheet<void>(context, builder: (_) => const ReaderLayoutSheet());
