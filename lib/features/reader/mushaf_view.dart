import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/mushaf/mushaf_page.dart';

final _mushafPageArabicProvider = FutureProvider.autoDispose
    .family<Map<String, String>, int>((ref, page) async {
      final lines = await ref.watch(mushafPageProvider(page).future);
      final keysBySurah = <int, Set<String>>{};
      for (final line in lines) {
        for (final word in line.words) {
          final parts = word.verseKey.split(':');
          final surah = parts.length == 2 ? int.tryParse(parts.first) : null;
          if (surah != null) {
            keysBySurah.putIfAbsent(surah, () => <String>{}).add(word.verseKey);
          }
        }
      }

      final result = <String, String>{};
      final repository = ref.read(corpusRepositoryProvider);
      for (final entry in keysBySurah.entries) {
        final verses = await repository.versesBySurah(entry.key);
        for (final verse in verses) {
          if (entry.value.contains(verse.verseKey) && verse.arabic.isNotEmpty) {
            result[verse.verseKey] = verse.arabic;
          }
        }
      }
      return result;
    });

String mushafVerseSemanticsLabel(String verseKey, String? arabic) {
  final reference = verseKey.replaceFirst(':', ', ');
  final text = arabic?.trim();
  return text == null || text.isEmpty
      ? 'Verset $reference'
      : 'Verset $reference. $text';
}

/// Vue moushaf paginée (police QCF par page). Navigation par pages (façon
/// mushaf papier) — pas d'audio. Affichée quand la disposition Mushaf est
/// choisie et le pack présent.
class MushafView extends ConsumerStatefulWidget {
  const MushafView({
    super.key,
    this.initialVerseKey,
    this.onVerseChanged,
    this.onVerseLongPress,
  });

  final String? initialVerseKey;
  final ValueChanged<String>? onVerseChanged;
  final ValueChanged<String>? onVerseLongPress;

  @override
  ConsumerState<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends ConsumerState<MushafView> {
  final PageController _controller = PageController();
  int _page = 1; // page affichée (1-indexée)
  int _pageChangeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleJumpToVerse(widget.initialVerseKey);
  }

