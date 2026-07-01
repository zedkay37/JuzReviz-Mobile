// Enums du domaine — pur Dart, aucun import Flutter.

enum Revelation { meccan, medinan }

enum MasteryProfile { serenity, excellence }

/// État de « chaleur » d'un verset (calculé à l'affichage, jamais stocké).
/// Seul modèle d'état de mémorisation de l'app — pas de doublon manuel.
enum HeatState { fragile, fresh, fading, stale, blank }

Revelation revelationFromString(String s) =>
    s.toLowerCase() == 'medinan' ? Revelation.medinan : Revelation.meccan;

MasteryProfile masteryProfileFromString(String s) =>
    s.toLowerCase() == 'excellence'
        ? MasteryProfile.excellence
        : MasteryProfile.serenity;
