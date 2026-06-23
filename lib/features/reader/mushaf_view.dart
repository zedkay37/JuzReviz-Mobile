import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/mushaf/mushaf_page.dart';

/// Vue moushaf paginée (police QCF par page). Navigation par pages (façon
/// mushaf papier) — pas d'audio. Affichée quand la disposition Mushaf est
/// choisie et le pack présent.
class MushafView extends ConsumerStatefulWidget {
  const MushafView({
    super.key,
    this.initialVerseKey,
    this.onVerseLongPress,
  });

  final String? initialVerseKey;
  final ValueChanged<String>? onVerseLongPress;

  @override
  ConsumerState<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends ConsumerState<MushafView> {
  final PageController _controller = PageController();
  int _page = 1; // page affichée (1-indexée)

  @override
  void initState() {
    super.initState();
    final key = widget.initialVerseKey;
    if (key != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final page = await ref.read(mushafRepositoryProvider).pageForVerse(key);
        if (page != null && mounted && _controller.hasClients) {
          _controller.jumpToPage(page - 1);
          setState(() => _page = page);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_page - 1 + delta).clamp(0, 603);
    _controller.animateToPage(next,
        duration: LanternMotion.medium, curve: LanternMotion.emphasized);
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
            onPageChanged: (i) => setState(() => _page = i + 1),
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
                horizontal: LanternSpace.md, vertical: LanternSpace.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: _page > 1 ? () => _go(-1) : null,
                  child: const Icon(Icons.chevron_left),
                ),
                Text('Page $_page',
                    style: TextStyle(color: t.inkSoft, fontSize: 13)),
                OutlinedButton(
                  onPressed: _page < count ? () => _go(1) : null,
                  child: const Icon(Icons.chevron_right),
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
    final fontReady = ref.watch(mushafFontProvider(page)).hasValue;
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];

    if (!fontReady) return const Center(child: CircularProgressIndicator());

    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur page $page : $e')),
      data: (lines) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: LanternSpace.md, vertical: LanternSpace.sm),
        // FittedBox : toute la page tient à l'écran (jamais d'overflow).
        child: LayoutBuilder(
          builder: (context, c) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: c.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final line in lines)
                      _line(context, t, metas, line),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(
      BuildContext context, LanternTokens t, List metas, MushafLine line) {
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
                color: t.accent, fontSize: 22, fontFamily: t.arabicFamily),
          ),
        );
      case MushafLineType.basmalah:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textDirection: TextDirection.rtl,
            style: TextStyle(
                color: t.ink, fontSize: 24, fontFamily: t.arabicFamily),
          ),
        );
      case MushafLineType.ayah:
        final style = TextStyle(
            color: t.ink, fontSize: fontSize, fontFamily: 'p$page', height: 2.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: line.centered
                ? MainAxisAlignment.center
                : MainAxisAlignment.spaceBetween,
            children: [
              for (final w in line.words)
                GestureDetector(
                  onLongPress: onVerseLongPress == null
                      ? null
                      : () => onVerseLongPress!(w.verseKey),
                  child: Text(w.glyph, style: style),
                ),
            ],
          ),
        );
    }
  }
}
