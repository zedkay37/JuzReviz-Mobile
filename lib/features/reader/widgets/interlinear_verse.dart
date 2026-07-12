import 'package:flutter/material.dart';
import 'package:juzreviz/core/arabic/arabic_text.dart';
import 'package:juzreviz/core/arabic/tajweed.dart';
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
    this.tajweed = false,
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

  /// Coloration tajwid (ghunnah/madd/qalqalah…) sur le texte arabe.
  final bool tajweed;
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
      explicitChildNodes: useColumns,
      label:
          'Verset ${widget.verse.verseKey}'
          '${widget.showTranslation && translation.isNotEmpty ? '. $translation' : ''}',
      child: GestureDetector(
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: LanternMotion.resolve(context, LanternMotion.fast),
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
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    // Couche de sens séparée visuellement du texte arabe.
                    color: t.surfaceHigh.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
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

  /// Mot arabe suivant (règles tajwid inter-mots), null en fin de verset.
  String? _nextArabic(int i) => i + 1 < widget.verse.words.length
      ? widget.verse.words[i + 1].arabic
      : null;

  /// Spans tajwid d'un mot : lettres colorées par règle, base sinon.
  TextSpan _tajweedSpan(String word, String? next, TextStyle base) {
    final palette = Theme.of(context).brightness == Brightness.light
        ? tajweedColorsLight
        : tajweedColorsDark;
    return TextSpan(
      children: [
        for (final seg in tajweedSegments(word, nextWord: next))
          TextSpan(
            text: seg.text,
            style: seg.rule == null
                ? base
                : base.copyWith(color: palette[seg.rule]),
          ),
      ],
    );
  }

  Widget _fullLine(LanternTokens t) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    textDirection: TextDirection.rtl,
    children: [
      Expanded(
        child: widget.tajweed && widget.verse.words.isNotEmpty
            ? Text.rich(
                TextSpan(
                  children: [
                    for (var i = 0; i < widget.verse.words.length; i++) ...[
                      _tajweedSpan(
                        widget.verse.words[i].arabic,
                        _nextArabic(i),
                        TextStyle(
                          fontFamily: t.arabicFamily,
                          fontSize: widget.fontSize,
                          height: 1.9,
                          color: t.ink,
                        ),
                      ),
                      if (i < widget.verse.words.length - 1)
                        const TextSpan(text: ' '),
                    ],
                  ],
                ),
                textDirection: TextDirection.rtl,
              )
            : ArabicText(widget.verse.arabic, fontSize: widget.fontSize),
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
        _wordCell(
          t,
          widget.verse.words[i],
          next: _nextArabic(i),
          visible: i < _visibleCount,
        ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: AyahSeal(
          ayah: widget.verse.ayah,
          latin: widget.latinAyahNumbers,
        ),
      ),
    ],
  );

  Widget _wordCell(
    LanternTokens t,
    Word w, {
    String? next,
    required bool visible,
  }) {
    final highlighted = widget.highlightedPosition == w.position;
    if (!visible) {
      void reveal() => setState(() => _extraRevealed++);
      return Semantics(
        button: true,
        label: 'Révéler le mot ${w.position}',
        onTap: reveal,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: reveal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              child: Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: t.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('•••', style: TextStyle(color: t.inkSoft)),
              ),
            ),
          ),
        ),
      );
    }
    final tap = widget.onWordTap == null
        ? null
        : () => widget.onWordTap!(w.position);
    final longPress = widget.onWordLongPress == null
        ? null
        : () => widget.onWordLongPress!(w.position);
    return Semantics(
      button: tap != null || longPress != null,
      label: [
        w.arabic,
        if (widget.wordByWord) w.gloss(widget.lang),
      ].where((part) => part.isNotEmpty).join(', '),
      hint: longPress == null ? null : 'Appui long pour écouter ce mot',
      onTap: tap,
      onLongPress: longPress,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          onLongPress: longPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: highlighted
                        ? BoxDecoration(
                            color: t.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Builder(
                      builder: (_) {
                        final style = TextStyle(
                          fontFamily: t.arabicFamily,
                          fontSize: w.isWaqf
                              ? widget.fontSize * 0.6
                              : widget.fontSize,
                          height: 1.34,
                          color: highlighted ? t.accent : t.ink,
                        );
                        // Le surlignage audio prime sur la coloration tajwid.
                        return widget.tajweed && !highlighted
                            ? Text.rich(_tajweedSpan(w.arabic, next, style))
                            : Text(w.arabic, style: style);
                      },
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
          ),
        ),
      ),
    );
  }
}
