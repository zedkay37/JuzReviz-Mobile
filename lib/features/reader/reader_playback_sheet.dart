import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_sheet.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/features/settings/setting_widgets.dart';

/// Paramètres de lecture audio, accessibles d'un geste depuis la barre.
class PlaybackParamsSheet extends ConsumerWidget {
  const PlaybackParamsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.lantern;
    final s = ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Lecture audio',
              style: TextStyle(
                  color: t.ink, fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: LanternSpace.sm),
          ChoiceRow<String>(
            title: 'Récitateur',
            value: reciterById(s.reciter).id,
            options: [for (final r in reciters) (r.id, r.name.split(' ').first)],
            onChanged: (v) {
              ctrl.edit((p) => p.copyWith(reciter: v));
            },
          ),
          SliderRow(
            title: 'Vitesse',
            value: s.playbackRate.clamp(0.5, 2.0),
            min: 0.5,
            max: 2.0,
            divisions: 6,
            valueLabel: '${s.playbackRate}×',
            onChanged: (v) {
              ctrl.edit((p) => p.copyWith(playbackRate: v));
              ref.read(audioControllerProvider).setRate(v);
            },
          ),
          ChoiceRow<AudioRepeatMode>(
            title: 'Répétition',
            value: s.repeatMode,
            options: const [
              (AudioRepeatMode.off, 'Aucune'),
              (AudioRepeatMode.ayah, 'Par âyah'),
              (AudioRepeatMode.range, 'Le passage'),
              (AudioRepeatMode.progressive, 'Progressif'),
            ],
            onChanged: (v) => ctrl.edit((p) => p.copyWith(repeatMode: v)),
          ),
          if (s.repeatMode == AudioRepeatMode.ayah)
            SliderRow(
              title: 'Répétitions par âyah',
              value: s.repeatCount.toDouble().clamp(1, 9),
              min: 1,
              max: 9,
              divisions: 8,
              valueLabel: '×${s.repeatCount}',
              onChanged: (v) =>
                  ctrl.edit((p) => p.copyWith(repeatCount: v.round())),
            ),
          if (s.repeatMode == AudioRepeatMode.range)
            SliderRow(
              title: 'Boucles du passage',
              value: s.rangeCount.toDouble().clamp(1, 9),
              min: 1,
              max: 9,
              divisions: 8,
              valueLabel: '×${s.rangeCount}',
              onChanged: (v) =>
                  ctrl.edit((p) => p.copyWith(rangeCount: v.round())),
            ),
          SliderRow(
            title: 'Pause après chaque âyah',
            value: s.repeatPauseMs.toDouble().clamp(0, 5000),
            min: 0,
            max: 5000,
            divisions: 20,
            valueLabel: '${(s.repeatPauseMs / 1000).toStringAsFixed(1)} s',
            onChanged: (v) =>
                ctrl.edit((p) => p.copyWith(repeatPauseMs: v.round())),
          ),
          SwitchRow(
            title: 'Maîtrise auto en fin de répétition',
            value: s.autoMaster,
            onChanged: (v) => ctrl.edit((p) => p.copyWith(autoMaster: v)),
          ),
        ],
      ),
    );
  }
}

Future<void> showPlaybackParams(BuildContext context) =>
    showLanternSheet<void>(context, builder: (_) => const PlaybackParamsSheet());
