import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/text_normalize.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';

/// Ensemencement initial ou gestion ultérieure des sourates mémorisées.
Future<void> showKnownSurahsSheet(
  BuildContext context, {
  bool manageExisting = false,
}) => showLanternSheet<void>(
  context,
  builder: (_) => _KnownSurahsSheet(manageExisting: manageExisting),
);

class _KnownSurahsSheet extends ConsumerStatefulWidget {
  const _KnownSurahsSheet({required this.manageExisting});

  final bool manageExisting;

  @override
  ConsumerState<_KnownSurahsSheet> createState() => _KnownSurahsSheetState();
}

class _KnownSurahsSheetState extends ConsumerState<_KnownSurahsSheet> {
  final Set<int> _selected = {};
  final TextEditingController _searchController = TextEditingController();
  bool _initialized = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final metasAsync = ref.watch(surahMetasProvider);
    final masteryAsync = ref.watch(masteryControllerProvider);
    final metas = metasAsync.valueOrNull;
    final hasError =
        metasAsync.hasError || (widget.manageExisting && masteryAsync.hasError);
    if (metas == null || (widget.manageExisting && !masteryAsync.hasValue)) {
      return SizedBox(
        height: 320,
        child: hasError
            ? LanternEmpty(
                message: 'Impossible de charger tes sourates mémorisées.',
                action: TextButton.icon(
                  onPressed: () {
                    ref
                      ..invalidate(surahMetasProvider)
                      ..invalidate(masteryControllerProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_initialized) {
      if (widget.manageExisting) {
        _selected.addAll(
          masteryAsync.valueOrNull?.memorizedSurahs ?? const <int>{},
        );
      }
      _initialized = true;
    }
    final q = foldSearch(_query);
    final filtered = metas
        .where((m) {
          if (q.isEmpty) return true;
          return foldSearch(m.transliteration).contains(q) ||
              foldSearch(m.englishName).contains(q) ||
              '${m.number}' == q;
        })
        .toList(growable: false);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleExtra = (textScale - 1).clamp(0, 1).toDouble();
    final cellHeight = 56 + 28 * scaleExtra;
    final cellWidth = 120 + 60 * scaleExtra;

    return CustomScrollView(
      shrinkWrap: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.manageExisting
                    ? 'Mes sourates mémorisées'
                    : 'Que connais-tu déjà par cœur ?',
                style: TextStyle(
                  color: t.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.manageExisting
                    ? 'Ajoute ou retire les marqueurs. Retirer une sourate '
                          'conserve son historique de révision.'
                    : 'Coche tes sourates mémorisées : tes révisions commencent '
                          'dès aujourd’hui, par petites vagues quotidiennes.',
                style: TextStyle(color: t.inkSoft, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: LanternSpace.md),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Rechercher une sourate…',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: LanternSpace.sm),
              Wrap(
                spacing: LanternSpace.sm,
                runSpacing: LanternSpace.sm,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Sélectionner Juz ‘Amma'),
                    onPressed: () => setState(() {
                      _selected.addAll(
                        metas.where((m) => m.number >= 78).map((m) => m.number),
                      );
                    }),
                  ),
                  if (_selected.isNotEmpty)
                    ActionChip(
                      avatar: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Tout effacer'),
                      onPressed: () => setState(_selected.clear),
                    ),
                ],
              ),
              const SizedBox(height: LanternSpace.sm),
            ],
          ),
        ),
        if (filtered.isEmpty)
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: LanternEmpty(message: 'Aucune sourate ne correspond.'),
            ),
          )
        else
          SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: cellWidth,
              mainAxisExtent: cellHeight,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final m = filtered[i];
              final on = _selected.contains(m.number);
              void toggle() => setState(() {
                HapticFeedback.selectionClick();
                on ? _selected.remove(m.number) : _selected.add(m.number);
              });
              return Semantics(
                container: true,
                button: true,
                selected: on,
                label:
                    '${m.number}, ${m.transliteration}, ${m.ayahCount} versets',
                onTap: toggle,
                child: ExcludeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: toggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on
                            ? t.accent.withValues(alpha: 0.16)
                            : t.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: on ? t.accent : t.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${m.number} · ${m.transliteration}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: on ? t.accent : t.ink,
                              fontSize: 12,
                              fontWeight: on
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          Text(
                            '${m.ayahCount} v.',
                            style: TextStyle(color: t.inkFaint, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }, childCount: filtered.length),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: LanternSpace.md)),
        SliverToBoxAdapter(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _selected.isEmpty && !widget.manageExisting
                  ? null
                  : () => _save(metas),
              child: Text(
                widget.manageExisting
                    ? 'Enregistrer (${_selected.length})'
                    : _selected.isEmpty
                    ? 'Coche au moins une sourate'
                    : 'Valider (${_selected.length})',
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.manageExisting ? 'Annuler' : 'Je pars de zéro'),
          ),
        ),
      ],
    );
  }

  Future<void> _save(List<SurahMeta> metas) async {
    final byNum = {for (final m in metas) m.number: m.ayahCount};
    final n = _selected.length;
    final messenger = ScaffoldMessenger.of(context);
    final selected = {for (final s in _selected) s: byNum[s] ?? 1};
    final controller = ref.read(masteryControllerProvider.notifier);
    if (widget.manageExisting) {
      await controller.setKnownSurahs(selected);
    } else {
      await controller.seedKnownSurahs(selected);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.manageExisting
              ? 'Sourates mémorisées mises à jour.'
              : '$n sourate${n > 1 ? 's' : ''} au programme — tes '
                    'premières révisions t’attendent.',
        ),
      ),
    );
  }
}
