import 'dart:collection';

import 'package:juzreviz/data/settings/settings.dart';

/// Vue paresseuse du plan progressif.
///
/// La fenêtre `n` contient les clés `0..n-1`. La séquence aplatie compte donc
/// `N * (N + 1) / 2` éléments, mais seule une copie des [N] clés source est
/// conservée. L'accès aléatoire retrouve la fenêtre par recherche binaire.
class _ProgressivePlaybackList extends ListBase<String> {
  _ProgressivePlaybackList(List<String> keys)
    : _keys = List<String>.of(keys, growable: false),
      _length = keys.length * (keys.length + 1) ~/ 2;

  final List<String> _keys;
  final int _length;

  @override
  int get length => _length;

  @override
  set length(int value) =>
      throw UnsupportedError('Le plan progressif est en lecture seule.');

  @override
  String operator [](int index) {
    RangeError.checkValidIndex(index, this);

    // Première fenêtre dont le nombre triangulaire est strictement supérieur
    // à l'index aplati. Les fenêtres sont numérotées à partir de 1.
    var low = 1;
    var high = _keys.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      final endExclusive = middle * (middle + 1) ~/ 2;
      if (index < endExclusive) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }

    final windowStart = (low - 1) * low ~/ 2;
    return _keys[index - windowStart];
  }

  @override
  void operator []=(int index, String value) =>
      throw UnsupportedError('Le plan progressif est en lecture seule.');
}

/// Développe une liste de versets en séquence de lecture selon le mode de
/// répétition. Pur & testable — pilote le moteur audio du Reader.
///
/// - `off`        : chaque verset une fois.
/// - `ayah`       : chaque verset répété `repeatCount` fois.
/// - `range`      : tout le passage répété `rangeCount` fois.
/// - `progressive`: fenêtres cumulatives (1, 1-2, 1-2-3…) — mémorisation.
List<String> expandPlayback(
  List<String> keys,
  AudioRepeatMode mode, {
  int repeatCount = 1,
  int rangeCount = 1,
}) {
  if (keys.isEmpty) return const [];
  final rc = repeatCount.clamp(1, 99);
  final gc = rangeCount.clamp(1, 99);
  switch (mode) {
    case AudioRepeatMode.off:
      return List<String>.of(keys);
    case AudioRepeatMode.ayah:
      return [
        for (final k in keys)
          for (var i = 0; i < rc; i++) k,
      ];
    case AudioRepeatMode.range:
      return [for (var r = 0; r < gc; r++) ...keys];
    case AudioRepeatMode.progressive:
      return _ProgressivePlaybackList(keys);
  }
}

/// Alignement vertical de l'auto-scroll selon le tempo de défilement.
/// `ahead` place le verset courant plus haut (anticipation), `behind` plus bas.
double scrollAlignmentFor(ScrollTempo tempo, double strength) {
  const base = 0.35;
  final amp = 0.25 * strength.clamp(0.0, 1.0);
  return switch (tempo) {
    ScrollTempo.ahead => (base - amp).clamp(0.0, 1.0),
    ScrollTempo.sync => base,
    ScrollTempo.behind => (base + amp).clamp(0.0, 1.0),
  };
}
