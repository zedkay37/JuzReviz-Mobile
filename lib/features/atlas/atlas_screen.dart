import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/text_normalize.dart';
import 'package:juzreviz/core/designsystem/components/heat_widgets.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/review_banner.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/usecase/atlas_heat.dart';

enum _RevFilter { all, meccan, medinan }

/// Deux intentions distinctes : naviguer le Coran vs voir sa mémorisation.
enum _AtlasMode { explore, progress }

class AtlasScreen extends ConsumerStatefulWidget {
  const AtlasScreen({super.key});

  @override
  ConsumerState<AtlasScreen> createState() => _AtlasScreenState();
}

class _AtlasScreenState extends ConsumerState<AtlasScreen> {
  _AtlasMode _mode = _AtlasMode.explore;
  _RevFilter _rev = _RevFilter.all;
  bool _memorizedOnly = false;
  String _query = '';

  bool get _progress => _mode == _AtlasMode.progress;

  @override
  Widget build(BuildContext context) {
    final tilesAsync = ref.watch(atlasHeatProvider);
    final memorized = ref.watch(masteryControllerProvider).valueOrNull
            ?.memorizedSurahs ??
        const <int>{};

    return LanternScaffold(
      appBar: AppBar(title: const Text('Atlas')),
      body: Column(
        children: [
          const ReviewBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                LanternSpace.md, LanternSpace.sm, LanternSpace.md, 0),
            child: SegmentedButton<_AtlasMode>(
              segments: const [
                ButtonSegment(
                    value: _AtlasMode.explore,
                    label: Text('Explorer'),
                    icon: Icon(Icons.travel_explore)),
                ButtonSegment(
                    value: _AtlasMode.progress,
                    label: Text('Ma progression'),
                    icon: Icon(Icons.local_fire_department)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: LanternSpace.md, vertical: LanternSpace.sm),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Sourate, numéro, translittération…',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
            child: Row(
              children: [
                _chip('Toutes', _rev == _RevFilter.all,
                    () => setState(() => _rev = _RevFilter.all)),
                _chip('Mecquoises', _rev == _RevFilter.meccan,
                    () => setState(() => _rev = _RevFilter.meccan)),
                _chip('Médinoises', _rev == _RevFilter.medinan,
                    () => setState(() => _rev = _RevFilter.medinan)),
                if (_progress) ...[
                  const SizedBox(width: 12),
                  _chip('Mémorisées', _memorizedOnly,
                      () => setState(() => _memorizedOnly = !_memorizedOnly)),
                ],
              ],
            ),
          ),
          if (_progress) const _HeatLegend(),
          Expanded(
            child: tilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
              data: (tiles) => _grid(_filter(tiles, memorized)),
            ),
          ),
        ],
      ),
    );
  }

  List<SurahHeatTile> _filter(List<SurahHeatTile> tiles, Set<int> memorized) {
    final q = foldSearch(_query);
    return tiles.where((t) {
      final m = t.meta;
      if (_rev == _RevFilter.meccan && m.revelation != Revelation.meccan) {
        return false;
      }
      if (_rev == _RevFilter.medinan && m.revelation != Revelation.medinan) {
        return false;
      }
      if (_progress && _memorizedOnly && !memorized.contains(m.number)) {
        return false;
      }
      if (q.isEmpty) return true;
      return foldSearch(m.transliteration).contains(q) ||
          foldSearch(m.englishName).contains(q) ||
          '${m.number}' == q;
    }).toList(growable: false);
  }

  Widget _grid(List<SurahHeatTile> tiles) {
    if (tiles.isEmpty) {
      return const LanternEmpty(message: 'Aucune sourate ne correspond.');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(LanternSpace.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        mainAxisExtent: 92,
        crossAxisSpacing: LanternSpace.sm,
        mainAxisSpacing: LanternSpace.sm,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final tile = tiles[i];
        return HeatTile(
          meta: tile.meta,
          heat: tile.heat,
          scarred: tile.scarred,
          showHeat: _progress,
          heroTag: 'surah-${tile.meta.number}',
          onTap: () => context.push('/atlas/surah/${tile.meta.number}'),
        );
      },
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

/// Légende de la heatmap (mode progression) — rend les états distinguables.
class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    Widget dot(HeatState s, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration:
                  BoxDecoration(color: t.heat(s), shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: t.inkSoft, fontSize: 11)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: LanternSpace.md, vertical: LanternSpace.sm),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          dot(HeatState.fresh, 'Frais'),
          dot(HeatState.fading, 'Tiédit'),
          dot(HeatState.fragile, 'Fragile'),
          dot(HeatState.blank, 'Vierge'),
        ],
      ),
    );
  }
}
