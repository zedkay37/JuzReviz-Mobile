import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/core/designsystem/components/lantern_scaffold.dart';
import 'package:juzreviz/core/designsystem/lantern_theme.dart';
import 'package:juzreviz/core/designsystem/lantern_tokens.dart';
import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';
import 'package:juzreviz/data/playlists/playlist.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/enums.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider).valueOrNull ?? const Settings();
    final ctrl = ref.read(settingsControllerProvider.notifier);
    void up(Settings Function(Settings) f) => ctrl.edit(f);

    return LanternScaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: LanternSpace.sm),
        children: [
          _section('Récitation'),
          ListTile(
            title: const Text('Récitateur'),
            subtitle: Text(reciterById(s.reciter).name),
            onTap: () => _pickReciter(context, ref),
          ),
          ListTile(
            title: const Text('Vitesse'),
            trailing: Text('${s.playbackRate}×'),
            subtitle: Slider(
              value: s.playbackRate,
              min: 0.5,
              max: 2,
              divisions: 6,
              label: '${s.playbackRate}×',
              onChanged: (v) => up((p) => p.copyWith(playbackRate: v)),
            ),
          ),
          _enumTile<AudioRepeatMode>(
            'Répétition',
            AudioRepeatMode.values,
            s.repeatMode,
            (v) => up((p) => p.copyWith(repeatMode: v)),
            (v) => switch (v) {
              AudioRepeatMode.off => 'Aucune',
              AudioRepeatMode.ayah => 'Par ayah',
              AudioRepeatMode.range => 'Par passage',
              AudioRepeatMode.progressive => 'Progressif',
            },
          ),
          _section('Lecture & affichage'),
          SwitchListTile(
            title: const Text('Mot-à-mot'),
            value: s.readerWordByWord,
            onChanged: (v) => up((p) => p.copyWith(readerWordByWord: v)),
          ),
          _langTile('Langue des gloses', s.glossLang,
              (v) => up((p) => p.copyWith(glossLang: v))),
          SwitchListTile(
            title: const Text('Traduction'),
            value: s.readerTranslation,
            onChanged: (v) => up((p) => p.copyWith(readerTranslation: v)),
          ),
          _langTile('Langue de traduction', s.translationLang,
              (v) => up((p) => p.copyWith(translationLang: v))),
          SwitchListTile(
            title: const Text('Chiffres latins'),
            value: s.latinAyahNumbers,
            onChanged: (v) => up((p) => p.copyWith(latinAyahNumbers: v)),
          ),
          SwitchListTile(
            title: const Text('Couleurs tajwid'),
            value: s.tajweedColors,
            onChanged: (v) => up((p) => p.copyWith(tajweedColors: v)),
          ),
          SwitchListTile(
            title: const Text('Audio-mot (tap mot)'),
            value: s.wordAudio,
            onChanged: (v) => up((p) => p.copyWith(wordAudio: v)),
          ),
          _enumTile<VeilMode>(
            'Voile (auto-test)',
            VeilMode.values,
            s.veilMode,
            (v) => up((p) => p.copyWith(veilMode: v)),
            (v) => switch (v) {
              VeilMode.full => 'Tout visible',
              VeilMode.firstWords => 'Premiers mots',
              VeilMode.hidden => 'Masqué',
            },
          ),
          SwitchListTile(
            title: const Text('Mode focus'),
            value: s.focusMode,
            onChanged: (v) => up((p) => p.copyWith(focusMode: v)),
          ),
          _section('Révision'),
          _enumTile<MasteryProfile>(
            'Profil de maîtrise',
            MasteryProfile.values,
            s.masteryProfile,
            (v) => up((p) => p.copyWith(masteryProfile: v)),
            (v) => v == MasteryProfile.serenity ? 'Sérénité' : 'Excellence',
          ),
          SwitchListTile(
            title: const Text('Capture auto en fin de verset'),
            value: s.autoMaster,
            onChanged: (v) => up((p) => p.copyWith(autoMaster: v)),
          ),
          SwitchListTile(
            title: const Text('Rappels de révision'),
            value: s.remindersEnabled,
            onChanged: (v) => up((p) => p.copyWith(remindersEnabled: v)),
          ),
          _section('Apparence'),
          ListTile(
            title: const Text('Thème'),
            subtitle: Text(appThemeFromString(s.theme).label),
            onTap: () => _pickTheme(context, ref),
          ),
          SwitchListTile(
            title: const Text('Couleur dynamique (Android)'),
            value: s.dynamicColor,
            onChanged: (v) => up((p) => p.copyWith(dynamicColor: v)),
          ),
          SwitchListTile(
            title: const Text('Garder l’écran allumé'),
            value: s.keepScreenOn,
            onChanged: (v) => up((p) => p.copyWith(keepScreenOn: v)),
          ),
          SwitchListTile(
            title: const Text('Décor vivant'),
            value: s.ambientDecor,
            onChanged: (v) => up((p) => p.copyWith(ambientDecor: v)),
          ),
          _section('Données'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Exporter l’état de révision'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Importer'),
            onTap: () => _import(context, ref),
          ),
          _section('À propos'),
          const ListTile(
            title: Text('Sources & attributions'),
            subtitle: Text(
                'Texte uthmani : Tanzil.net. Gloses & traductions : corpus '
                'word-by-word (CC BY-NC). Aucune donnée ne quitte l’appareil.'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
            LanternSpace.md, LanternSpace.lg, LanternSpace.md, LanternSpace.xs),
        child: Builder(
          builder: (context) => Text(title.toUpperCase(),
              style: TextStyle(
                  color: context.lantern.accent,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
        ),
      );

  Widget _enumTile<T extends Enum>(
    String title,
    List<T> values,
    T current,
    ValueChanged<T> onChanged,
    String Function(T) label,
  ) =>
      ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: current,
          underline: const SizedBox.shrink(),
          items: [
            for (final v in values)
              DropdownMenuItem(value: v, child: Text(label(v))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  Widget _langTile(String title, String current, ValueChanged<String> onChanged) =>
      ListTile(
        title: Text(title),
        trailing: DropdownButton<String>(
          value: current == 'en' ? 'en' : 'fr',
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(value: 'fr', child: Text('Français')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );

  Future<void> _pickReciter(BuildContext context, WidgetRef ref) async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Récitateur'),
        children: [
          for (final r in reciters)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r.id),
              child: Text(r.name),
            ),
        ],
      ),
    );
    if (v != null) {
      ref.read(settingsControllerProvider.notifier).edit((p) => p.copyWith(reciter: v));
    }
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Thème'),
        children: [
          for (final theme in AppTheme.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, theme.id),
              child: Text(theme.label),
            ),
        ],
      ),
    );
    if (v != null) {
      ref.read(settingsControllerProvider.notifier).edit((p) => p.copyWith(theme: v));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsControllerProvider).valueOrNull ?? const Settings();
    final mastery = ref.read(masteryControllerProvider).valueOrNull ?? const MasteryState();
    final playlists = ref.read(playlistsControllerProvider).valueOrNull ?? const <Playlist>[];
    final payload = jsonEncode({
      'settings': settings.toJson(),
      'mastery': mastery.toJson(),
      'playlists': playlists.map((p) => p.toJson()).toList(),
    });
    await Clipboard.setData(ClipboardData(text: payload));
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export copié'),
        content: SingleChildScrollView(child: SelectableText(payload)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer (coller le JSON)'),
        content: TextField(controller: ctrl, maxLines: 6),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Importer')),
        ],
      ),
    );
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      if (map['settings'] is Map) {
        final next = Settings.fromJsonSanitized(
            (map['settings'] as Map).cast<String, dynamic>());
        await ref.read(settingsRepositoryProvider).save(next);
      }
      if (map['mastery'] is Map) {
        final next = MasteryState.fromJson(
            (map['mastery'] as Map).cast<String, dynamic>());
        await ref.read(masteryRepositoryProvider).save(next);
      }
      if (map['playlists'] is List) {
        final next = (map['playlists'] as List)
            .map((e) => Playlist.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        await ref.read(playlistsRepositoryProvider).save(next);
      }
      ref
        ..invalidate(settingsControllerProvider)
        ..invalidate(masteryControllerProvider)
        ..invalidate(playlistsControllerProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Import réussi.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('JSON invalide.')));
    }
  }
}
