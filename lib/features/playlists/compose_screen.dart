import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/plural.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/components/prompt_dialog.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/usecase/juz_index.dart';

/// Composeur multi-sélection : coche des sourates / juz d'un tap pour bâtir
/// une liste de lecture-révision, puis la lire ou l'enregistrer en playlist.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  /// Sourate → plage (from, to). Plage entière = (1, ayahCount).
  final Map<int, (int, int)> _surahs = {};
  final Set<int> _juz = {};

  int get _count => _surahs.length + _juz.length;

  List<Selection> _selections() => [
        for (final n in _surahs.keys.toList()..sort())
          SelSurah(n, _surahs[n]!.$1, _surahs[n]!.$2),
        for (final j in _juz.toList()..sort()) SelJuz(j),
      ];

  List<String> _allKeys(List<SurahMeta> metas) {
    final keys = <String>[];
    for (final n in _surahs.keys.toList()..sort()) {
      final (from, to) = _surahs[n]!;
      for (var a = from; a <= to; a++) {
        keys.add('$n:$a');
      }
    }
    for (final j in _juz.toList()..sort()) {
      keys.addAll(juzVerseKeys(j, metas));
    }
    return keys;
  }

  void _read() {
    final metas = ref.read(surahMetasProvider).valueOrNull ?? const [];
    final keys = _allKeys(metas);
    if (keys.isEmpty) return;
    context.push('/recite', extra: SelReview(_label(metas), keys));
  }

  String _label(List<SurahMeta> metas) {
    if (_surahs.isNotEmpty) {
      final first = (_surahs.keys.toList()..sort()).first;
      final name =
          metas.where((m) => m.number == first).firstOrNull?.transliteration ??
              'Sourate $first';
      final (from, to) = _surahs[first]!;
      final meta = metas.where((m) => m.number == first).firstOrNull;
      final range =
          meta != null && (from != 1 || to != meta.ayahCount) ? ' $from–$to' : '';
      return _surahs.length > 1 ? '$name$range +${_surahs.length - 1}' : '$name$range';
    }
    if (_juz.isNotEmpty) {
      final j = (_juz.toList()..sort()).first;
      return _juz.length > 1 ? 'Juz $j +${_juz.length - 1}' : 'Juz $j';
    }
    return 'Lecture';
  }

  Future<void> _save() async {
    final name = await promptText(context,
        title: 'Nom de la playlist', hint: 'Ma révision');
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(playlistsControllerProvider.notifier)
        .createWithSelections(name.trim(), _selections());
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${name.trim()} » enregistrée')));
    setState(() {
      _surahs.clear();
      _juz.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final metasAsync = ref.watch(surahMetasProvider);

    return DefaultTabController(
      length: 2,
      child: LanternScaffold(
        appBar: AppBar(
          title: Text(_count == 0
              ? 'Réciter'
              : '$_count ${pluralize(_count, 'sélection', 'sélections')}'),
          actions: [
            if (_count > 0)
              TextButton(onPressed: _save, child: const Text('Enregistrer')),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Sourates'), Tab(text: 'Juz')],
          ),
        ),
        body: metasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
          data: (metas) => TabBarView(
            children: [
              ListView.builder(
                itemCount: metas.length + 2,
                itemBuilder: (_, i) {
                  if (i == 0) return _QuickActions(metas: metas);
                  if (i == 1) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Text(
                        'Astuce : appui long sur une sourate pour choisir une plage précise.',
                        style: TextStyle(color: t.inkFaint, fontSize: 12),
                      ),
                    );
                  }
                  return _surahTile(t, metas[i - 2]);
                },
              ),
              ListView.builder(
                itemCount: 30,
                itemBuilder: (_, i) => _juzTile(t, i + 1),
              ),
            ],
          ),
        ),
        floatingActionButton: _count == 0
            ? null
            : FloatingActionButton.extended(
                backgroundColor: t.accent,
                foregroundColor: t.accentInk,
                onPressed: _read,
                icon: const Icon(Icons.graphic_eq),
                label: const Text('Réciter'),
              ),
      ),
    );
  }

  Widget _surahTile(LanternTokens t, SurahMeta m) {
    final range = _surahs[m.number];
    final on = range != null;
    final isPartial = on && (range.$1 != 1 || range.$2 != m.ayahCount);
    return ListTile(
      onTap: () => setState(() {
        HapticFeedback.selectionClick();
        _juz.clear(); // sélection non-cumulative : sourates OU juz
        on ? _surahs.remove(m.number) : _surahs[m.number] = (1, m.ayahCount);
      }),
      onLongPress: () => _pickRange(m),
      leading: _badge(t, '${m.number}', on),
      title: Text(m.transliteration, style: TextStyle(color: t.ink)),
      subtitle: Text(
          isPartial
              ? 'Plage : ${range.$1}–${range.$2}'
              : '${m.ayahCount} versets · ${m.revelation == Revelation.meccan ? 'Mecquoise' : 'Médinoise'}',
          style: TextStyle(
              color: isPartial ? t.accent : t.inkSoft, fontSize: 12)),
      trailing: Text(m.arabicName,
          textDirection: TextDirection.rtl,
          style: TextStyle(
              color: t.inkSoft, fontSize: 18, fontFamily: t.arabicFamily)),
    );
  }

  Future<void> _pickRange(SurahMeta m) async {
    final current = _surahs[m.number];
    final picked = await showLanternSheet<(int, int)>(
      context,
      builder: (_) => _SurahRangeSheet(
        meta: m,
        initialFrom: current?.$1 ?? 1,
        initialTo: current?.$2 ?? m.ayahCount,
      ),
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _juz.clear();
      _surahs[m.number] = picked;
    });
  }

  Widget _juzTile(LanternTokens t, int juz) {
    final on = _juz.contains(juz);
    return ListTile(
      onTap: () => setState(() {
        HapticFeedback.selectionClick();
        _surahs.clear(); // sélection non-cumulative : sourates OU juz
        on ? _juz.remove(juz) : _juz.add(juz);
      }),
      leading: _badge(t, '$juz', on),
      title: Text('Juz $juz', style: TextStyle(color: t.ink)),
    );
  }

  Widget _badge(LanternTokens t, String label, bool on) => CircleAvatar(
        backgroundColor: on ? t.accent : t.surfaceHigh,
        child: on
            ? Icon(Icons.check, color: t.accentInk, size: 20)
            : Text(label, style: TextStyle(color: t.accent, fontSize: 13)),
      );
}

