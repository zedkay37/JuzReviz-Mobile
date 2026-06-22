import 'package:juzreviz/data/settings/settings.dart';

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
      return [
        for (var r = 0; r < gc; r++) ...keys,
      ];
    case AudioRepeatMode.progressive:
      return [
        for (var n = 1; n <= keys.length; n++) ...keys.sublist(0, n),
      ];
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
