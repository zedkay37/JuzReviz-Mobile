import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/core/common/clock.dart';
import 'package:juzreviz/data/audio/audio_controller.dart';
import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/corpus/corpus_repository.dart';
import 'package:juzreviz/data/mastery/mastery_repository.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';
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

final audioControllerProvider = Provider<AudioController>((ref) {
  final c = AudioController();
  ref.onDispose(c.dispose);
  return c;
});

final tafsirRepositoryProvider =
    Provider<TafsirRepository>((ref) => TafsirRepository());

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
