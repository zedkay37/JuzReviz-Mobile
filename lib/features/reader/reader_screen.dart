import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/components/review_banner.dart';
import 'package:juzreviz/core/designsystem/components/verse_action_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/playback.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/verse.dart';
import 'package:juzreviz/features/atlas/surah_picker.dart';
import 'package:juzreviz/features/reader/mushaf_view.dart';
import 'package:juzreviz/features/reader/reader_layout_sheet.dart';
import 'package:juzreviz/features/reader/reader_playback_sheet.dart';
import 'package:juzreviz/features/reader/reader_providers.dart';
import 'package:juzreviz/features/reader/widgets/ayah_seal.dart';
import 'package:juzreviz/features/reader/widgets/interlinear_verse.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Étude silencieuse (Coran, mot-à-mot) vs récitation (Réciter, écoute karaoké).
enum ReaderMode { study, recitation }

typedef _ReaderConfig = ({
  bool wbw,
  bool trans,
  String lang,
  bool latin,
  VeilMode veil,
  int veilWords,
  bool focus,
  bool wordAudio,
  double fontSize,
});

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.selection,
    this.mode = ReaderMode.study,
  });
  final Selection selection;

  /// Étude silencieuse ou récitation (audio + karaoké dès l'ouverture).
  final ReaderMode mode;

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

  /// Nombre d'éléments en tête de liste (en-tête de sourate) : décale les index.
  int _lead = 0;
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

  // Boucle sur l'âyah courante (rejoue le verset au lieu d'avancer).
  bool _loopAyah = false;

  // Sourate actuellement visible (pour la navigation inter-sourates en haut).
  int? _visibleSurah;

  @override
  void initState() {
    super.initState();
    _autoPlayPending = widget.mode == ReaderMode.recitation;
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
        .fold<int>(_verses.length + _lead, (a, b) => a < b ? a : b);
    final vi = (firstIndex - _lead).clamp(0, _verses.length - 1);
    final key = _verses[vi].verseKey;
    final surah = _verses[vi].surah;
    if (surah != _visibleSurah && mounted) {
      setState(() => _visibleSurah = surah);
    }
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
    // Boucle âyah : rejoue le verset courant sans avancer ni maîtriser.
    if (_loopAyah && _activeKey != null) {
      ref
          .read(audioControllerProvider)
          .playVerse(
            settings.reciter,
            _activeKey!,
            rate: settings.playbackRate,
          );
      return;
    }
    final finished = _ptr >= 0 && _ptr < _plan.length ? _plan[_ptr] : null;
    final isLastOccurrence =
        finished != null &&
        (_ptr + 1 >= _plan.length || _plan[_ptr + 1] != finished);
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
      final atSurahEnd =
          _verses.isNotEmpty && finished == _verses.last.verseKey;
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
    _plan = expandPlayback(
      keys,
      settings.repeatMode,
      repeatCount: settings.repeatCount,
      rangeCount: settings.rangeCount,
    );
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
    final ok = await audio.playVerse(
      settings.reciter,
      key,
      rate: settings.playbackRate,
    );
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
      index: index + _lead,
      duration: LanternMotion.medium,
      curve: LanternMotion.emphasized,
      alignment: scrollAlignmentFor(
        settings.scrollTempo,
        settings.scrollTempoStrength,
      ),
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

  /// Titre : sélecteur si une seule sourate, navigation inter-sourates sinon.
  Widget _buildTitle() {
    final surahs = _distinctSurahs();
    if (surahs.length <= 1) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _changeSurah,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(_readableTitle(), overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      );
    }
    final cur = _visibleSurah ?? surahs.first;
    final i = surahs.indexOf(cur);
    final prev = i > 0 ? surahs[i - 1] : null;
    final next = i >= 0 && i < surahs.length - 1 ? surahs[i + 1] : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Sourate précédente',
          icon: const Icon(Icons.chevron_left),
          onPressed: prev == null ? null : () => _gotoSelectionSurah(prev),
        ),
        Flexible(
          child: Text(
            _surahName(cur),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Sourate suivante',
          icon: const Icon(Icons.chevron_right),
          onPressed: next == null ? null : () => _gotoSelectionSurah(next),
        ),
      ],
    );
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

  /// Mode récitation (audio mis en avant) vs lecture (contrôles de défilement).
  bool get _recitation => widget.mode == ReaderMode.recitation;

  /// Sourates distinctes présentes dans la sélection (ordre de lecture).
  List<int> _distinctSurahs() {
    final out = <int>[];
    for (final v in _verses) {
      if (out.isEmpty || out.last != v.surah) out.add(v.surah);
    }
    return out;
  }

  String _surahName(int surah) {
    final m = ref
        .read(surahMetasProvider)
        .valueOrNull
        ?.where((x) => x.number == surah)
        .firstOrNull;
    return m?.transliteration ?? 'Sourate $surah';
  }

  /// Défile jusqu'au début d'une sourate de la sélection.
  void _gotoSelectionSurah(int surah) {
    final idx = _verses.indexWhere((v) => v.surah == surah);
    if (idx < 0 || !_scroll.isAttached) return;
    setState(() => _visibleSurah = surah);
    _scroll.scrollTo(
      index: idx + _lead,
      alignment: 0.02,
      duration: LanternMotion.medium,
      curve: LanternMotion.emphasized,
    );
  }

  /// Défile d'un « écran » de versets (set d'âyât suivant/précédent).
  void _scrollSet(int delta) {
    if (_verses.isEmpty || !_scroll.isAttached) return;
    final positions = _positions.itemPositions.value;
    if (positions.isEmpty) return;
    final indices = positions.map((p) => p.index);
    final first = indices.reduce((a, b) => a < b ? a : b);
    final last = indices.reduce((a, b) => a > b ? a : b);
    final span = (last - first) < 1 ? 1 : (last - first);
    final target = (delta > 0 ? last : first - span).clamp(
      0,
      _verses.length - 1,
    );
    _scroll.scrollTo(
      index: target,
      alignment: 0.02,
      duration: LanternMotion.medium,
      curve: LanternMotion.emphasized,
    );
  }

  Future<void> _playWordAudio(Verse v, int position) async {
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    HapticFeedback.selectionClick();
    final ok = await ref
        .read(audioControllerProvider)
        .playUrl(
          wordAudioUrl(v.verseKey, position),
          rate: settings.playbackRate,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio du mot indisponible.')),
      );
    }
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
    final listMin = positions
        .where((p) => p.itemTrailingEdge > 0)
        .map((p) => p.index)
        .fold<int>(_verses.length + _lead, (a, b) => a < b ? a : b);
    return (listMin - _lead).clamp(0, _verses.isEmpty ? 0 : _verses.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final cfg = ref.watch(
      settingsControllerProvider.select((s) {
        final v = s.valueOrNull ?? const Settings();
        // Mot-à-mot et traduction sont des réglages directs (ajustables depuis le
        // menu verset). La disposition n'est qu'un préréglage de ces deux-là.
        return (
          wbw: v.readerWordByWord,
          trans: v.readerTranslation,
          lang: v.contentLang,
          latin: v.latinAyahNumbers,
          veil: v.veilMode,
          veilWords: v.veilWords,
          focus: v.focusMode,
          wordAudio: v.wordAudio,
          fontSize: (30.0 * v.fontScale).clamp(20.0, 54.0),
        );
      }),
    );
    final versesAsync = ref.watch(readerVersesProvider(_selection));
    final focus = _focus || cfg.focus;
    final layout = ref.watch(
      settingsControllerProvider.select(
        (s) => readerLayoutFromString(
          (s.valueOrNull ?? const Settings()).readerLayout,
        ),
      ),
    );
    final mushafReady = ref.watch(mushafAvailableProvider).valueOrNull ?? false;
    final useMushaf =
        !_recitation &&
        mushafReady &&
        (layout == ReaderLayout.mushafMadni ||
            layout == ReaderLayout.mushafTajweed);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return LanternScaffold(
      safeArea: false,
      appBar: focus
          ? null
          : AppBar(
              titleSpacing: 8,
              title: _buildTitle(),
              actions: _recitation
                  ? [
                      if (_ayahPosition() case final pos?)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _AyahPositionButton(
                            ayah: pos.$1,
                            total: pos.$2,
                            onTap: () => _showAyahJump(context),
                          ),
                        ),
                    ]
                  : [
                      if (_ayahPosition() case final pos?)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _AyahPositionButton(
                            ayah: pos.$1,
                            total: pos.$2,
                            onTap: () => _showAyahJump(context),
                          ),
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
      bottomNavigationBar: useMushaf ? null : _bottomBar(),
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
                  if (_autoPlayPending) {
                    _autoPlayPending = false;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _startFrom(0);
                    });
                  }
                  if (useMushaf) {
                    return MushafView(
                      initialVerseKey: verses.first.verseKey,
                      onVerseLongPress: (k) =>
                          showVerseActions(context, verseKey: k),
                    );
                  }
                  _resolveResume(verses);
                  if (focus || _recitation) return _buildList(verses, cfg);
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
          ],
        ),
      ),
    );
  }

  /// Barre du bas, en vraie zone de Scaffold (jamais superposée au contenu).
  /// Récitation = transport audio ; lecture = défilement (+ stop ponctuel).
  Widget _bottomBar() {
    if (_recitation) {
      return _AudioBar(
        playing: _playing,
        onPlayPause: _togglePlay,
        onPrevAyah: () => _stepAyah(-1),
        onNextAyah: () => _stepAyah(1),
        loopOn: _loopAyah,
        onToggleLoop: () => setState(() => _loopAyah = !_loopAyah),
      );
    }
    if (_playing || _ptr >= 0) {
      return _StopBar(
        playing: _playing,
        onPlayPause: _togglePlay,
        onStop: _stopAudio,
      );
    }
    return _ReadingNavBar(
      onPrev: () => _scrollSet(-1),
      onNext: () => _scrollSet(1),
    );
  }

  void _resolveResume(List<Verse> verses) {
    if (_resumeResolved) return;
    final s = ref.read(settingsControllerProvider).valueOrNull;
    if (s == null) {
      return; // réessaie au prochain build (settings pas encore prêt)
    }
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
        LanternSpace.md,
        LanternSpace.sm,
        LanternSpace.md,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(Icons.history, size: 18, color: t.accent),
          label: Text('Reprendre · verset $ayah'),
          onPressed: () {
            _dismissResume();
            final settings =
                ref.read(settingsControllerProvider).valueOrNull ??
                const Settings();
            _scrollToKey(key, settings);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<Verse> verses, _ReaderConfig cfg) {
    // En-tête de sourate (titre + basmallah) comme 1er élément scrollable.
    _lead = (verses.isNotEmpty && verses.first.ayah == 1) ? 1 : 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Lecture adaptative : largeur de colonne bornée sur tablette/paysage.
        final maxWidth = constraints.maxWidth > 720.0
            ? 720.0
            : constraints.maxWidth;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ScrollablePositionedList.builder(
              itemScrollController: _scroll,
              itemPositionsListener: _positions,
              initialScrollIndex: 0,
              padding: const EdgeInsets.symmetric(vertical: LanternSpace.lg),
              itemCount: verses.length + _lead,
              itemBuilder: (context, i) {
                if (_lead == 1 && i == 0) {
                  return _SurahHeaderBox(surah: verses.first.surah);
                }
                final v = verses[i - _lead];
                final t = context.lantern;
                final selecting = _rangeStart != null;
                final inRange = selecting && _isInPendingRange(v.verseKey);
                final tile = RepaintBoundary(
                  child: _recitation
                      ? _RecitationVerseTile(
                          verse: v,
                          active: _activeKey == v.verseKey,
                          latinAyahNumbers: cfg.latin,
                          lang: cfg.lang,
                          showTranslation: cfg.trans,
                          onLongPress: () => _capture(v),
                        )
                      : InterlinearVerse(
                          verse: v,
                          wordByWord: cfg.wbw,
                          showTranslation: cfg.trans,
                          lang: cfg.lang,
                          latinAyahNumbers: cfg.latin,
                          veilMode: cfg.veil,
                          veilWords: cfg.veilWords,
                          fontSize: cfg.fontSize,
                          active: _activeKey == v.verseKey,
                          // Tap sur un mot = audio de prononciation du mot
                          // (réglage « Audio-mot » explicite).
                          onWordTap: selecting || !cfg.wordAudio
                              ? null
                              : (pos) => _playWordAudio(v, pos),
                          onLongPress: selecting ? null : () => _capture(v),
                        ),
                );
                if (!selecting) return tile;
                // Mode sélection de plage : tap = borne de fin.
                return GestureDetector(
                  onTap: () => _endRange(v.verseKey),
                  child: Container(
                    decoration: BoxDecoration(
                      color: inRange ? t.accent.withValues(alpha: 0.08) : null,
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

  /// Lit une seule âyah puis s'arrête (depuis le menu verset).
  Future<void> _playSingle(String key) async {
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    _plan = [key];
    await _playAt(0, settings);
  }

  Future<void> _stopAudio() async {
    _pauseTimer?.cancel();
    await ref.read(audioControllerProvider).stop();
    if (mounted) {
      setState(() {
        _playing = false;
        _activeKey = null;
        _ptr = -1;
        _plan = const [];
      });
    }
  }

  Future<void> _capture(Verse v) async {
    final i = _verses.indexWhere((x) => x.verseKey == v.verseKey);
    await showVerseActions(
      context,
      verseKey: v.verseKey,
      arabicPreview: v.arabic,
      reference: _readableTitle(),
      showDisplay: true,
      onSelectRange: () => setState(() => _rangeStart = v.verseKey),
      onPlaySingle: () => _playSingle(v.verseKey),
      onPlayFrom: i >= 0 ? () => _startFrom(i) : null,
      onRepeat: i >= 0 ? () => _repeatRange(i, i) : null,
      onStop: _playing ? _stopAudio : null,
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

  /// Position (âyah courante, dernière âyah de la même sourate) pour le
  /// bouton de saut rapide en mode Réciter.
  (int, int)? _ayahPosition() {
    if (_verses.isEmpty) return null;
    final idx = (_activeKey != null
            ? _verses.indexWhere((v) => v.verseKey == _activeKey)
            : _firstVisibleIndex())
        .clamp(0, _verses.length - 1);
    final v = _verses[idx];
    final last = _verses.lastWhere((x) => x.surah == v.surah, orElse: () => v);
    return (v.ayah, last.ayah);
  }

  /// Feuille discrète : glisser pour sauter à une âyah de la sourate en cours.
  Future<void> _showAyahJump(BuildContext context) async {
    if (_verses.isEmpty) return;
    final curIdx = (_activeKey != null
            ? _verses.indexWhere((v) => v.verseKey == _activeKey)
            : _firstVisibleIndex())
        .clamp(0, _verses.length - 1);
    final surah = _verses[curIdx].surah;
    final indices = [
      for (var i = 0; i < _verses.length; i++)
        if (_verses[i].surah == surah) i,
    ];
    if (indices.length < 2) return;
    final picked = await showLanternSheet<int>(
      context,
      builder: (_) => _AyahJumpSheet(
        verses: _verses,
        indices: indices,
        initialIndex: curIdx,
      ),
    );
    if (picked == null) return;
    if (_recitation) {
      // Réciter : sauter = reprendre l'écoute à partir de là.
      await _startFrom(picked);
    } else {
      // Coran : sauter = simple défilement, sans déclencher l'audio.
      final settings =
          ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
      _scrollToKey(_verses[picked].verseKey, settings);
    }
  }

  /// Navigue d'une âyah (audio) : ±1 puis joue à partir de là.
  Future<void> _stepAyah(int delta) async {
    if (_verses.isEmpty) return;
    final curKey = _activeKey;
    var idx = curKey != null
        ? _verses.indexWhere((v) => v.verseKey == curKey)
        : -1;
    if (idx < 0) idx = _firstVisibleIndex();
    final next = (idx + delta).clamp(0, _verses.length - 1);
    await _startFrom(next);
  }

  Future<void> _repeatRange(int startIndex, int endIndex) async {
    final settings =
        ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    final keys = _verses
        .sublist(startIndex, endIndex + 1)
        .map((v) => v.verseKey)
        .toList();
    _plan = expandPlayback(
      keys,
      AudioRepeatMode.range,
      rangeCount: settings.rangeCount.clamp(2, 99),
    );
    if (_plan.isEmpty) return;
    await _playAt(0, settings);
  }
}

/// En-tête de sourate (titre calligraphié + basmallah) au début d'une sourate.
class _SurahHeaderBox extends ConsumerWidget {
  const _SurahHeaderBox({required this.surah});
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final meta = ref
        .watch(surahMetasProvider)
        .valueOrNull
        ?.where((m) => m.number == surah)
        .firstOrNull;
    if (meta == null) return const SizedBox.shrink();
    final showBasmalah = surah != 1 && surah != 9;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LanternSpace.lg,
        LanternSpace.md,
        LanternSpace.lg,
        LanternSpace.sm,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: LanternSpace.lg,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LanternSpace.radius),
              border: Border.all(color: t.accent.withValues(alpha: 0.55)),
            ),
            child: Column(
              children: [
                Text(
                  'سورة ${meta.arabicName}',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: t.accent,
                    fontSize: 24,
                    height: 1.35,
                    fontFamily: t.arabicFamily,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meta.transliteration} · '
                  '${meta.revelation == Revelation.meccan ? 'Mecquoise' : 'Médinoise'}'
                  ' · ${meta.ayahCount} versets',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.inkSoft,
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (showBasmalah)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 18),
              child: Text(
                'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: t.ink,
                  fontSize: 26,
                  height: 1.55,
                  fontFamily: t.arabicFamily,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Verset en mode Réciter : arabe seul en grand, surlignage « karaoké » du
/// verset en cours, traduction affichée seulement pour le verset actif.
class _RecitationVerseTile extends StatelessWidget {
  const _RecitationVerseTile({
    required this.verse,
    required this.active,
    required this.latinAyahNumbers,
    required this.lang,
    required this.showTranslation,
    this.onLongPress,
  });

  final Verse verse;
  final bool active;
  final bool latinAyahNumbers;
  final String lang;
  final bool showTranslation;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final translation = verse.translation(lang);
    final showTrans = active && showTranslation && translation.isNotEmpty;
    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: LanternMotion.medium,
        curve: LanternMotion.emphasized,
        margin: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: LanternSpace.lg,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: LanternSpace.md,
          vertical: LanternSpace.lg,
        ),
        decoration: BoxDecoration(
          color: active ? t.surfaceHigh : null,
          borderRadius: BorderRadius.circular(LanternSpace.radius),
          border: active
              ? Border.all(color: t.accent.withValues(alpha: 0.5))
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.16),
                    blurRadius: 28,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: LanternMotion.medium,
                    curve: LanternMotion.emphasized,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: t.arabicFamily,
                      fontSize: active ? 32 : 22,
                      height: 1.9,
                      color: active ? t.ink : t.inkSoft,
                    ),
                    child: Text(verse.arabic, textDirection: TextDirection.rtl),
                  ),
                ),
                const SizedBox(width: LanternSpace.sm),
                AnimatedScale(
                  duration: LanternMotion.medium,
                  curve: LanternMotion.emphasized,
                  scale: active ? 1.0 : 0.74,
                  child: AyahSeal(ayah: verse.ayah, latin: latinAyahNumbers, size: 30),
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: LanternMotion.medium,
              child: !showTrans
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(verse.verseKey),
                      padding: const EdgeInsets.only(top: LanternSpace.md),
                      child: Text(
                        translation,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: t.inkSoft,
                          fontSize: 15,
                          height: 1.4,
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

/// Pastille « 13 / 120 » — position dans la sourate, tap = saut rapide.
class _AyahPositionButton extends StatelessWidget {
  const _AyahPositionButton({
    required this.ayah,
    required this.total,
    required this.onTap,
  });
  final int ayah;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Material(
      color: t.surfaceHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            '$ayah / $total',
            style: TextStyle(
              color: t.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille de saut rapide : un curseur, relâcher = navigue et referme.
class _AyahJumpSheet extends StatefulWidget {
  const _AyahJumpSheet({
    required this.verses,
    required this.indices,
    required this.initialIndex,
  });
  final List<Verse> verses;
  final List<int> indices;
  final int initialIndex;

  @override
  State<_AyahJumpSheet> createState() => _AyahJumpSheetState();
}

class _AyahJumpSheetState extends State<_AyahJumpSheet> {
  late double _pos = widget.indices
      .indexOf(widget.initialIndex)
      .clamp(0, widget.indices.length - 1)
      .toDouble();

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final verse = widget.verses[widget.indices[_pos.round()]];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ALLER À L’ÂYAH',
          style: TextStyle(
            color: t.inkFaint,
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${verse.ayah}',
          style: TextStyle(
            color: t.accent,
            fontSize: 40,
            fontWeight: FontWeight.w600,
          ),
        ),
        Slider(
          value: _pos,
          min: 0,
          max: (widget.indices.length - 1).toDouble(),
          divisions: widget.indices.length - 1,
          activeColor: t.accent,
          onChanged: (v) => setState(() => _pos = v),
          onChangeEnd: (v) =>
              Navigator.of(context).pop(widget.indices[v.round()]),
        ),
      ],
    );
  }
}

/// Contrôle discret d'écoute ponctuelle en mode lecture (pause + arrêt).
class _StopBar extends StatelessWidget {
  const _StopBar({
    required this.playing,
    required this.onPlayPause,
    required this.onStop,
  });
  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(LanternSpace.md),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: playing ? 'Pause' : 'Reprendre',
              icon: Icon(
                playing ? Icons.pause_circle : Icons.play_circle,
                color: t.accent,
                size: 32,
              ),
              onPressed: onPlayPause,
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: const Text('Arrêter'),
              style: TextButton.styleFrom(foregroundColor: t.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre de lecture (mode Lire) : défilement par set d'âyât, pas d'audio.
/// Le focus se pilote uniquement depuis l'icône de l'AppBar (pas de doublon).
class _ReadingNavBar extends StatelessWidget {
  const _ReadingNavBar({
    required this.onPrev,
    required this.onNext,
  });
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(LanternSpace.md),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Précédent',
              icon: Icon(Icons.keyboard_arrow_up, color: t.ink),
              onPressed: onPrev,
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.accentInk,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onNext,
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              label: const Text('Suivant'),
            ),
          ],
        ),
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
        LanternSpace.md,
        LanternSpace.sm,
        LanternSpace.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: LanternSpace.md,
        vertical: 10,
      ),
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
            child: Text(
              'Tapez le verset de fin',
              style: TextStyle(color: t.ink, fontSize: 14),
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Annuler')),
        ],
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  const _AudioBar({
    required this.playing,
    required this.onPlayPause,
    required this.onPrevAyah,
    required this.onNextAyah,
    required this.loopOn,
    required this.onToggleLoop,
  });

  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevAyah;
  final VoidCallback onNextAyah;
  final bool loopOn;
  final VoidCallback onToggleLoop;

  Widget _barIcon(
    IconData icon, {
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
    double size = 24,
  }) => IconButton(
    visualDensity: VisualDensity.compact,
    tooltip: tooltip,
    icon: Icon(icon, color: color, size: size),
    onPressed: onPressed,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(LanternSpace.md),
        padding: const EdgeInsets.symmetric(
          horizontal: LanternSpace.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceHigh),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          children: [
            const Spacer(),
            _barIcon(
              Icons.skip_previous,
              color: t.inkSoft,
              onPressed: onPrevAyah,
              tooltip: 'Âyah précédente',
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: playing ? 'Pause' : 'Lecture',
              icon: Icon(
                playing ? Icons.pause_circle : Icons.play_circle,
                color: t.accent,
                size: 40,
              ),
              onPressed: onPlayPause,
            ),
            const SizedBox(width: 4),
            _barIcon(
              Icons.skip_next,
              color: t.inkSoft,
              onPressed: onNextAyah,
              tooltip: 'Âyah suivante',
            ),
            const Spacer(),
            _barIcon(
              Icons.repeat_one,
              color: loopOn ? t.accent : t.inkSoft,
              onPressed: onToggleLoop,
              tooltip: 'Boucler l’âyah',
            ),
            _barIcon(
              Icons.tune,
              color: t.inkSoft,
              onPressed: () => showPlaybackParams(context),
              tooltip: 'Paramètres de lecture',
            ),
          ],
        ),
      ),
    );
  }
}
