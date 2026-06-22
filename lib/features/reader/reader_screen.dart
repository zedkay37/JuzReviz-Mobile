import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/capture_bar.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/verse.dart';
import 'package:juzreviz/features/reader/reader_providers.dart';
import 'package:juzreviz/features/reader/widgets/interlinear_verse.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.selection});
  final Selection selection;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  bool _focus = false;
  bool _chromeVisible = true;
  String? _playingKey;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final settings = ref.watch(settingsControllerProvider).valueOrNull ??
        const Settings();
    final versesAsync = ref.watch(readerVersesProvider(widget.selection));
    final focus = _focus || settings.focusMode;

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
                data: (verses) => verses.isEmpty
                    ? const LanternEmpty(message: 'Aucun verset.')
                    : _buildList(verses, settings),
              ),
            ),
            if (focus)
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                right: 8,
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: LanternMotion.fast,
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
                duration: LanternMotion.medium,
                curve: LanternMotion.emphasized,
                child: _AudioBar(
                  settings: settings,
                  playing: _playingKey != null,
                  onPlayPause: () => _togglePlay(verseKey: _firstKey(versesAsync)),
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

  String? _firstKey(AsyncValue<List<Verse>> async) =>
      async.valueOrNull?.firstOrNull?.verseKey;

  Widget _buildList(List<Verse> verses, Settings s) {
    return ListView.separated(
      padding: const EdgeInsets.only(
          top: LanternSpace.md, bottom: 120, left: 4, right: 4),
      itemCount: verses.length,
      separatorBuilder: (_, _) => Divider(
          height: 1, color: context.lantern.surfaceHigh.withValues(alpha: 0.6)),
      itemBuilder: (context, i) {
        final v = verses[i];
        return InterlinearVerse(
          verse: v,
          wordByWord: s.readerWordByWord,
          showTranslation: s.readerTranslation,
          glossLang: s.glossLang,
          translationLang: s.translationLang,
          latinAyahNumbers: s.latinAyahNumbers,
          veilMode: s.veilMode,
          veilWords: s.veilWords,
          highlightedPosition: null,
          onWordTap: s.wordAudio ? (pos) {} : null,
          onLongPress: () => _capture(v),
        );
      },
    );
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
          _togglePlay(verseKey: v.verseKey);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _togglePlay({String? verseKey}) async {
    final audio = ref.read(audioControllerProvider);
    if (_playingKey != null) {
      await audio.pause();
      setState(() => _playingKey = null);
      return;
    }
    if (verseKey == null) return;
    final s = ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    final ok = await audio.playVerse(s.reciter, verseKey, rate: s.playbackRate);
    if (!mounted) return;
    setState(() => _playingKey = ok ? verseKey : null);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio indisponible hors-ligne.')),
      );
    }
  }

  void _cycleSpeed() {
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final s = ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    const steps = [0.75, 1.0, 1.25, 1.5, 2.0];
    final idx = steps.indexWhere((x) => x >= s.playbackRate);
    final next = steps[(idx + 1) % steps.length];
    ctrl.edit((p) => p.copyWith(playbackRate: next));
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

class _AudioBar extends StatelessWidget {
  const _AudioBar({
    required this.settings,
    required this.playing,
    required this.onPlayPause,
    required this.onSpeed,
    required this.onReciter,
  });

  final Settings settings;
  final bool playing;
  final VoidCallback onPlayPause;
  final VoidCallback onSpeed;
  final VoidCallback onReciter;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(LanternSpace.md),
        padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md, vertical: 6),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.surfaceHigh),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18)],
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle,
                  color: t.accent, size: 34),
              onPressed: onPlayPause,
            ),
            TextButton(
              onPressed: onReciter,
              child: Text(reciterById(settings.reciter).name.split(' ').first,
                  style: TextStyle(color: t.ink)),
            ),
            const Spacer(),
            TextButton(
              onPressed: onSpeed,
              child: Text('${settings.playbackRate}Ã—',
                  style: TextStyle(color: t.inkSoft)),
            ),
          ],
        ),
      ),
    );
  }
}
