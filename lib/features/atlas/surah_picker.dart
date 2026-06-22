import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/text_normalize.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/enums.dart';

/// Sélecteur de sourate (numéro + nom + recherche). Renvoie le numéro choisi.
Future<int?> pickSurah(BuildContext context) {
  final t = context.lantern;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(LanternSpace.radius)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.85,
      child: _SurahPickerSheet(),
    ),
  );
}

class _SurahPickerSheet extends ConsumerStatefulWidget {
  const _SurahPickerSheet();

  @override
  ConsumerState<_SurahPickerSheet> createState() => _SurahPickerSheetState();
}

class _SurahPickerSheetState extends ConsumerState<_SurahPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];
    final q = foldSearch(_query);
    final filtered = metas.where((m) {
      if (q.isEmpty) return true;
      return foldSearch(m.transliteration).contains(q) ||
          foldSearch(m.englishName).contains(q) ||
          '${m.number}' == q;
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Sourate, numéro, translittération…',
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: LanternSpace.sm),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final m = filtered[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.surfaceHigh,
                    foregroundColor: t.accent,
                    radius: 16,
                    child: Text('${m.number}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(m.transliteration),
                  subtitle: Text(
                    '${m.englishName} · ${m.ayahCount} versets · '
                    '${m.revelation == Revelation.meccan ? 'Mecquoise' : 'Médinoise'}',
                    style: TextStyle(color: t.inkSoft, fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).pop(m.number),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
