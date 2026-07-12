import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/verse_action_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/reader/reader_providers.dart';
import 'package:juzreviz/features/reader/widgets/interlinear_verse.dart';

/// Runner de micro-session : enchaîne les versets (écoute + voile),
/// capture inline F/M, puis résumé doux.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.selection});
  final Selection selection;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  int _index = 0;
  int _fragileCount = 0;
  int _masteredCount = 0;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final versesAsync = ref.watch(readerVersesProvider(widget.selection));
    final settings =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();

    return LanternScaffold(
      contentMaxWidth: 760,
      appBar: AppBar(title: const Text('Micro-session')),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LanternEmpty(
          message:
              'Impossible de charger les versets de cette session. Réessaie dans un instant.',
          action: OutlinedButton.icon(
            onPressed: () =>
                ref.invalidate(readerVersesProvider(widget.selection)),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
        data: (verses) {
          if (verses.isEmpty) {
            return const LanternEmpty(message: 'Rien à réviser.');
          }
          if (_done) return _summary(verses.length);
          final v = verses[_index.clamp(0, verses.length - 1)];
          return Column(
            children: [
              LinearProgressIndicator(
                value: (_index + 1) / verses.length,
                backgroundColor: t.surfaceHigh,
                color: t.accent,
              ),
              Padding(
                padding: const EdgeInsets.all(LanternSpace.sm),
                child: Text(
                  '${_index + 1} / ${verses.length}',
                  style: TextStyle(color: t.inkSoft),
                ),
              ),
              Expanded(
                // Swipe : gauche = fragile, droite = maîtrisé (mémoire
                // musculaire type Anki) — les boutons restent en dessous.
                child: Dismissible(
                  key: ValueKey(v.verseKey),
                  direction: DismissDirection.horizontal,
                  background: _swipeHint(
                    t,
                    alignment: Alignment.centerLeft,
                    icon: Icons.spa,
                    label: 'Maîtrisé',
                    color: t.fresh,
                  ),
                  secondaryBackground: _swipeHint(
                    t,
                    alignment: Alignment.centerRight,
                    icon: Icons.bolt,
                    label: 'Fragile',
                    color: t.fragile,
                  ),
                  onDismissed: (dir) => _mark(
                    v.verseKey,
                    verses.length,
                    mastered: dir == DismissDirection.startToEnd,
                  ),
                  child: SingleChildScrollView(
                    child: InterlinearVerse(
                      verse: v,
                      onLongPress: () =>
                          showVerseActions(context, verseKey: v.verseKey),
                      wordByWord: settings.readerWordByWord,
                      showTranslation: settings.readerTranslation,
                      lang: settings.contentLang,
                      latinAyahNumbers: settings.latinAyahNumbers,
                      tajweed: settings.tajweedColors,
                      // Auto-test : voile actif en session par défaut.
                      veilMode: settings.veilMode == VeilMode.full
                          ? VeilMode.firstWords
                          : settings.veilMode,
                      veilWords: settings.veilWords,
                    ),
                  ),
                ),
              ),
              _actions(v.verseKey, verses.length),
            ],
          );
        },
      ),
    );
  }

  /// Marque le verset et avance — chemin unique pour boutons et swipe.
  void _mark(String verseKey, int total, {required bool mastered}) {
    if (mastered) {
      HapticFeedback.lightImpact();
      ref.read(masteryControllerProvider.notifier).markMastered(verseKey);
      _masteredCount++;
    } else {
      HapticFeedback.mediumImpact();
      ref.read(masteryControllerProvider.notifier).markFragile(verseKey);
      _fragileCount++;
    }
    _next(total);
  }

  Widget _swipeHint(
    LanternTokens t, {
    required Alignment alignment,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: LanternSpace.lg),
      color: color.withValues(alpha: 0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _actions(String verseKey, int total) {
    final t = context.lantern;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(LanternSpace.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5;
            final fragile = OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: t.fragile),
              icon: const Icon(Icons.bolt),
              label: const Text('Fragile'),
              onPressed: () => _mark(verseKey, total, mastered: false),
            );
            final mastered = FilledButton.icon(
              icon: const Icon(Icons.spa),
              label: const Text('Maîtrisé'),
              onPressed: () => _mark(verseKey, total, mastered: true),
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fragile,
                  const SizedBox(height: LanternSpace.sm),
                  mastered,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: fragile),
                const SizedBox(width: LanternSpace.sm),
                Expanded(child: mastered),
              ],
            );
          },
        ),
      ),
    );
  }

  void _next(int total) {
    if (_index + 1 >= total) {
      ref.read(masteryControllerProvider.notifier).recordSession();
      setState(() => _done = true);
    } else {
      setState(() => _index++);
    }
  }

  Widget _summary(int total) {
    final t = context.lantern;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(LanternSpace.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - LanternSpace.lg * 2)
                .clamp(0, double.infinity)
                .toDouble(),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: t.accent, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Session terminée',
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$total versets revus · $_masteredCount maîtrisés · $_fragileCount fragiles',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.inkSoft),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Revenir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
