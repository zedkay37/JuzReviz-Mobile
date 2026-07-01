import 'package:juzreviz/domain/model/enums.dart';

/// Libellé FR de l'unique état de mémorisation (`HeatState`), utilisé partout
/// (Atlas, drill, programme du jour) — source unique de vocabulaire.
String heatLabelFr(HeatState s) => switch (s) {
      HeatState.fragile => 'Fragile',
      HeatState.fresh => 'Frais',
      HeatState.fading => 'À rafraîchir',
      HeatState.stale => 'À revoir',
      HeatState.blank => 'Vierge',
    };
