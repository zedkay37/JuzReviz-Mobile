import 'package:juzreviz/data/audio/reciters.dart';
import 'package:juzreviz/domain/model/enums.dart';

enum VeilMode { full, firstWords, hidden }

enum ScrollTempo { ahead, sync, behind }

/// Disposition du lecteur. Une seule entrée mushaf : les polices QCF
/// téléchargées (hafs v1) n'ont pas de variante tajweed colorée.
enum ReaderLayout { mushaf, flexible, verseByVerse }

extension ReaderLayoutX on ReaderLayout {
  String get id => name;

  String get label => switch (this) {
    ReaderLayout.mushaf => 'Mushaf Madni',
    ReaderLayout.flexible => 'Flexible',
    ReaderLayout.verseByVerse => 'Verset par verset',
  };

  String get description => switch (this) {
    ReaderLayout.mushaf =>
      'Pages fixes du mushaf classique, polices d’imprimerie',
    ReaderLayout.flexible =>
      'Taille de police personnalisable et mise en page flexible',
    ReaderLayout.verseByVerse =>
      'Chaque verset avec traduction et signification des mots',
  };

  /// Le mushaf nécessite le pack de polices téléchargeable (~90 Mo).
  bool get available =>
      this == ReaderLayout.flexible || this == ReaderLayout.verseByVerse;
}

ReaderLayout readerLayoutFromString(String s) {
  // Migration : les anciens ids mushafTajweed/mushafMadni → mushaf.
  if (s == 'mushafTajweed' || s == 'mushafMadni') return ReaderLayout.mushaf;
  return ReaderLayout.values.firstWhere(
    (v) => v.name == s,
    orElse: () => ReaderLayout.flexible,
  );
}

enum AudioRepeatMode { off, ayah, range, progressive }

T _enumFrom<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
  }
  return fallback;
}

/// Réglages applicatifs — immuable, sanitisé au chargement.
/// **Toute clé absente reçoit un défaut** (parité avec la sanitisation desktop).
class Settings {
  const Settings({
    this.reciter = 'ar.alafasy',
    this.playbackRate = 1.0,
    this.repeatMode = AudioRepeatMode.off,
    this.repeatCount = 1,
    this.rangeCount = 1,
    this.repeatPauseMs = 0,
    this.contentLang = 'fr',
    this.readerWordByWord = true,
    this.readerTranslation = true,
    this.latinAyahNumbers = false,
    this.tajweedColors = false,
    this.wordAudio = false,
    this.theme = 'lanterne',
    this.veilMode = VeilMode.full,
    this.veilWords = 3,
    this.masteryProfile = MasteryProfile.serenity,
    this.autoMaster = false,
    this.remindersEnabled = false,
    this.reminderTime = '08:00',
    this.currentVerseKey = '1:1',
    this.coachmarkSeen = false,
    this.batteryTipSeen = false,
    this.readerLayout = 'flexible',
    this.fontScale = 1.0,
  });

