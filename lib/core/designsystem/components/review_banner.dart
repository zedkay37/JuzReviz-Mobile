import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/common/plural.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/domain/model/selection.dart';

/// Bandeau de révision omniprésent : surfacé en haut du Reader / de l'Atlas
/// quand des versets sont dus. Se replie (collapse animé) si la file est vide.
class ReviewBanner extends ConsumerWidget {
  const ReviewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final summary = ref.watch(reviewSummaryProvider).valueOrNull;
    final count = summary?.count ?? 0;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : LanternMotion.medium,
      curve: LanternMotion.emphasized,
      alignment: Alignment.topCenter,
      child: count == 0
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                  LanternSpace.md, LanternSpace.sm, LanternSpace.md, 0),
              child: Material(
                color: t.surface,
                borderRadius: BorderRadius.circular(LanternSpace.radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(LanternSpace.radius),
                  onTap: () => _review(context, ref),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: LanternSpace.md, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(LanternSpace.radius),
                      border: Border.all(color: t.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department, color: t.accent, size: 20),
                        const SizedBox(width: LanternSpace.sm),
                        Expanded(
                          child: Text(
                            '$count ${pluralize(count, 'verset', 'versets')} à réviser · ~${summary!.minutes} min',
                            style: TextStyle(color: t.ink, fontSize: 14),
                          ),
                        ),
                        Text('Réviser',
                            style: TextStyle(
                                color: t.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        Icon(Icons.chevron_right, color: t.accent, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final queue = ref.read(decayQueueProvider).valueOrNull ?? const [];
    if (queue.isEmpty) return;
    final keys = queue.map((e) => e.verseKey).toList(growable: false);
    context.push('/session', extra: SelReview('Révision', keys));
  }
}
