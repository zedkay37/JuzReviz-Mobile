// Enums du domaine — pur Dart, aucun import Flutter.

enum Revelation { meccan, medinan }

enum MasteryProfile { serenity, excellence }

/// État de « chaleur » d'un verset (calculé à l'affichage, jamais stocké).
enum HeatState { fragile, fresh, fading, stale, blank }

/// État « net » pour les badges.
enum FlagState { fragile, mastered, blank }

Revelation revelationFromString(String s) =>
    s.toLowerCase() == 'medinan' ? Revelation.medinan : Revelation.meccan;

MasteryProfile masteryProfileFromString(String s) =>
    s.toLowerCase() == 'excellence'
        ? MasteryProfile.excellence
        : MasteryProfile.serenity;