  factory Settings.fromJsonSanitized(Map<String, dynamic> j) {
    double asD(String k, double d) =>
        j[k] is num ? (j[k] as num).toDouble() : d;
    int asI(String k, int d) => j[k] is num ? (j[k] as num).toInt() : d;
    bool asB(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    String asS(String k, String d) => j[k] is String ? j[k] as String : d;
    const def = Settings();
    final reciter = reciterById(asS('reciter', def.reciter)).id;
    final contentLang = asS('contentLang', def.contentLang) == 'en'
        ? 'en'
        : 'fr';
    final rawTheme = asS('theme', def.theme);
    const themes = {'lanterne', 'rawda', 'parchemin', 'highContrast'};
    final theme = themes.contains(rawTheme) ? rawTheme : def.theme;
    final reminderTime = _sanitizeReminderTime(
      asS('reminderTime', def.reminderTime),
      def.reminderTime,
    );
    final currentVerseKey = _sanitizeVerseKey(
      asS('currentVerseKey', def.currentVerseKey),
      def.currentVerseKey,
    );
    return Settings(
      reciter: reciter,
      playbackRate: asD('playbackRate', def.playbackRate).clamp(0.5, 2.0),
      repeatMode: _enumFrom(
        AudioRepeatMode.values,
        j['repeatMode'],
        def.repeatMode,
      ),
      repeatCount: asI('repeatCount', def.repeatCount).clamp(1, 99),
      rangeCount: asI('rangeCount', def.rangeCount).clamp(1, 99),
      repeatPauseMs: asI('repeatPauseMs', def.repeatPauseMs).clamp(0, 60000),
      contentLang: contentLang,
      readerWordByWord: asB('readerWordByWord', def.readerWordByWord),
      readerTranslation: asB('readerTranslation', def.readerTranslation),
      latinAyahNumbers: asB('latinAyahNumbers', def.latinAyahNumbers),
      tajweedColors: asB('tajweedColors', def.tajweedColors),
      wordAudio: asB('wordAudio', def.wordAudio),
      theme: theme,
      veilMode: _enumFrom(VeilMode.values, j['veilMode'], def.veilMode),
      veilWords: asI('veilWords', def.veilWords).clamp(1, 10),
      masteryProfile: masteryProfileFromString(
        asS('masteryProfile', def.masteryProfile.name),
      ),
      autoMaster: asB('autoMaster', def.autoMaster),
      remindersEnabled: asB('remindersEnabled', def.remindersEnabled),
      reminderTime: reminderTime,
      currentVerseKey: currentVerseKey,
      coachmarkSeen: asB('coachmarkSeen', def.coachmarkSeen),
      batteryTipSeen: asB('batteryTipSeen', def.batteryTipSeen),
      readerLayout: readerLayoutFromString(
        asS('readerLayout', def.readerLayout),
      ).id,
      fontScale: asD('fontScale', def.fontScale).clamp(0.7, 1.8),
    );
  }

  final String reciter;
  final double playbackRate;
  final AudioRepeatMode repeatMode;
  final int repeatCount;
  final int rangeCount;
  final int repeatPauseMs;

  /// Langue unique pour gloses, traduction et tafsir ('fr' ou 'en').
  final String contentLang;
  final bool readerWordByWord;
  final bool readerTranslation;
  final bool latinAyahNumbers;

  /// Coloration tajwid (sous-ensemble fiable : ghunnah, madd, qalqalah…).
  final bool tajweedColors;
  final bool wordAudio;
  final String theme;
  final VeilMode veilMode;
  final int veilWords;
  final MasteryProfile masteryProfile;
  final bool autoMaster;
  final bool remindersEnabled;
  final String reminderTime;
  final String currentVerseKey;
  final bool coachmarkSeen;

  /// Astuce batterie (audio coupé en arrière-plan) déjà affichée une fois.
  final bool batteryTipSeen;
  final String readerLayout;
  final double fontScale;

  Map<String, dynamic> toJson() => {
    'reciter': reciter,
    'playbackRate': playbackRate,
    'repeatMode': repeatMode.name,
    'repeatCount': repeatCount,
    'rangeCount': rangeCount,
    'repeatPauseMs': repeatPauseMs,
    'contentLang': contentLang,
    'readerWordByWord': readerWordByWord,
    'readerTranslation': readerTranslation,
    'latinAyahNumbers': latinAyahNumbers,
    'tajweedColors': tajweedColors,
    'wordAudio': wordAudio,
    'theme': theme,
    'veilMode': veilMode.name,
    'veilWords': veilWords,
    'masteryProfile': masteryProfile.name,
    'autoMaster': autoMaster,
    'remindersEnabled': remindersEnabled,
    'reminderTime': reminderTime,
    'currentVerseKey': currentVerseKey,
    'coachmarkSeen': coachmarkSeen,
    'batteryTipSeen': batteryTipSeen,
    'readerLayout': readerLayout,
    'fontScale': fontScale,
  };

  Settings copyWith({
    String? reciter,
    double? playbackRate,
    AudioRepeatMode? repeatMode,
    int? repeatCount,
    int? rangeCount,
    int? repeatPauseMs,
    String? contentLang,
    bool? readerWordByWord,
    bool? readerTranslation,
    bool? latinAyahNumbers,
    bool? tajweedColors,
    bool? wordAudio,
    String? theme,
    VeilMode? veilMode,
    int? veilWords,
    MasteryProfile? masteryProfile,
    bool? autoMaster,
    bool? remindersEnabled,
    String? reminderTime,
    String? currentVerseKey,
    bool? coachmarkSeen,
    bool? batteryTipSeen,
    String? readerLayout,
    double? fontScale,
  }) => Settings(
    reciter: reciter ?? this.reciter,
    playbackRate: playbackRate ?? this.playbackRate,
    repeatMode: repeatMode ?? this.repeatMode,
    repeatCount: repeatCount ?? this.repeatCount,
    rangeCount: rangeCount ?? this.rangeCount,
    repeatPauseMs: repeatPauseMs ?? this.repeatPauseMs,
    contentLang: contentLang ?? this.contentLang,
    readerWordByWord: readerWordByWord ?? this.readerWordByWord,
    readerTranslation: readerTranslation ?? this.readerTranslation,
    latinAyahNumbers: latinAyahNumbers ?? this.latinAyahNumbers,
    tajweedColors: tajweedColors ?? this.tajweedColors,
    wordAudio: wordAudio ?? this.wordAudio,
    theme: theme ?? this.theme,
    veilMode: veilMode ?? this.veilMode,
    veilWords: veilWords ?? this.veilWords,
    masteryProfile: masteryProfile ?? this.masteryProfile,
    autoMaster: autoMaster ?? this.autoMaster,
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderTime: reminderTime ?? this.reminderTime,
    currentVerseKey: currentVerseKey ?? this.currentVerseKey,
    coachmarkSeen: coachmarkSeen ?? this.coachmarkSeen,
    batteryTipSeen: batteryTipSeen ?? this.batteryTipSeen,
    readerLayout: readerLayout ?? this.readerLayout,
    fontScale: fontScale ?? this.fontScale,
  );
}

String _sanitizeReminderTime(String raw, String fallback) {
  final parts = raw.split(':');
  if (parts.length != 2) return fallback;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return fallback;
  }
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _sanitizeVerseKey(String raw, String fallback) {
  final parts = raw.split(':');
  if (parts.length != 2) return fallback;
  final surah = int.tryParse(parts[0]);
  final ayah = int.tryParse(parts[1]);
  if (surah == null ||
      ayah == null ||
      surah < 1 ||
      surah > 114 ||
      ayah < 1 ||
      ayah > 286) {
    return fallback;
  }
  return '$surah:$ayah';
}
