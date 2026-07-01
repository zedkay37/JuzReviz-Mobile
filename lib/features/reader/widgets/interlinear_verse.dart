import 'package:flutter/material.dart';
import 'package:juzreviz/core/arabic/arabic_text.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/verse.dart';
import 'package:juzreviz/domain/model/word.dart';
import 'package:juzreviz/features/reader/widgets/ayah_seal.dart';

/// Verset interlinéaire (flagship) : arabe monumental, glose sous chaque mot,
/// traduction sous le verset. Gère voile, surlignage audio, tap mot, capture.
class InterlinearVerse extends StatefulWidget {
  const InterlinearVerse({
    super.key,
    required this.verse,
    this.wordByWord = true,
    this.showTranslation = true,
    this.lang = 'fr',
    this.latinAyahNumbers = false,
    this.veilMode = VeilMode.full,
    this.veilWords = 3,
    this.fontSize = 30,
    this.highlightedPosition,
    this.active = false,
    this.onWordTap,
    this.onWordLongPress,
    this.onLongPress,
  });

  final Verse verse;
  final bool wordByWord;
  final bool showTranslation;
  /// Langue unique des gloses et de la traduction.
  final String lang;
  final bool latinAyahNumbers;
  final VeilMode veilMode;
  final int veilWords;
  final double fontSize;
  final int? highlightedPosition;

  /// Verset en cours de lecture (surlignage doux + auto-scroll).
  final bool active;
  final ValueChanged<int>? onWordTap;

  /// Appui long sur un mot → audio de prononciation du mot.
  final ValueChanged<int>? onWordLongPress;
  final VoidCallback? onLongPress;

  @override
  State<InterlinearVerse> createState() => _InterlinearVerseState();
}

class _InterlinearVerseState extends State<InterlinearVerse> {
  int _extraRevealed = 0;

  int get _baseVisible => switch (widget.veilMode) {
    VeilMode.full => widget.verse.words.length,
    VeilMode.firstWords => widget.veilWords,
    VeilMode.hidden => 0,
  };

  int get _visibleCount =>
      (_baseVisible + _extraRevealed).clamp(0, widget.verse.words.length);

  @override
  void didUpdateWidget(InterlinearVerse old) {
    super.didUpdateWidget(old);
    if (old.veilMode != widget.veilMode ||
        old.verse.verseKey != widget.verse.verseKey) {
      _extraRevealed = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final veiled = widget.veilMode != VeilMode.full;
    final useColumns = widget.wordByWord || veiled;

    final translation = widget.verse.translation(widget.lang);
    return Semantics(
      container: true,
      label:
          'Verset ${widget.verse.verseKey}'
          '${translation.isNotEmpty ? '. $translation' : ''}',
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: LanternMotion.fast,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            // Surlignage groupé doux (verset actif), sans filet lourd.
            color: widget.active ? t.surfaceHigh : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (useColumns) _wordColumns(t) else _fullLine(t),
              if (widget.showTranslation && translation.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    translation,
                    textAlign: TextAlign.start,
                    style: TextStyle(color: t.ink, fontSize: 16, height: 1.42),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullLine(LanternTokens t) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    textDirection: TextDirection.rtl,
    children: [
      Expanded(
        child: ArabicText(widget.verse.arabic, fontSize: widget.fontSize),
      ),
      const SizedBox(width: LanternSpace.sm),
      AyahSeal(ayah: widget.verse.ayah, latin: widget.latinAyahNumbers),
    ],
  );

  Widget _wordColumns(LanternTokens t) => Wrap(
    textDirection: TextDirection.rtl,
    alignment: WrapAlignment.start,
    crossAxisAlignment: WrapCrossAlignment.start,
    spacing: 18,
    runSpacing: 20,
    children: [
      for (var i = 0; i < widget.verse.words.length; i++)
        _wordCell(t, widget.verse.words[i], visible: i < _visibleCount),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: AyahSeal(
          ayah: widget.verse.ayah,
          latin: widget.latinAyahNumbers,
        ),
      ),
    ],
  );

  Widget _wordCell(LanternTokens t, Word w, {required bool visible}) {
    final highlighted = widget.highlightedPosition == w.position;
    if (!visible) {
      return GestureDetector(
        onTap: () => setState(() => _extraRevealed++),
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('•••', style: TextStyle(color: t.inkSoft)),
        ),
      );
    }
    return GestureDetector(
      onTap: widget.onWordTap == null
          ? null
          : () => widget.onWordTap!(w.position),
      onLongPress: widget.onWordLongPress == null
          ? null
          : () => widget.onWordLongPress!(w.position),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: highlighted
                  ? BoxDecoration(
                      color: t.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Text(
                w.arabic,
                style: TextStyle(
                  fontFamily: t.arabicFamily,
                  fontSize: w.isWaqf ? widget.fontSize * 0.6 : widget.fontSize,
                  height: 1.34,
                  color: highlighted ? t.accent : t.ink,
                ),
              ),
            ),
          ),
          if (widget.wordByWord)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  w.gloss(widget.lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.inkSoft,
                    fontSize: 13,
                    height: 1.28,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
