import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/capture_bar.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/playback.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/verse.dart';
import 'package:juzreviz/features/reader/reader_providers.dart';
import 'package:juzreviz/features/reader/widgets/interlinear_verse.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

typedef _ReaderConfig = ({
  bool wbw,
  bool trans,
  String glossLang,
  String transLang,
  bool latin,
  VeilMode veil,
  int veilWords,
  bool focus,
  bool wordAudio,
});

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.selection});
  final Selection selection;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ItemScrollController _scroll = ItemScrollController();
  final ItemPositionsListener _positions = ItemPositionsListener.create();

  bool _focus = false;
  bool _chromeVisible = true;

  List<Verse> _verses = const [];
  List<String> _plan = const [];
  int _ptr = -1;
  bool _playing = false;
  String? _activeKey;

  StreamSubscription<ProcessingState>? _procSub;
  Timer? _resumeDebounce;

  @override
  void initState() {
    super.initState();
    _positions.itemPositions.addListener(_onScrollPositions);
    _procSub = ref
        .read(audioControllerProvider)
        .processingStateStream
        .listen(_onProcessingState);
  }

  @override
  void dispose() {
    _positions.itemPositions.removeListener(_onScrollPositions);
    _procSub?.cancel();
    _resumeDebounce?.cancel();
    ref.read(audioControllerProvider).stop();
    super.dispose();
  }

  // --- Reprise : persiste le premier verset visible (debounce). ---
  void _onScrollPositions() {
    if (_verses.isEmpty) return;
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return;
    final firstIndex = positions
        .where((p) => p.itemTrailingEdge > 0)
        .map((p) => p.index)
        .fold<int>(_verses.length, (a, b) => a < b ? a : b);
    if (firstIndex < 0 || firstIndex >= _verses.length) return;
    final key = _verses[firstIndex].verseKey;
    _resumeDebounce?.cancel();
    _resumeDebounce = Timer(const Duration(milliseconds: 900), () {
      ref
          .read(settingsControllerProvider.notifier)
          .edit((p) => p.copyWith(currentVerseKey: key));
    });
  }

  // --- Moteur audio séquentiel. ---
  void _onProcessingState(ProcessingState state) {
    if (state != ProcessingState.completed || !_playing) return;
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    final finished = _ptr >= 0 && _ptr < _plan.length ? _plan[_ptr] : null;
    final isLastOccurrence =
        finished != null && (_ptr + 1 >= _plan.length || _plan[_ptr + 1] != finished);
    if (settings.autoMaster && finished != null && isLastOccurrence) {
      ref.read(masteryControllerProvider.notifier).markMastered(finished);
    }
    final next = _ptr + 1;
    if (next < _plan.length) {
      _playAt(next, settings);
    } else {
      setState(() {
        _playing = false;
        _activeKey = null;
        _ptr = -1;
      });
    }
  }

  Future<void> _startFrom(int verseIndex) async {
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    final keys = _verses.sublist(verseIndex).map((v) => v.verseKey).toList();
    _plan = expandPlayback(keys, settings.repeatMode,
        repeatCount: settings.repeatCount, rangeCount: settings.rangeCount);
    if (_plan.isEmpty) return;
    await _playAt(0, settings);
  }

  Future<void> _playAt(int ptr, Settings settings) async {
    final key = _plan[ptr];
    setState(() {
      _ptr = ptr;
      _playing = true;
      _activeKey = key;
    });
    _scrollToKey(key, settings);
    final audio = ref.read(audioControllerProvider);
    final ok = await audio.playVerse(settings.reciter, key,
        rate: settings.playbackRate);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _playing = false;
        _activeKey = null;
        _ptr = -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio indisponible hors-ligne.')),
      );
    }
  }

  void _scrollToKey(String key, Settings settings) {
    final index = _verses.indexWhere((v) => v.verseKey == key);
    if (index < 0 || !_scroll.isAttached) return;
    _scroll.scrollTo(
      index: index,
      duration: LanternMotion.medium,
      curve: LanternMotion.emphasized,
      alignment: scrollAlignmentFor(
          settings.scrollTempo, settings.scrollTempoStrength),
    );
  }

  Future<void> _togglePlay() async {
    final audio = ref.read(audioControllerProvider);
    if (_playing) {
      await audio.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    if (_ptr >= 0 && _ptr < _plan.length) {
      await audio.resume();
      if (mounted) setState(() => _playing = true);
      return;
    }
    final start = _firstVisibleIndex();
    await _startFrom(start);
  }

  int _firstVisibleIndex() {
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return 0;
    return positions
        .where((p) => p.itemTrailingEdge > 0)
        .map((p) => p.index)
        .fold<int>(_verses.length, (a, b) => a < b ? a : b)
        .clamp(0, _verses.isEmpty ? 0 : _verses.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final cfg = ref.watch(settingsControllerProvider.select((s) {
      final v = s.valueOrNull ?? const Settings();
      return (
        wbw: v.readerWordByWord,
        trans: v.readerTranslation,
        glossLang: v.glossLang,
        transLang: v.translationLang,
        latin: v.latinAyahNumbers,
        veil: v.veilMode,
        veilWords: v.veilWords,
        focus: v.focusMode,
        wordAudio: v.wordAudio,
      );
    }));
    final versesAsync = ref.watch(readerVersesProvider(widget.selection));
    final focus = _focus || cfg.focus;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LanternScaffold(
      safeArea: false,
      appBar: focus
          ? null
          : AppBar(
              title: Text(widget.selection.label),
              actions: [
                IconButton(
                  tooltip: 'Focus',
                  icon: const Icon(Icons.center_focus_strong),
                  onPressed: () => setState(() => _focus = true),
                ),
              ],
            ),
      body: GestureDetector(
        onTap: () => setState(() => _chromeVisible = !_chromeVisible),
        child: Stack(
          children: [
            SafeArea(
              child: versesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
                data: (verses) {
                  _verses = verses;
                  if (verses.isEmpty) {
                    return const LanternEmpty(message: 'Aucun verset.');
                  }
                  return _buildList(verses, cfg);
                },
              ),
            ),
            if (focus)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                right: 8,
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: reduceMotion ? Duration.zero : LanternMotion.fast,
                  child: IconButton(
                    icon: Icon(Icons.fullscreen_exit, color: t.inkSoft),
                    onPressed: () => setState(() => _focus = false),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: _chromeVisible ? Offset.zero : const Offset(0, 1.4),
                duration: reduceMotion ? Duration.zero : LanternMotion.medium,
                curve: LanternMotion.emphasized,
                child: _AudioBar(
                  playing: _playing,
                  onPlayPause: _togglePlay,
                  onSpeed: _cycleSpeed,
                  onReciter: _pickReciter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Verse> verses, _ReaderConfig cfg) {
    // Reprise : index initial = verset courant si dans cette sélection.
    final resumeKey =
        ref.read(settingsControllerProvider).valueOrNull?.currentVerseKey;
    var initial = 0;
    if (resumeKey != null) {
      final i = verses.indexWhere((v) => v.verseKey == resumeKey);
      if (i >= 0) initial = i;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lecture adaptative : largeur de colonne bornée sur tablette/paysage.
        final maxWidth = constraints.maxWidth > 720.0 ? 720.0 : constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ScrollablePositionedList.builder(
              itemScrollController: _scroll,
              itemPositionsListener: _positions,
              initialScrollIndex: initial,
              padding: const EdgeInsets.only(top: LanternSpace.sm, bottom: 130),
              itemCount: verses.length,
              itemBuilder: (context, i) {
                final v = verses[i];
                return RepaintBoundary(
                  child: InterlinearVerse(
                    verse: v,
                    wordByWord: cfg.wbw,
                    showTranslation: cfg.trans,
                    glossLang: cfg.glossLang,
                    translationLang: cfg.transLang,
                    latinAyahNumbers: cfg.latin,
                    veilMode: cfg.veil,
                    veilWords: cfg.veilWords,
                    active: _activeKey == v.verseKey,
                    onWordTap: cfg.wordAudio ? (pos) => _playWord(v, pos) : null,
                    onLongPress: () => _capture(v),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _playWord(Verse v, int position) async {
    // Audio-mot : joue le verset à la position du mot (fallback verset entier).
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    await ref
        .read(audioControllerProvider)
        .playVerse(settings.reciter, v.verseKey, rate: settings.playbackRate);
  }

  Future<void> _capture(Verse v) async {
    await showLanternSheet<void>(
      context,
      builder: (ctx) => CaptureBar(
        verseKey: v.verseKey,
        onFragile: () {
          ref.read(masteryControllerProvider.notifier).markFragile(v.verseKey);
          Navigator.of(ctx).pop();
        },
        onMastered: () {
          ref.read(masteryControllerProvider.notifier).markMastered(v.verseKey);
          Navigator.of(ctx).pop();
        },
        onListen: () {
          Navigator.of(ctx).pop();
          final i = _verses.indexWhere((x) => x.verseKey == v.verseKey);
          if (i >= 0) _startFrom(i);
        },
      ),
    );
  }

  void _cycleSpeed() {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final s = ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    const steps = [0.75, 1.0, 1.25, 1.5, 2.0];
    final idx = steps.indexWhere((x) => x >= s.playbackRate);
    final next = steps[(idx + 1) % steps.length];
    ctrl.edit((p) => p.copyWith(playbackRate: next));
    ref.read(audioControllerProvider).setRate(next);
  }

  Future<void> _pickReciter() async {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    await showLanternSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in reciters)
            ListTile(
              title: Text(r.name),
              onTap: () {
                ctrl.edit((p) => p.copyWith(reciter: r.id));
                Navigator.of(ctx).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _AudioBar extends ConsumerWidget {
  const _AudioBar({
    required this.playing,
    required this.onPlayPause,
    required this.onSpeed,
    required this.onReciter,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onSpeed;
  final VoidCallback onReciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final reciter = ref.watch(settingsControllerProvider
        .select((s) => (s.valueOrNull ?? const Settings()).reciter));
    final rate = ref.watch(settingsControllerProvider
        .select((s) => (s.valueOrNull ?? const Settings()).playbackRate));
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(LanternSpace.md),
        padding:
            const EdgeInsets.symmetric(horizontal: LanternSpace.md, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceHigh),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Lecture',
              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle,
                  color: t.accent, size: 34),
              onPressed: onPlayPause,
            ),
            TextButton(
              onPressed: onReciter,
              child: Text(reciterById(reciter).name.split(' ').first,
                  style: TextStyle(color: t.ink)),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSpeed,
              child: Text('$rate×', style: TextStyle(color: t.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
