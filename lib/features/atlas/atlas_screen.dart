import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/text_normalize.dart';
import 'package:juzreviz/core/designsystem/components/heat_labels.dart';
import 'package:juzreviz/core/designsystem/components/heat_widgets.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/review_banner.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/usecase/atlas_heat.dart';

enum _RevFilter { all, meccan, medinan }

/// Vue « carte de chaleur » du Coran — embarquée dans l'onglet Coran
/// (bascule liste/grille), plus utilisée comme écran plein-page.
class AtlasGridView extends ConsumerStatefulWidget {
  const AtlasGridView({super.key});

  @override
  ConsumerState<AtlasGridView> createState() => _AtlasGridViewState();
}

class _AtlasGridViewState extends ConsumerState<AtlasGridView> {
  _RevFilter _rev = _RevFilter.all;
  bool _memorizedOnly = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tilesAsync = ref.watch(atlasHeatProvider);
    final memorized =
        ref.watch(masteryControllerProvider).valueOrNull?.memorizedSurahs ??
        const <int>{};

    final content = tilesAsync.when<Widget>(
      // Anti-flicker : garde la grille pendant les recomputations.
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, _) => SliverToBoxAdapter(
        child: SizedBox(
          height: 240,
          child: LanternEmpty(
            message:
                'Impossible d’afficher la carte de mémorisation. Réessaie dans un instant.',
            action: OutlinedButton.icon(
              onPressed: () => ref.invalidate(atlasHeatProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
        ),
      ),
      data: (tiles) => _grid(_filter(tiles, memorized)),
    );

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        const SliverToBoxAdapter(child: ReviewBanner()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LanternSpace.md,
              vertical: LanternSpace.sm,
            ),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Sourate, numéro, translittération…',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
            child: Row(
              children: [
                _chip(
                  'Toutes',
                  _rev == _RevFilter.all,
                  () => setState(() => _rev = _RevFilter.all),
                ),
                _chip(
                  'Mecquoises',
                  _rev == _RevFilter.meccan,
                  () => setState(() => _rev = _RevFilter.meccan),
                ),
                _chip(
                  'Médinoises',
                  _rev == _RevFilter.medinan,
                  () => setState(() => _rev = _RevFilter.medinan),
                ),
                const SizedBox(width: 12),
                _chip(
                  'Mémorisées',
                  _memorizedOnly,
                  () => setState(() => _memorizedOnly = !_memorizedOnly),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: _HeatLegend()),
        content,
      ],
    );
  }

  List<SurahHeatTile> _filter(List<SurahHeatTile> tiles, Set<int> memorized) {
    final q = foldSearch(_query);
    return tiles
        .where((t) {
          final m = t.meta;
          if (_rev == _RevFilter.meccan && m.revelation != Revelation.meccan) {
            return false;
          }
          if (_rev == _RevFilter.medinan &&
              m.revelation != Revelation.medinan) {
            return false;
          }
          if (_memorizedOnly && !memorized.contains(m.number)) return false;
          if (q.isEmpty) return true;
          return foldSearch(m.transliteration).contains(q) ||
              foldSearch(m.englishName).contains(q) ||
              '${m.number}' == q;
        })
        .toList(growable: false);
  }

  Widget _grid(List<SurahHeatTile> tiles) {
    if (tiles.isEmpty) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
          child: LanternEmpty(message: 'Aucune sourate ne correspond.'),
        ),
      );
    }
    final scaleExtra = (MediaQuery.textScalerOf(context).scale(1) - 1)
        .clamp(0, 1)
        .toDouble();
    return SliverPadding(
      padding: const EdgeInsets.all(LanternSpace.md),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 170 + 45 * scaleExtra,
          mainAxisExtent: 92 + 38 * scaleExtra,
          crossAxisSpacing: LanternSpace.sm,
          mainAxisSpacing: LanternSpace.sm,
        ),
        delegate: SliverChildBuilderDelegate((context, i) {
          final tile = tiles[i];
          return HeatTile(
            meta: tile.meta,
            heat: tile.heat,
            scarred: tile.scarred,
            heroTag: 'surah-${tile.meta.number}',
            onTap: () => context.push('/atlas/surah/${tile.meta.number}'),
          );
        }, childCount: tiles.length),
      ),
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

/// Légende de la heatmap — rend les états distinguables.
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
          decoration: BoxDecoration(color: t.heat(s), shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: t.inkSoft, fontSize: 11)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: LanternSpace.md,
        vertical: LanternSpace.sm,
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          // Libellés = heatLabelFr : un seul vocabulaire dans toute l'app.
          dot(HeatState.fresh, heatLabelFr(HeatState.fresh)),
          dot(HeatState.fading, heatLabelFr(HeatState.fading)),
          dot(HeatState.stale, heatLabelFr(HeatState.stale)),
          dot(HeatState.fragile, heatLabelFr(HeatState.fragile)),
          dot(HeatState.blank, heatLabelFr(HeatState.blank)),
        ],
      ),
    );
  }
}
