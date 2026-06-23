import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/core/common/clock.dart';
import 'package:juzreviz/data/audio/audio_cache.dart';
import 'package:juzreviz/data/audio/audio_controller.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/corpus/corpus_repository.dart';
import 'package:juzreviz/data/mastery/mastery_repository.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';
import 'package:juzreviz/data/mushaf/mushaf_page.dart';
import 'package:juzreviz/data/mushaf/mushaf_repository.dart';
import 'package:juzreviz/data/playlists/playlist.dart';
import 'package:juzreviz/data/playlists/playlists_repository.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/data/settings/settings_repository.dart';
import 'package:juzreviz/data/tafsir/tafsir_repository.dart';
import 'package:juzreviz/domain/mastery/mastery.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/usecase/atlas_heat.dart';
import 'package:juzreviz/domain/usecase/decay_queue.dart';
import 'package:juzreviz/domain/usecase/juz_index.dart';
import 'package:juzreviz/domain/usecase/streak.dart';

// --- Infrastructure ---

final jsonStoreProvider = Provider<JsonStore>((ref) => FileJsonStore());
final clockProvider = Provider<Clock>((ref) => const SystemClock());

final corpusRepositoryProvider =
    Provider<CorpusRepository>((ref) => CorpusRepository());
final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.read(jsonStoreProvider)));
final masteryRepositoryProvider = Provider<MasteryRepository>(
    (ref) => MasteryRepository(ref.read(jsonStoreProvider)));
final playlistsRepositoryProvider = Provider<PlaylistsRepository>(
    (ref) => PlaylistsRepository(ref.read(jsonStoreProvider)));

final audioCacheRepositoryProvider =
    Provider<AudioCacheRepository>((ref) => AudioCacheRepository());

final audioControllerProvider = Provider<AudioController>((ref) {
  final cache = ref.read(audioCacheRepositoryProvider);
  final c = AudioController(
    resolver: (reciterId, verseKey) async =>
        (await cache.cachedFile(reciterId, verseKey))?.path,
  );
  ref.onDispose(c.dispose);
  return c;
});

// --- Téléchargements audio offline (sourate / juz / Coran) ---

/// État/octets d'une sourate pour un récitateur (cache offline).
final surahDownloadStatusProvider = FutureProvider.family<
    ({bool done, int bytes}), ({String reciter, int surah})>((ref, a) async {
  final metas = await ref.watch(surahMetasProvider.future);
  final meta = metas.firstWhere((m) => m.number == a.surah);
  final keys = surahVerseKeys(a.surah, meta.ayahCount);
  final repo = ref.read(audioCacheRepositoryProvider);
  final done = await repo.areVersesDownloaded(a.reciter, keys);
  final bytes = await repo.surahBytes(a.reciter, a.surah);
  return (done: done, bytes: bytes);
});

/// Un juz est-il intégralement en cache pour ce récitateur ?
final juzDownloadStatusProvider =
    FutureProvider.family<bool, ({String reciter, int juz})>((ref, a) async {
  final metas = await ref.watch(surahMetasProvider.future);
  final keys = juzVerseKeys(a.juz, metas);
  return ref.read(audioCacheRepositoryProvider).areVersesDownloaded(a.reciter, keys);
});

/// Le Coran entier est-il en cache pour ce récitateur ?
final quranDownloadStatusProvider =
    FutureProvider.family<bool, String>((ref, reciter) async {
  final metas = await ref.watch(surahMetasProvider.future);
  return ref
      .read(audioCacheRepositoryProvider)
      .areVersesDownloaded(reciter, quranVerseKeys(metas));
});

final totalCacheBytesProvider = FutureProvider<int>(
    (ref) => ref.read(audioCacheRepositoryProvider).totalBytes());

/// État de téléchargement courant : un seul groupe actif à la fois.
typedef DownloadsState = ({String? active, double progress});

final downloadsControllerProvider =
    NotifierProvider<DownloadsController, DownloadsState>(
        DownloadsController.new);

class DownloadsController extends Notifier<DownloadsState> {
  bool _cancel = false;

  @override
  DownloadsState build() => (active: null, progress: 0);

  void _invalidateAll() {
    ref.invalidate(surahDownloadStatusProvider);
    ref.invalidate(juzDownloadStatusProvider);
    ref.invalidate(quranDownloadStatusProvider);
    ref.invalidate(totalCacheBytesProvider);
  }

  /// Télécharge un groupe identifié ([id] : `s2`, `j5`, `quran`…).
  Future<void> download(String reciterId, String id, List<String> keys) async {
    if (state.active != null) return; // une à la fois
    _cancel = false;
    state = (active: id, progress: 0);
    await ref.read(audioCacheRepositoryProvider).downloadSurah(
          reciterId,
          keys,
          onProgress: (d, t) =>
              state = (active: id, progress: t == 0 ? 0 : d / t),
          cancelled: () => _cancel,
        );
    state = (active: null, progress: 0);
    _invalidateAll();
  }