/// Accès directs au-dessus du composeur : reprendre la dernière position,
/// écouter les versets à revoir. Zéro friction pour l'usage quotidien.
class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.metas});
  final List<SurahMeta> metas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final s =
        ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final queue = ref.watch(decayQueueProvider).valueOrNull ?? const [];

    final parts = s.currentVerseKey.split(':');
    final surah = int.tryParse(parts.first) ?? 1;
    final ayah = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final meta = metas.where((m) => m.number == surah).firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LanternSpace.md,
        LanternSpace.md,
        LanternSpace.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (meta != null)
            Material(
              color: t.surface,
              borderRadius: BorderRadius.circular(LanternSpace.radius),
              child: InkWell(
                borderRadius: BorderRadius.circular(LanternSpace.radius),
                onTap: () => context.push(
                  '/recite',
                  extra: SelSurah(surah, ayah, meta.ayahCount),
                ),
                child: Container(
                  padding: const EdgeInsets.all(LanternSpace.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(LanternSpace.radius),
                    border: Border.all(color: t.accent),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle, color: t.accent, size: 34),
                      const SizedBox(width: LanternSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reprendre la récitation',
                                style:
                                    TextStyle(color: t.inkSoft, fontSize: 12)),
                            Text(
                              '${meta.transliteration} · verset $ayah',
                              style: TextStyle(
                                  color: t.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: t.inkSoft),
                    ],
                  ),
                ),
              ),
            ),
          if (queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: LanternSpace.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(Icons.local_fire_department,
                      size: 18, color: t.fragile),
                  label: Text('Écouter mes versets à revoir (${queue.length})'),
                  onPressed: () => context.push(
                    '/recite',
                    extra: SelReview(
                      'À revoir',
                      queue.map((e) => e.verseKey).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Feuille « De / à » : borne une sourate sur une plage d'âyât précise.
class _SurahRangeSheet extends StatefulWidget {
  const _SurahRangeSheet({
    required this.meta,
    required this.initialFrom,
    required this.initialTo,
  });
  final SurahMeta meta;
  final int initialFrom;
  final int initialTo;

  @override
  State<_SurahRangeSheet> createState() => _SurahRangeSheetState();
}

class _SurahRangeSheetState extends State<_SurahRangeSheet> {
  late int _from = widget.initialFrom;
  late int _to = widget.initialTo;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final max = widget.meta.ayahCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Plage — ${widget.meta.transliteration}',
          style: TextStyle(
              color: t.ink, fontSize: 17, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text('$max versets', style: TextStyle(color: t.inkSoft, fontSize: 12)),
        const SizedBox(height: 18),
        _stepperRow(
          t,
          'De l’âyah',
          _from,
          onMinus: () => setState(() {
            if (_from > 1) _from--;
          }),
          onPlus: () => setState(() {
            if (_from < _to) _from++;
          }),
        ),
        const SizedBox(height: 8),
        _stepperRow(
          t,
          'À l’âyah',
          _to,
          onMinus: () => setState(() {
            if (_to > _from) _to--;
          }),
          onPlus: () => setState(() {
            if (_to < max) _to++;
          }),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop((1, max)),
                child: const Text('Sourate entière'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop((_from, _to)),
                child: const Text('Valider'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepperRow(
    LanternTokens t,
    String label,
    int value, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: t.inkSoft, fontSize: 14)),
        ),
        IconButton(
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 48,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: t.ink, fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
