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
      appBar: AppBar(title: const Text('Micro-session')),
      body: versesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
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
                child: Text('${_index + 1} / ${verses.length}',
                    style: TextStyle(color: t.inkSoft)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: InterlinearVerse(
                    verse: v,
                    onLongPress: () =>
                        showVerseActions(context, verseKey: v.verseKey),
                    wordByWord: settings.readerWordByWord,
                    showTranslation: settings.readerTranslation,
                    lang: settings.contentLang,
                    latinAyahNumbers: settings.latinAyahNumbers,
                    // Auto-test : voile actif en session par défaut.
                    veilMode: settings.veilMode == VeilMode.full
                        ? VeilMode.firstWords
                        : settings.veilMode,
                    veilWords: settings.veilWords,
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

  Widget _actions(String verseKey, int total) {
    final t = context.lantern;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LanternSpace.md),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: t.fragile),
                icon: const Icon(Icons.bolt),
                label: const Text('Fragile'),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(masteryControllerProvider.notifier)
                      .markFragile(verseKey);
                  _fragileCount++;
                  _next(total);
                },
              ),
            ),
            const SizedBox(width: LanternSpace.sm),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.spa),
                label: const Text('Maîtrisé'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(masteryControllerProvider.notifier)
                      .markMastered(verseKey);
                  _masteredCount++;
                  _next(total);
                },
              ),
            ),
          ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: t.accent, size: 40),
          const SizedBox(height: 12),
          Text('Session terminée',
              style: TextStyle(
                  color: t.ink, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('$total versets revus · $_masteredCount maîtrisés · $_fragileCount fragiles',
              style: TextStyle(color: t.inkSoft)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Revenir'),
          ),
        ],
      ),
    );
  }
}