  void cancel() => _cancel = true;

  Future<void> deleteKeys(String reciterId, List<String> keys) async {
    await ref.read(audioCacheRepositoryProvider).deleteVerses(reciterId, keys);
    _invalidateAll();
  }

  Future<void> clearAll() async {
    await ref.read(audioCacheRepositoryProvider).clearAll();
    _invalidateAll();
  }
}

final tafsirRepositoryProvider =
    Provider<TafsirRepository>((ref) => TafsirRepository());

// --- Moushaf (pages QPC, optionnel) ---

final mushafRepositoryProvider =
    Provider<MushafRepository>((ref) => MushafRepository());

/// Le pack moushaf (pages + polices QCF) est-il embarqué ?
final mushafAvailableProvider =
    FutureProvider<bool>((ref) => ref.read(mushafRepositoryProvider).isAvailable());

/// Lignes d'une page de moushaf (1-indexée).
final mushafPageProvider = FutureProvider.family<List<MushafLine>, int>(
    (ref, page) => ref.read(mushafRepositoryProvider).linesForPage(page));

/// Charge la police QCF de la page (lazy, une seule fois).
final mushafFontProvider = FutureProvider.family<void, int>(
    (ref, page) => ref.read(mushafRepositoryProvider).ensureFont(page));

final mushafPageCountProvider =
    FutureProvider<int>((ref) => ref.read(mushafRepositoryProvider).pageCount());

/// Tafsir d'un verset, par langue (lazy, décompressé+caché par le repo).
final verseTafsirProvider =
    FutureProvider.family<String, ({String lang, String verseKey})>(
  (ref, a) => ref.read(tafsirRepositoryProvider).verseTafsir(a.lang, a.verseKey),
);

// --- Settings ---

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, Settings>(SettingsController.new);

class SettingsController extends AsyncNotifier<Settings> {
  @override
  Future<Settings> build() => ref.read(settingsRepositoryProvider).load();

