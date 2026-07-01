import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/components/program_card.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/surah_meta.dart';
import 'package:juzreviz/domain/usecase/decay_queue.dart';

class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(decayQueueProvider);
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];

    return LanternScaffold(
      appBar: AppBar(title: const Text('Aujourd’hui')),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => LanternEmpty(message: 'Erreur : $e'),
        data: (queue) {
          return Column(
            children: [
              _Header(streak: streak, count: queue.length),
              const _HotZones(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: queue.isEmpty
                            ? null
                            : () => _start(context, queue, 15),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('3 minutes'),
                      ),
                    ),
                    const SizedBox(width: LanternSpace.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: queue.isEmpty
                            ? null
                            : () => _start(context, queue, queue.length),
                        icon: const Icon(Icons.playlist_play),
                        label: const Text('Tout réviser'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LanternSpace.sm),
              Expanded(
                child: queue.isEmpty
                    ? const LanternEmpty(
                        message:
                            'Rien ne s’éteint aujourd’hui. Reviens quand tu veux — '
                            'tes versets sont au chaud.',
                        icon: Icons.spa_outlined,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(LanternSpace.md),
                        itemCount: queue.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: LanternSpace.sm),
                        itemBuilder: (context, i) {
                          final e = queue[i];
                          return ProgramCard(
                            verseKey: e.verseKey,
                            title: _title(metas, e.verseKey),
                            state: e.state,
                            count: e.count,
                            onTap: () => _start(context, [e], 1),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _title(List<SurahMeta> metas, String key) {
    final surah = int.parse(key.split(':')[0]);
    final m = metas.where((x) => x.number == surah).firstOrNull;
    return m == null ? 'Sourate $surah' : m.transliteration;
  }

  void _start(BuildContext context, List<QueueEntry> queue, int n) {
    final keys = queue.take(n).map((e) => e.verseKey).toList();
    context.push('/session', extra: SelReview('Révision du jour', keys));
  }
}

class _HotZones extends ConsumerWidget {
  const _HotZones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final zones = ref.watch(hotZonesProvider).valueOrNull ?? const [];
    if (zones.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text('Zones chaudes',
                  style: TextStyle(color: t.inkSoft, fontSize: 12)),
            ),
          ),
          for (final z in zones)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: Icon(Icons.local_fire_department,
                    size: 16, color: t.heat(z.heat.dominant)),
                label: Text('${z.meta.transliteration} · ${z.heat.needsReview}'),
                onPressed: () => context.push('/atlas/surah/${z.meta.number}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak, required this.count});
  final int streak;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return Padding(
      padding: const EdgeInsets.all(LanternSpace.md),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: t.accent),
          const SizedBox(width: 6),
          Text('$streak j',
              style: TextStyle(
                  color: t.ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
          Text('de régularité',
              style: TextStyle(color: t.inkSoft, fontSize: 13)),
          const Spacer(),
          Text(
            count == 0 ? 'À jour' : '$count à revoir',
            style: TextStyle(color: t.inkSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
