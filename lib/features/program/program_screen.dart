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
import 'package:juzreviz/features/program/known_surahs_sheet.dart';

class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(decayQueueProvider);
    final streak = ref.watch(streakProvider).valueOrNull ?? 0;
    final metas = ref.watch(surahMetasProvider).valueOrNull ?? const [];

    // État vierge : rien de marqué → l'onboarding d'ensemencement prime.
    final mastery = ref.watch(masteryControllerProvider).valueOrNull;
    final blank =
        mastery != null &&
        mastery.mastered.isEmpty &&
        mastery.fragile.isEmpty &&
        mastery.memorizedSurahs.isEmpty;

    return LanternScaffold(
      contentMaxWidth: 760,
      appBar: AppBar(title: const Text('Aujourd’hui')),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LanternEmpty(
          message:
              'Impossible de charger le programme du jour. Réessaie dans un instant.',
          action: OutlinedButton.icon(
            onPressed: () => ref.invalidate(decayQueueProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
        data: (queue) {
          if (blank) return const _ColdStart();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(streak: streak, count: queue.length),
              ),
              const SliverToBoxAdapter(child: _HotZones()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LanternSpace.md,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stack =
                          constraints.maxWidth < 420 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.35;
                      final quick = FilledButton.icon(
                        onPressed: queue.isEmpty
                            ? null
                            : () => _start(context, queue, 15),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Session rapide'),
                      );
                      final all = OutlinedButton.icon(
                        onPressed: queue.isEmpty
                            ? null
                            : () => _start(context, queue, queue.length),
                        icon: const Icon(Icons.playlist_play),
                        label: const Text('Tout réviser'),
                      );
                      if (stack) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            quick,
                            const SizedBox(height: LanternSpace.sm),
                            all,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: quick),
                          const SizedBox(width: LanternSpace.sm),
                          Expanded(child: all),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: LanternSpace.sm),
              ),
              if (queue.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LanternEmpty(
                    message:
                        'Rien ne s’éteint aujourd’hui. Reviens quand tu veux — '
                        'tes versets sont au chaud.',
                    icon: Icons.spa_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(LanternSpace.md),
                  sliver: SliverList.builder(
                    itemCount: queue.length * 2 - 1,
                    itemBuilder: (context, i) {
                      if (i.isOdd) {
                        return const SizedBox(height: LanternSpace.sm);
                      }
                      final e = queue[i ~/ 2];
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
    final scaleExtra = (MediaQuery.textScalerOf(context).scale(1) - 1)
        .clamp(0, 1)
        .toDouble();
    return SizedBox(
      height: 40 + 20 * scaleExtra,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LanternSpace.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                'Zones chaudes',
                style: TextStyle(color: t.inkSoft, fontSize: 12),
              ),
            ),
          ),
          for (final z in zones)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: t.heat(z.heat.dominant),
                ),
                label: Text(
                  '${z.meta.transliteration} · ${z.heat.needsReview}',
                ),
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: LanternSpace.md,
        runSpacing: LanternSpace.xs,
        children: [
          if (streak > 0)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_fire_department, color: t.accent),
                const SizedBox(width: 6),
                Text(
                  '$streak j',
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'de régularité',
                    style: TextStyle(color: t.inkSoft, fontSize: 13),
                  ),
                ),
              ],
            )
          else
            Text(
              'Ta révision du jour',
              style: TextStyle(
                color: t.ink,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          Text(
            count == 0 ? 'À jour' : '$count à revoir',
            style: TextStyle(color: t.inkSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Premier lancement : rien de marqué → ensemencer avec les sourates connues.
class _ColdStart extends StatelessWidget {
  const _ColdStart();

  @override
  Widget build(BuildContext context) {
    final t = context.lantern;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(LanternSpace.lg),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - LanternSpace.lg * 2)
                .clamp(0, double.infinity)
                .toDouble(),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: t.accent, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Commence avec ce que tu sais',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Indique les sourates que tu connais déjà par cœur : '
                  'ton programme de révision démarre immédiatement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.inkSoft, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => showKnownSurahsSheet(context),
                  icon: const Icon(Icons.checklist),
                  label: const Text('Je connais déjà des sourates'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/coran'),
                  child: const Text('Je pars de zéro — ouvrir le Coran'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