  Future<void> edit(Settings Function(Settings) mutate) async {
    final next = mutate(state.valueOrNull ?? const Settings());
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

// --- Mastery ---

final masteryControllerProvider =
    AsyncNotifierProvider<MasteryController, MasteryState>(
        MasteryController.new);

class MasteryController extends AsyncNotifier<MasteryState> {
  @override
  Future<MasteryState> build() => ref.read(masteryRepositoryProvider).load();

  int _now() => ref.read(clockProvider).nowMs();
  MasteryState get _s => state.valueOrNull ?? const MasteryState();

  Future<void> _persist(MasteryState next) async {
    state = AsyncData(next);
    await ref.read(masteryRepositoryProvider).save(next);
  }

  Future<void> markFragile(String key) {
    final fragile = {..._s.fragile};
    fragile[key] = Fragile(_now(), (fragile[key]?.count ?? 0) + 1);
    return _persist(_s.copyWith(fragile: fragile));
  }

  Future<void> markMastered(String key) {
    final mastered = {..._s.mastered};
    mastered[key] = Mastered(_now());
    return _persist(_s.copyWith(mastered: mastered));
  }

  Future<void> clearDifficulty(String key) {
    final fragile = {..._s.fragile}..remove(key);
    return _persist(_s.copyWith(fragile: fragile));
  }

  Future<void> resetVerse(String key) {
    final fragile = {..._s.fragile}..remove(key);
    final mastered = {..._s.mastered}..remove(key);
    return _persist(_s.copyWith(fragile: fragile, mastered: mastered));
  }

  /// Cicatrice manuelle (toggle) : pose/retire le badge permanent.
  Future<void> toggleScar(String key) {
    final scarred = {..._s.scarred};
    scarred.contains(key) ? scarred.remove(key) : scarred.add(key);
    return _persist(_s.copyWith(scarred: scarred));
  }

  Future<void> toggleMemorized(int surah) {
    final set = {..._s.memorizedSurahs};
    set.contains(surah) ? set.remove(surah) : set.add(surah);
    return _persist(_s.copyWith(memorizedSurahs: set));
  }

  Future<void> recordSession() {
    final days = {..._s.sessionDays, dayKey(_now())};
    return _persist(_s.copyWith(sessionDays: days));
  }
}

// --- Playlists ---

final playlistsControllerProvider =
    AsyncNotifierProvider<PlaylistsController, List<Playlist>>(
        PlaylistsController.new);

class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() => ref.read(playlistsRepositoryProvider).load();

  List<Playlist> get _s => state.valueOrNull ?? const [];
  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _persist(List<Playlist> next) async {
    state = AsyncData(next);
    await ref.read(playlistsRepositoryProvider).save(next);
  }

  Future<Playlist> create(String name) async {
    final p = Playlist(id: _id(), name: name);
    await _persist([..._s, p]);
    return p;
  }

  Future<void> rename(String id, String name) =>
      _persist([for (final p in _s) if (p.id == id) p.copyWith(name: name) else p]);

  Future<void> delete(String id) =>
      _persist([for (final p in _s) if (p.id != id) p]);

  Future<void> addItem(String playlistId, Selection selection) {
    final item = PlaylistItem(id: _id(), selection: selection, label: selection.label);
    return _persist([
      for (final p in _s)
        if (p.id == playlistId) p.copyWith(items: [...p.items, item]) else p,
    ]);
  }

  /// Ajoute le passage s'il est absent, le retire s'il est présent (idempotent).
  Future<void> togglePassage(String playlistId, Selection selection) {
    return _persist([
      for (final p in _s)
        if (p.id == playlistId)
          p.copyWith(
            items: p.items.any((i) => i.selection == selection)
                ? [for (final i in p.items) if (i.selection != selection) i]
                : [
                    ...p.items,
                    PlaylistItem(
                        id: _id(), selection: selection, label: selection.label),
                  ],
          )
        else
          p,
    ]);
  }

  /// Crée une playlist et y ajoute le passage en un seul geste.
  Future<void> createWithPassage(String name, Selection selection) async {
    final item = PlaylistItem(id: _id(), selection: selection, label: selection.label);
    await _persist([..._s, Playlist(id: _id(), name: name, items: [item])]);
  }

  /// Crée une playlist à partir d'une sélection multiple (composeur).
  Future<void> createWithSelections(
      String name, List<Selection> selections) async {
    final items = [
      for (final s in selections)
        PlaylistItem(id: _id(), selection: s, label: s.label),
    ];
    await _persist([..._s, Playlist(id: _id(), name: name, items: items)]);
  }

  Future<void> removeItem(String playlistId, String itemId) => _persist([
        for (final p in _s)
          if (p.id == playlistId)
            p.copyWith(items: [for (final i in p.items) if (i.id != itemId) i])
          else
            p,
      ]);

  Future<void> reorderItems(String playlistId, int oldIndex, int newIndex) {
    return _persist([
      for (final p in _s)
        if (p.id == playlistId)
          p.copyWith(items: _reorder(p.items, oldIndex, newIndex))
        else
          p,
    ]);
  }

  List<PlaylistItem> _reorder(List<PlaylistItem> items, int oldIndex, int newIndex) {
    final list = [...items];
    final i = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = list.removeAt(oldIndex);
    list.insert(i, moved);
    return list;
  }
}

/// Sélection d'un passage à partir d'une clé `"s:a"` (+ fin `"s:b"` éventuelle).
Selection passageSelection(String verseKey, [String? rangeEnd]) {
  final p = verseKey.split(':');
  final surah = int.parse(p[0]);
  final from = int.parse(p[1]);
  final to = rangeEnd != null ? int.parse(rangeEnd.split(':')[1]) : from;
  return SelSurah(surah, from, to);
}

bool playlistHasPassage(Playlist p, Selection selection) =>
    p.items.any((i) => i.selection == selection);

// --- Dérivés (lecture seule, recomposés réactivement) ---

final surahMetasProvider = FutureProvider<List<SurahMeta>>(
    (ref) => ref.read(corpusRepositoryProvider).surahMetas());

final atlasHeatProvider = FutureProvider<List<SurahHeatTile>>((ref) async {
  final metas = await ref.watch(surahMetasProvider.future);
  final mastery = await ref.watch(masteryControllerProvider.future);
  final settings = await ref.watch(settingsControllerProvider.future);
  final now = ref.read(clockProvider).nowMs();
  return buildAtlasHeat(
      metas, mastery.fragile, mastery.mastered, settings.masteryProfile, now);
});

final decayQueueProvider = FutureProvider<List<QueueEntry>>((ref) async {
  final mastery = await ref.watch(masteryControllerProvider.future);
  final settings = await ref.watch(settingsControllerProvider.future);
  final now = ref.read(clockProvider).nowMs();
  return buildDecayQueue(
      mastery.fragile, mastery.mastered, settings.masteryProfile, now);
});

/// Synthèse de la file de révision : nombre dû + estimation de durée (min).
final reviewSummaryProvider =
    FutureProvider<({int count, int minutes})>((ref) async {
  final queue = await ref.watch(decayQueueProvider.future);
  final count = queue.length;
  final minutes = count == 0 ? 0 : ((count * 12) / 60).ceil().clamp(1, 999);
  return (count: count, minutes: minutes);
});

final streakProvider = FutureProvider<int>((ref) async {
  final mastery = await ref.watch(masteryControllerProvider.future);
  final now = ref.read(clockProvider).nowMs();
  return computeStreak(mastery.sessionDays, now);
});

/// Top sourates « qui s'éteignent » (stats zones chaudes, sans gamification).
final hotZonesProvider = FutureProvider<List<SurahHeatTile>>((ref) async {
  final tiles = await ref.watch(atlasHeatProvider.future);
  final hot = tiles.where((t) => t.heat.needsReview > 0).toList()
    ..sort((a, b) => b.heat.needsReview.compareTo(a.heat.needsReview));
  return hot.take(5).toList(growable: false);
});
