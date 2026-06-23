import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_ambient.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/components/review_banner.dart';
import 'package:juzreviz/core/designsystem/components/verse_action_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/playback.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/verse.dart';
import 'package:juzreviz/features/atlas/surah_picker.dart';
import 'package:juzreviz/features/reader/mushaf_view.dart';
import 'package:juzreviz/features/reader/reader_layout_sheet.dart';
import 'package:juzreviz/features/reader/reader_playback_sheet.dart';
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
  double fontSize,
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

  /// Sélection courante : override choisi via le picker, sinon celle du parent.
  Selection? _override;
  Selection get _selection => _override ?? widget.selection;

  List<Verse> _verses = const [];
  List<String> _plan = const [];
  int _ptr = -1;
  bool _playing = false;
  String? _activeKey;

  StreamSubscription<ProcessingState>? _procSub;
  Timer? _resumeDebounce;
  Timer? _pauseTimer; // temporisation après chaque âyah

  // Reprise surfacée : puce « Reprendre » (auto-dismiss), tap → recale.
  String? _resumeKey;
  bool _resumeResolved = false;
  Timer? _resumeChipTimer;

  // Sélection de plage : clé du verset de départ (null = pas en sélection).
  // État éphémère, réinitialisé à la sortie du Reader (dispose).
  String? _rangeStart;

  // Enchaînement auto : démarre la lecture dès que la sourate suivante est prête.
  bool _autoPlayPending = false;

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
    _resumeChipTimer?.cancel();
    _pauseTimer?.cancel();
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
      final pause = settings.repeatPauseMs;
      if (pause > 0) {
        _pauseTimer?.cancel();
        _pauseTimer = Timer(Duration(milliseconds: pause), () {
          if (mounted && _playing) _playAt(next, settings);
        });
      } else {
        _playAt(next, settings);
      }
    } else {
      // Fin de sourate → enchaîne sur la suivante (façon concurrent).
      final surah = _currentSurah;
      final atSurahEnd = _verses.isNotEmpty && finished == _verses.last.verseKey;
      if (surah != null && surah < 114 && atSurahEnd) {
        _goToSurah(surah + 1, autoPlay: true);
        return;
      }
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

  String _readableTitle() {
    final sel = _selection;
    if (sel is SelSurah) {
      final metas = ref.read(surahMetasProvider).valueOrNull;
      final m = metas?.where((x) => x.number == sel.surah).firstOrNull;
      final name = m?.transliteration ?? 'Sourate ${sel.surah}';
      if (m != null && sel.from == 1 && sel.to == m.ayahCount) return name;
      return '$name ${sel.from}–${sel.to}';
    }
    return sel.label;
  }

  Future<void> _changeSurah() async {
    final number = await pickSurah(context);
    if (number == null || !mounted) return;
    await _goToSurah(number);
  }

  /// Change de sourate (picker, prev/next, enchaînement auto).
  Future<void> _goToSurah(int number, {bool autoPlay = false}) async {
    if (number < 1 || number > 114) return;
    final metas = ref.read(surahMetasProvider).valueOrNull;
    final count =
        metas?.where((m) => m.number == number).firstOrNull?.ayahCount ?? 1;
    _pauseTimer?.cancel();
    await ref.read(audioControllerProvider).stop();
    if (!mounted) return;
    ref
        .read(settingsControllerProvider.notifier)
        .edit((p) => p.copyWith(currentVerseKey: '$number:1'));
    setState(() {
      _override = SelSurah(number, 1, count);
      _verses = const [];
      _plan = const [];
      _ptr = -1;
      _playing = false;
      _activeKey = null;
      _autoPlayPending = autoPlay;
    });
  }

  /// Sourate courante si la sélection est une sourate (sinon null).
  int? get _currentSurah {
    final sel = _selection;
    return sel is SelSurah ? sel.surah : null;
  }

  Future<void> _togglePlay() async {
    final audio = ref.read(audioControllerProvider);
    if (_playing) {
      _pauseTimer?.cancel();
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
      // La disposition pilote l'affichage : « Verset par verset » = mot-à-mot +
      // traduction ; « Flexible » = arabe seul, taille personnalisable.
      final verse =
          readerLayoutFromString(v.readerLayout) == ReaderLayout.verseByVerse;
      return (
        wbw: verse,
        trans: verse,
        glossLang: v.glossLang,
        transLang: v.translationLang,
        latin: v.latinAyahNumbers,
        veil: v.veilMode,
        veilWords: v.veilWords,
        focus: v.focusMode,
        wordAudio: verse && v.wordAudio,
        fontSize: (30.0 * v.fontScale).clamp(20.0, 54.0),
      );
    }));
    final versesAsync = ref.watch(readerVersesProvider(_selection));
    final ambient = ref.watch(settingsControllerProvider
        .select((s) => (s.valueOrNull ?? const Settings()).ambientDecor));
    final focus = _focus || cfg.focus;
    final layout = ref.watch(settingsControllerProvider.select((s) =>
        readerLayoutFromString((s.valueOrNull ?? const Settings()).readerLayout)));
    final mushafReady = ref.watch(mushafAvailableProvider).valueOrNull ?? false;
    final useMushaf = mushafReady &&
        (layout == ReaderLayout.mushafMadni ||
            layout == ReaderLayout.mushafTajweed);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LanternScaffold(
      safeArea: false,
      appBar: focus
          ? null
          : AppBar(
              titleSpacing: 8,
              title: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _changeSurah,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(_readableTitle(),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.expand_more, size: 20),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Programme',
                  icon: const Icon(Icons.local_fire_department_outlined),
                  onPressed: () => context.push('/program'),
                ),
                IconButton(
                  tooltip: 'Disposition',
                  icon: const Icon(Icons.view_day_outlined),
                  onPressed: () => showReaderLayout(context),
                ),
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
            if (ambient)
              Positioned.fill(child: LanternAmbient(animate: !reduceMotion)),
            SafeArea(
              child: versesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
                data: (verses) {
                  _verses = verses;
                  if (verses.isEmpty) {
                    return const LanternEmpty(message: 'Aucun verset.');
                  }
                  if (_autoPlayPending) {
                    _autoPlayPending = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _startFrom(0);
                    });
                  }
                  if (useMushaf) {
                    return MushafView(
                      onVerseLongPress: (k) =>
                          showVerseActions(context, verseKey: k),
                    );
                  }
                  _resolveResume(verses);
                  if (focus) return _buildList(verses, cfg);
                  final selecting = _rangeStart != null;
                  return Column(
                    children: [
                      if (selecting)
                        _SelectionBanner(onCancel: _cancelRange)
                      else ...[
                        const ReviewBanner(),
                        if (_resumeKey != null) _resumeChip(_resumeKey!),
                      ],
                      Expanded(child: _buildList(verses, cfg)),
                    ],
                  );
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
                  onPrevSurah: (_currentSurah != null && _currentSurah! > 1)
                      ? () => _goToSurah(_currentSurah! - 1, autoPlay: _playing)
                      : null,
                  onNextSurah: (_currentSurah != null && _currentSurah! < 114)
                      ? () => _goToSurah(_currentSurah! + 1, autoPlay: _playing)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resolveResume(List<Verse> verses) {
    if (_resumeResolved) return;
    final s = ref.read(settingsControllerProvider).valueOrNull;
    if (s == null) return; // réessaie au prochain build (settings pas encore prêt)
    _resumeResolved = true;
    final rk = s.currentVerseKey;
    if (rk.isEmpty) return;
    final idx = verses.indexWhere((v) => v.verseKey == rk);
    if (idx <= 0) return; // déjà en tête → rien à surfacer
    _resumeKey = rk;
    _resumeChipTimer?.cancel();
    _resumeChipTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _resumeKey = null);
    });
  }

  void _dismissResume() {
    _resumeChipTimer?.cancel();
    if (mounted) setState(() => _resumeKey = null);
  }

  Widget _resumeChip(String key) {
    final t = context.lantern;
    final ayah = key.split(':').last;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          LanternSpace.md, LanternSpace.sm, LanternSpace.md, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(Icons.history, size: 18, color: t.accent),
          label: Text('Reprendre · verset $ayah'),
          onPressed: () {
            _dismissResume();
            final settings = ref.read(settingsControllerProvider).valueOrNull ??
                const Settings();
            _scrollToKey(key, settings);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Verse> verses, _ReaderConfig cfg) {
    const initial = 0;
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
                final t = context.lantern;
                final selecting = _rangeStart != null;
                final inRange = selecting && _isInPendingRange(v.verseKey);
                final tile = RepaintBoundary(
                  child: InterlinearVerse(
                    verse: v,
                    wordByWord: cfg.wbw,
                    showTranslation: cfg.trans,
                    glossLang: cfg.glossLang,
                    translationLang: cfg.transLang,
                    latinAyahNumbers: cfg.latin,
                    veilMode: cfg.veil,
                    veilWords: cfg.veilWords,
                    fontSize: cfg.fontSize,
                    active: _activeKey == v.verseKey,
                    onWordTap: (cfg.wordAudio && !selecting)
                        ? (pos) => _playWord(v, pos)
                        : null,
                    onLongPress: selecting ? null : () => _capture(v),
                  ),
                );
                if (!selecting) return tile;
                // Mode sélection de plage : tap = borne de fin.
                return GestureDetector(
                  onTap: () => _endRange(v.verseKey),
                  child: Container(
                    decoration: BoxDecoration(
                      color: inRange
                          ? t.accent.withValues(alpha: 0.08)
                          : null,
                      border: Border(
                        left: BorderSide(
                          color: inRange ? t.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: tile,
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
    final i = _verses.indexWhere((x) => x.verseKey == v.verseKey);
    await showVerseActions(
      context,
      verseKey: v.verseKey,
      arabicPreview: v.arabic,
      reference: _readableTitle(),
      onSelectRange: () => setState(() => _rangeStart = v.verseKey),
      onPlayFrom: i >= 0 ? () => _startFrom(i) : null,
      onRepeat: i >= 0 ? () => _repeatRange(i, i) : null,
    );
  }

  bool _isInPendingRange(String key) => key == _rangeStart;

  void _cancelRange() => setState(() => _rangeStart = null);

  Future<void> _endRange(String endKey) async {
    final start = _rangeStart;
    if (start == null) return;
    final s1 = int.parse(start.split(':')[0]);
    final a1 = int.parse(start.split(':')[1]);
    final s2 = int.parse(endKey.split(':')[0]);
    final a2 = int.parse(endKey.split(':')[1]);
    setState(() => _rangeStart = null);
    if (s1 != s2) return; // plage inter-sourate non gérée
    final from = a1 <= a2 ? a1 : a2;
    final to = a1 <= a2 ? a2 : a1;
    final startKey = '$s1:$from';
    final endK = to == from ? null : '$s1:$to';
    final ia = _verses.indexWhere((v) => v.verseKey == startKey);
    final ib = _verses.indexWhere((v) => v.verseKey == '$s1:$to');
    if (!mounted) return;
    await showVerseActions(
      context,
      verseKey: startKey,
      rangeEnd: endK,
      reference: _readableTitle(),
      onPlayFrom: ia >= 0 ? () => _startFrom(ia) : null,
      onRepeat: (ia >= 0 && ib >= 0) ? () => _repeatRange(ia, ib) : null,
    );
  }

  Future<void> _repeatRange(int startIndex, int endIndex) async {
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    final keys =
        _verses.sublist(startIndex, endIndex + 1).map((v) => v.verseKey).toList();
    _plan = expandPlayback(keys, AudioRepeatMode.range,
        rangeCount: settings.rangeCount.clamp(2, 99));
    if (_plan.isEmpty) return;
    await _playAt(0, settings);
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

/// Bandeau du mode sélection de plage (Reader) : invite + annulation.
class _SelectionBanner extends StatelessWidget {
  const _SelectionBanner({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          LanternSpace.md, LanternSpace.sm, LanternSpace.md, 0),
      padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(LanternSpace.radius),
        border: Border.all(color: t.accent),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app, color: t.accent, size: 20),
          const SizedBox(width: LanternSpace.sm),
          Expanded(
            child: Text('Tapez le verset de fin',
                style: TextStyle(color: t.ink, fontSize: 14)),
          ),
          TextButton(onPressed: onCancel, child: const Text('Annuler')),
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
    this.onPrevSurah,
    this.onNextSurah,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onSpeed;
  final VoidCallback onReciter;
  final VoidCallback? onPrevSurah;
  final VoidCallback? onNextSurah;

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
              tooltip: 'Sourate précédente',
              icon: Icon(Icons.skip_previous,
                  color: onPrevSurah == null ? t.inkFaint : t.inkSoft),
              onPressed: onPrevSurah,
            ),
            IconButton(
              tooltip: playing ? 'Pause' : 'Lecture',
              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle,
                  color: t.accent, size: 34),
              onPressed: onPlayPause,
            ),
            IconButton(
              tooltip: 'Sourate suivante',
              icon: Icon(Icons.skip_next,
                  color: onNextSurah == null ? t.inkFaint : t.inkSoft),
              onPressed: onNextSurah,
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
            IconButton(
              tooltip: 'Paramètres de lecture',
              icon: Icon(Icons.tune, color: t.inkSoft),
              onPressed: () => showPlaybackParams(context),
            ),
          ],
        ),
      ),
    );
  }
}
