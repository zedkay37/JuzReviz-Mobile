import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/plural.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/prompt_dialog.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/audio_cache.dart';
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
  final Set<int> _surahs = {};
  final Set<int> _juz = {};

  int get _count => _surahs.length + _juz.length;

  List<Selection> _selections() => [
        for (final n in _surahs.toList()..sort())
          _surahSel(n),
        for (final j in _juz.toList()..sort()) SelJuz(j),
      ];

  Selection _surahSel(int n) {
    final metas = ref.read(surahMetasProvider).valueOrNull;
    final count = metas?.where((m) => m.number == n).firstOrNull?.ayahCount ?? 1;
    return SelSurah(n, 1, count);
  }

  List<String> _allKeys(List<SurahMeta> metas) {
    final keys = <String>[];
    final byNum = {for (final m in metas) m.number: m};
    for (final n in _surahs.toList()..sort()) {
      final m = byNum[n];
      if (m != null) keys.addAll(surahVerseKeys(n, m.ayahCount));
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
      final first = (_surahs.toList()..sort()).first;
      final name =
          metas.where((m) => m.number == first).firstOrNull?.transliteration ??
              'Sourate $first';
      return _surahs.length > 1 ? '$name +${_surahs.length - 1}' : name;
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
                itemCount: metas.length,
                itemBuilder: (_, i) => _surahTile(t, metas[i]),
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
    final on = _surahs.contains(m.number);
    return ListTile(
      onTap: () => setState(() {
        HapticFeedback.selectionClick();
        _juz.clear(); // sélection non-cumulative : sourates OU juz
        on ? _surahs.remove(m.number) : _surahs.add(m.number);
      }),
      leading: _badge(t, '${m.number}', on),
      title: Text(m.transliteration, style: TextStyle(color: t.ink)),
      subtitle: Text(
          '${m.ayahCount} versets · ${m.revelation == Revelation.meccan ? 'Mecquoise' : 'Médinoise'}',
          style: TextStyle(color: t.inkSoft, fontSize: 12)),
      trailing: Text(m.arabicName,
          textDirection: TextDirection.rtl,
          style: TextStyle(
              color: t.inkSoft, fontSize: 18, fontFamily: t.arabicFamily)),
    );
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
