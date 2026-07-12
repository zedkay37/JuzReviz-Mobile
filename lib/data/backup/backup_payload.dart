import 'dart:convert';

import 'package:juzreviz/data/mastery/mastery_state.dart';
import 'package:juzreviz/data/playlists/playlist.dart';
import 'package:juzreviz/data/settings/settings.dart';
import 'package:juzreviz/domain/model/selection.dart';

/// Format complet de sauvegarde locale.
///
/// Les anciennes sauvegardes sans [schema] restent acceptées, mais les trois
/// sections sont obligatoires afin qu'un collage partiel ne remplace pas
/// silencieusement une partie de l'état par des valeurs vides.
class BackupPayload {
  const BackupPayload({
    required this.settings,
    required this.mastery,
    required this.playlists,
  });

  static const currentSchema = 1;

  final Settings settings;
  final MasteryState mastery;
  final List<Playlist> playlists;

  String encode() => jsonEncode({
    'schema': currentSchema,
    'settings': settings.toJson(),
    'mastery': mastery.toJson(),
    'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
  });

  /// Valide strictement toutes les sections avant que l'appelant n'écrive le
  /// premier fichier. Les parseurs tolérants de l'app ne sont appelés qu'après
  /// cette validation dédiée aux sauvegardes.
  factory BackupPayload.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException('Sauvegarde invalide');
    final map = decoded.cast<String, dynamic>();
    final rawSchema = map['schema'];
    final versioned = rawSchema != null;
    if (versioned &&
        (rawSchema is! num ||
            rawSchema.toInt() != rawSchema ||
            rawSchema.toInt() != currentSchema)) {
      throw const FormatException('Version de sauvegarde non prise en charge');
    }

    const sections = {'settings', 'mastery', 'playlists'};
    if (!sections.every(map.containsKey)) {
      throw const FormatException('Sauvegarde incomplète');
    }
    if (versioned &&
        map.keys.any((key) => key != 'schema' && !sections.contains(key))) {
      throw const FormatException('Champ de sauvegarde inconnu');
    }

    final settingsMap = _stringMap(map['settings'], 'Réglages invalides');
    final masteryMap = _stringMap(map['mastery'], 'Progression invalide');
    final rawPlaylists = map['playlists'];
    if (rawPlaylists is! List) {
      throw const FormatException('Playlists invalides');
    }

    // L'ancien export contenait déjà toutes les clés de ces deux sections.
    // Exiger leur complétude évite qu'un JSON manuel partiel réinitialise le
    // reste des données via les valeurs par défaut des parseurs tolérants.
    _validateSettings(settingsMap, requireComplete: true);
    _validateMastery(masteryMap, requireComplete: true);
    final playlists = <Playlist>[];
    for (final rawPlaylist in rawPlaylists) {
      final playlistMap = _stringMap(rawPlaylist, 'Playlist invalide');
      _validatePlaylist(playlistMap);
      playlists.add(Playlist.fromJson(playlistMap));
    }

    return BackupPayload(
      settings: Settings.fromJsonSanitized(settingsMap),
      mastery: MasteryState.fromJson(masteryMap),
      playlists: List.unmodifiable(playlists),
    );
  }
}

Map<String, dynamic> _stringMap(Object? raw, String message) {
  if (raw is! Map) throw FormatException(message);
  try {
    return raw.cast<String, dynamic>();
  } catch (_) {
    throw FormatException(message);
  }
}

void _validateSettings(
  Map<String, dynamic> map, {
  required bool requireComplete,
}) {
  final defaults = const Settings().toJson();
  if (map.isEmpty ||
      map.keys.any((key) => !defaults.containsKey(key)) ||
      (requireComplete && !defaults.keys.every(map.containsKey))) {
    throw const FormatException('Réglages incomplets ou inconnus');
  }
  for (final entry in map.entries) {
    final expected = defaults[entry.key];
    final value = entry.value;
    final valid = switch (expected) {
      bool _ => value is bool,
      num _ => value is num,
      String _ => value is String,
      _ => false,
    };
    if (!valid) throw FormatException('Réglage ${entry.key} invalide');
  }
}

void _validateMastery(
  Map<String, dynamic> map, {
  required bool requireComplete,
}) {
  const fields = {
    'fragile',
    'mastered',
    'scarred',
    'memorizedSurahs',
    'sessionDays',
  };
  if (map.isEmpty ||
      map.keys.any((key) => !fields.contains(key)) ||
      (requireComplete && !fields.every(map.containsKey))) {
    throw const FormatException('Progression incomplète ou inconnue');
  }

  final fragile = _stringMap(map['fragile'] ?? const {}, 'Fragilité invalide');
  for (final entry in fragile.entries) {
    if (!_isVerseKey(entry.key)) {
      throw const FormatException('Clé fragile invalide');
    }
    final value = _stringMap(entry.value, 'Fragilité invalide');
    if (value.keys.any((key) => key != 'markedAtMs' && key != 'count') ||
        value['markedAtMs'] is! num ||
        value['count'] is! num) {
      throw const FormatException('Fragilité invalide');
    }
  }

  final mastered = _stringMap(map['mastered'] ?? const {}, 'Maîtrise invalide');
  for (final entry in mastered.entries) {
    if (!_isVerseKey(entry.key)) {
      throw const FormatException('Clé maîtrisée invalide');
    }
    final value = _stringMap(entry.value, 'Maîtrise invalide');
    if (value.keys.any((key) => key != 'masteredAtMs') ||
        value['masteredAtMs'] is! num) {
      throw const FormatException('Maîtrise invalide');
    }
  }

  _validateStringList(map['scarred'] ?? const [], _isVerseKey, 'Cicatrices');
  _validateStringList(map['sessionDays'] ?? const [], _isDayKey, 'Jours');
  final memorized = map['memorizedSurahs'] ?? const [];
  if (memorized is! List ||
      memorized.any(
        (value) => value is! num || value.toInt() < 1 || value.toInt() > 114,
      )) {
    throw const FormatException('Sourates mémorisées invalides');
  }
}

void _validatePlaylist(Map<String, dynamic> map) {
  if (map.keys.any((key) => key != 'id' && key != 'name' && key != 'items') ||
      map['id'] is! String ||
      (map['id'] as String).isEmpty ||
      map['name'] is! String ||
      map['items'] is! List) {
    throw const FormatException('Playlist invalide');
  }
  for (final rawItem in map['items'] as List) {
    final item = _stringMap(rawItem, 'Élément de playlist invalide');
    if (item.keys.any(
          (key) => key != 'id' && key != 'label' && key != 'selection',
        ) ||
        item['id'] is! String ||
        (item['id'] as String).isEmpty ||
        item['label'] is! String) {
      throw const FormatException('Élément de playlist invalide');
    }
    final selection = _stringMap(
      item['selection'],
      'Sélection de playlist invalide',
    );
    Selection.fromJson(selection);
  }
}

void _validateStringList(
  Object? raw,
  bool Function(String) validate,
  String label,
) {
  if (raw is! List ||
      raw.any((value) => value is! String || !validate(value))) {
    throw FormatException('$label invalides');
  }
}

bool _isVerseKey(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return false;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  return surah != null &&
      ayah != null &&
      surah >= 1 &&
      surah <= 114 &&
      ayah >= 1 &&
      ayah <= 286;
}

bool _isDayKey(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse(value) != null;
