import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/mushaf/mushaf_page.dart';

/// Vue moushaf paginée (police QCF par page). Affichée quand la disposition
/// « Madni Mushaf » est choisie et le pack d'assets présent.
class MushafView extends ConsumerStatefulWidget {
  const MushafView({
    super.key,
    this.initialPage = 1,
    this.onVerseLongPress,
  });

  final int initialPage;
  final ValueChanged<String>? onVerseLongPress;

  @override
  ConsumerState<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends ConsumerState<MushafView> {
  late final PageController _controller =
      PageController(initialPage: (widget.initialPage - 1).clamp(0, 603));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(mushafPageCountProvider).valueOrNull ?? 604;
    // RTL : la première page est à droite, on « tourne » vers la gauche.
    return PageView.builder(
      controller: _controller,
      reverse: true,
      itemCount: count,
      itemBuilder: (_, i) => _MushafPage(
        page: i + 1,
        onVerseLongPress: widget.onVerseLongPress,
      ),
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
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];

    return linesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur page $page : $e')),
      data: (lines) => LayoutBuilder(
        builder: (context, c) {
          final fontSize = (c.maxWidth / 13).clamp(20.0, 40.0);
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LanternSpace.md, vertical: LanternSpace.sm),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final line in lines)
                  _line(context, t, metas, line, fontSize),
                Text('$page',
                    style: TextStyle(color: t.inkSoft, fontSize: 12)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _line(BuildContext context, LanternTokens t, List metas,
      MushafLine line, double fontSize) {
    switch (line.type) {
      case MushafLineType.surahHeader:
        final name = metas
            .where((m) => m.number == line.surah)
            .map((m) => m.arabicName as String)
            .firstOrNull;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: t.accent.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            name ?? 'سورة ${line.surah}',
            textDirection: TextDirection.rtl,
            style: TextStyle(
                color: t.accent, fontSize: fontSize * 0.7, fontFamily: t.arabicFamily),
          ),
        );
      case MushafLineType.basmalah:
        return Text(
          'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
          textDirection: TextDirection.rtl,
          style: TextStyle(
              color: t.ink, fontSize: fontSize * 0.8, fontFamily: t.arabicFamily),
        );
      case MushafLineType.ayah:
        final style = TextStyle(
            color: t.ink, fontSize: fontSize, fontFamily: 'qcf_p$page', height: 1.9);
        final words = [
          for (final w in line.words)
            GestureDetector(
              onLongPress: onVerseLongPress == null
                  ? null
                  : () => onVerseLongPress!(w.verseKey),
              child: Text(w.glyph, style: style),
            ),
        ];
        return Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: line.centered
              ? MainAxisAlignment.center
              : MainAxisAlignment.spaceBetween,
          children: words,
        );
    }
  }
}