  @override
  void didUpdateWidget(covariant MushafView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialVerseKey != widget.initialVerseKey) {
      _scheduleJumpToVerse(widget.initialVerseKey);
    }
  }

  void _scheduleJumpToVerse(String? key) {
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final page = await ref.read(mushafRepositoryProvider).pageForVerse(key);
      if (page != null && mounted && _controller.hasClients) {
        _controller.jumpToPage(page - 1);
        setState(() => _page = page);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta, int pageCount) {
    final next = (_page - 1 + delta).clamp(0, pageCount - 1);
    _controller.animateToPage(
      next,
      duration: LanternMotion.medium,
      curve: LanternMotion.emphasized,
    );
  }

  Future<void> _onPageChanged(int index) async {
    final generation = ++_pageChangeGeneration;
    final page = index + 1;
    setState(() => _page = page);
    final lines = await ref.read(mushafRepositoryProvider).linesForPage(page);
    if (!mounted || generation != _pageChangeGeneration) return;
    for (final line in lines) {
      for (final word in line.words) {
        if (word.verseKey.isNotEmpty) {
          widget.onVerseChanged?.call(word.verseKey);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final count = ref.watch(mushafPageCountProvider).valueOrNull ?? 604;
    return Column(
      children: [
        Expanded(
          // RTL : page précédente à droite.
          child: PageView.builder(
            controller: _controller,
            reverse: true,
            onPageChanged: _onPageChanged,
            itemCount: count,
            itemBuilder: (_, i) => _MushafPage(
              page: i + 1,
              onVerseLongPress: widget.onVerseLongPress,
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LanternSpace.md,
              vertical: LanternSpace.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tooltip(
                  message: 'Page précédente',
                  child: OutlinedButton(
                    onPressed: _page > 1 ? () => _go(-1, count) : null,
                    child: const Icon(Icons.chevron_left),
                  ),
                ),
                Text(
                  'Page $_page',
                  style: TextStyle(color: t.inkSoft, fontSize: 13),
                ),
                Tooltip(
                  message: 'Page suivante',
                  child: OutlinedButton(
                    onPressed: _page < count ? () => _go(1, count) : null,
                    child: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MushafPage extends ConsumerWidget {
  const _MushafPage({required this.page, this.onVerseLongPress});
  final int page;
  final ValueChanged<String>? onVerseLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final linesAsync = ref.watch(mushafPageProvider(page));
    final fontAsync = ref.watch(mushafFontProvider(page));
    final arabicByVerse =
        ref.watch(_mushafPageArabicProvider(page)).valueOrNull ?? const {};
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];

    if (fontAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (fontAsync.hasError) return _pageError(ref);

    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _pageError(ref),
      data: (lines) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LanternSpace.md,
          vertical: LanternSpace.sm,
        ),
        // FittedBox : toute la page tient à l'écran (jamais d'overflow).
        child: LayoutBuilder(
          builder: (context, c) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              // Largeur intrinsèque (pas de SizedBox fixe) → la mise à l'échelle
              // tient compte de la largeur ET de la hauteur : jamais d'overflow.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in lines)
                    _line(context, t, metas, arabicByVerse, line),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageError(WidgetRef ref) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Impossible de charger la page $page.'),
        const SizedBox(height: LanternSpace.sm),
        TextButton.icon(
          onPressed: () {
            ref
              ..invalidate(mushafPageProvider(page))
              ..invalidate(mushafFontProvider(page));
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
        ),
      ],
    ),
  );

  Widget _line(
    BuildContext context,
    LanternTokens t,
    List metas,
    Map<String, String> arabicByVerse,
    MushafLine line,
  ) {
    const fontSize = 30.0;
    switch (line.type) {
      case MushafLineType.surahHeader:
        final name = metas
            .where((m) => m.number == line.surah)
            .map((m) => m.arabicName as String)
            .firstOrNull;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: t.accent.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            name ?? 'سورة ${line.surah}',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: t.accent,
              fontSize: 22,
              fontFamily: t.arabicFamily,
            ),
          ),
        );
      case MushafLineType.basmalah:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: t.ink,
              fontSize: 24,
              fontFamily: t.arabicFamily,
            ),
          ),
        );
      case MushafLineType.ayah:
        final style = TextStyle(
          color: t.ink,
          fontSize: fontSize,
          fontFamily: 'p$page',
          height: 2.0,
        );
        // Largeur intrinsèque (mainAxisSize.min) : la ligne prend sa taille
        // naturelle, mise à l'échelle ensuite par le FittedBox.
        final groups = <List<MushafWord>>[];
        for (final word in line.words) {
          if (groups.isEmpty || groups.last.last.verseKey != word.verseKey) {
            groups.add([word]);
          } else {
            groups.last.add(word);
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final words in groups)
                _verseGroup(words, style, arabicByVerse),
            ],
          ),
        );
    }
  }

  Widget _verseGroup(
    List<MushafWord> words,
    TextStyle style,
    Map<String, String> arabicByVerse,
  ) {
    final verseKey = words.first.verseKey;
    return Semantics(
      container: true,
      button: onVerseLongPress != null,
      label: mushafVerseSemanticsLabel(verseKey, arabicByVerse[verseKey]),
      hint: onVerseLongPress == null
          ? null
          : 'Appui long pour ouvrir les actions',
      onLongPress: onVerseLongPress == null
          ? null
          : () => onVerseLongPress!(verseKey),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: onVerseLongPress == null
              ? null
              : () => onVerseLongPress!(verseKey),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              for (final word in words) Text(word.glyph, style: style),
            ],
          ),
        ),
      ),
    );
  }
}
