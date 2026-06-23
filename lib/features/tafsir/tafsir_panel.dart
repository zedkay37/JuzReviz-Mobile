import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';

/// Ouvre le panneau Tafsir pour un verset, sans quitter le contexte de lecture.
Future<void> showTafsir(BuildContext context, WidgetRef ref, String verseKey) {
  ref.read(settingsControllerProvider.notifier).edit((p) => p.copyWith(tafsirOpen: true));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TafsirPanel(verseKey: verseKey),
  ).whenComplete(() {
    ref.read(settingsControllerProvider.notifier).edit((p) => p.copyWith(tafsirOpen: false));
  });
}

class TafsirPanel extends ConsumerWidget {
  const TafsirPanel({super.key, required this.verseKey});
  final String verseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final lang = ref.watch(settingsControllerProvider
        .select((s) => (s.valueOrNull ?? const Settings()).tafsirLanguage));
    final normLang = lang == 'en' ? 'en' : 'fr';
    final tafsirAsync =
        ref.watch(verseTafsirProvider((lang: normLang, verseKey: verseKey)));

    // Surface « parchemin » pour un confort de lecture longue (tokens dédiés).
    final parch = tokensFor(AppTheme.parchemin);
    final parchment = parch.background;
    final ink = parch.ink;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: parchment,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(LanternSpace.radius)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  Icon(Icons.menu_book, color: ink.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text('Tafsir · $verseKey',
                      style: TextStyle(
                          color: ink, fontSize: 16, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  _LangToggle(current: normLang, ink: ink, accent: t.accent),
                  IconButton(
                    icon: Icon(Icons.close, color: ink),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x33000000)),
            Expanded(
              child: tafsirAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur : $e')),
                data: (text) => text.trim().isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Pas de tafsir pour ce verset.',
                              style: TextStyle(color: ink)),
                        ),
                      )
                    : SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                        child: SelectableText(
                          text,
                          style: TextStyle(
                              color: ink, fontSize: 16, height: 1.7),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangToggle extends ConsumerWidget {
  const _LangToggle({required this.current, required this.ink, required this.accent});
  final String current;
  final Color ink;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget chip(String code, String label) {
      final on = current == code;
      return GestureDetector(
        onTap: () => ref
            .read(settingsControllerProvider.notifier)
            .edit((p) => p.copyWith(tafsirLanguage: code)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: on ? accent.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: TextStyle(
                  color: ink,
                  fontWeight: on ? FontWeight.w500 : FontWeight.w400)),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      chip('fr', 'FR'),
      const SizedBox(width: 4),
      chip('en', 'EN'),
    ]);
  }
}
