import 'package:juzreviz/domain/model/enums.dart';

enum VeilMode { full, firstWords, hidden }

enum ScrollTempo { ahead, sync, behind }

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
    this.glossLang = 'fr',
    this.translationLang = 'fr',
    this.tafsirLanguage = 'fr',
    this.readerWordByWord = true,
    this.readerTranslation = true,
    this.tajweedColors = false,
    this.latinAyahNumbers = false,
    this.wordAudio = false,
    this.scrollTempo = ScrollTempo.sync,
    this.scrollTempoStrength = 0.5,
    this.tafsirOpen = false,
    this.theme = 'lanterne',
    this.immersiveAutoHide = true,
    this.focusMode = false,
    this.veilMode = VeilMode.full,
    this.veilWords = 3,
    this.masteryProfile = MasteryProfile.serenity,
    this.autoMaster = false,
    this.ambientDecor = false,
    this.keepScreenOn = false,
    this.dynamicColor = false,
    this.widgetEnabled = true,
    this.remindersEnabled = false,
    this.reminderTime = '08:00',
    this.reminderFrequency = 'daily',
    this.currentVerseKey = '1:1',
    this.coachmarkSeen = false,
  });

  factory Settings.fromJsonSanitized(Map<String, dynamic> j) {
    double asD(String k, double d) => (j[k] as num?)?.toDouble() ?? d;
    int asI(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    bool asB(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    String asS(String k, String d) => j[k] is String ? j[k] as String : d;
    const def = Settings();
    return Settings(
      reciter: asS('reciter', def.reciter),
      playbackRate: asD('playbackRate', def.playbackRate).clamp(0.5, 2.0),
      repeatMode:
          _enumFrom(AudioRepeatMode.values, j['repeatMode'], def.repeatMode),
      repeatCount: asI('repeatCount', def.repeatCount).clamp(1, 99),
      rangeCount: asI('rangeCount', def.rangeCount).clamp(1, 99),
      repeatPauseMs: asI('repeatPauseMs', def.repeatPauseMs).clamp(0, 60000),
      glossLang: asS('glossLang', def.glossLang),
      translationLang: asS('translationLang', def.translationLang),
      tafsirLanguage: asS('tafsirLanguage', def.tafsirLanguage),
      readerWordByWord: asB('readerWordByWord', def.readerWordByWord),
      readerTranslation: asB('readerTranslation', def.readerTranslation),
      tajweedColors: asB('tajweedColors', def.tajweedColors),
      latinAyahNumbers: asB('latinAyahNumbers', def.latinAyahNumbers),
      wordAudio: asB('wordAudio', def.wordAudio),
      scrollTempo:
          _enumFrom(ScrollTempo.values, j['scrollTempo'], def.scrollTempo),
      scrollTempoStrength:
          asD('scrollTempoStrength', def.scrollTempoStrength).clamp(0.0, 1.0),
      tafsirOpen: asB('tafsirOpen', def.tafsirOpen),
      theme: asS('theme', def.theme),
      immersiveAutoHide: asB('immersiveAutoHide', def.immersiveAutoHide),
      focusMode: asB('focusMode', def.focusMode),
      veilMode: _enumFrom(VeilMode.values, j['veilMode'], def.veilMode),
      veilWords: asI('veilWords', def.veilWords).clamp(1, 10),
      masteryProfile: masteryProfileFromString(
          asS('masteryProfile', def.masteryProfile.name)),
      autoMaster: asB('autoMaster', def.autoMaster),
      ambientDecor: asB('ambientDecor', def.ambientDecor),
      keepScreenOn: asB('keepScreenOn', def.keepScreenOn),
      dynamicColor: asB('dynamicColor', def.dynamicColor),
      widgetEnabled: asB('widgetEnabled', def.widgetEnabled),
      remindersEnabled: asB('remindersEnabled', def.remindersEnabled),
      reminderTime: asS('reminderTime', def.reminderTime),
      reminderFrequency: asS('reminderFrequency', def.reminderFrequency),
      currentVerseKey: asS('currentVerseKey', def.currentVerseKey),
      coachmarkSeen: asB('coachmarkSeen', def.coachmarkSeen),
    );
  }

  final String reciter;
  final double playbackRate;
  final AudioRepeatMode repeatMode;
  final int repeatCount;
  final int rangeCount;
  final int repeatPauseMs;
  final String glossLang;
  final String translationLang;
  final String tafsirLanguage;
  final bool readerWordByWord;
  final bool readerTranslation;
  final bool tajweedColors;
  final bool latinAyahNumbers;
  final bool wordAudio;
  final ScrollTempo scrollTempo;
  final double scrollTempoStrength;
  final bool tafsirOpen;
  final String theme;
  final bool immersiveAutoHide;
  final bool focusMode;
  final VeilMode veilMode;
  final int veilWords;
  final MasteryProfile masteryProfile;
  final bool autoMaster;
  final bool ambientDecor;
  final bool keepScreenOn;
  final bool dynamicColor;
  final bool widgetEnabled;
  final bool remindersEnabled;
  final String reminderTime;
  final String reminderFrequency;
  final String currentVerseKey;
  final bool coachmarkSeen;

  Map<String, dynamic> toJson() => {
        'reciter': reciter,
        'playbackRate': playbackRate,
        'repeatMode': repeatMode.name,
        'repeatCount': repeatCount,
        'rangeCount': rangeCount,
        'repeatPauseMs': repeatPauseMs,
        'glossLang': glossLang,
        'translationLang': translationLang,
        'tafsirLanguage': tafsirLanguage,
        'readerWordByWord': readerWordByWord,
        'readerTranslation': readerTranslation,
        'tajweedColors': tajweedColors,
        'latinAyahNumbers': latinAyahNumbers,
        'wordAudio': wordAudio,
        'scrollTempo': scrollTempo.name,
        'scrollTempoStrength': scrollTempoStrength,
        'tafsirOpen': tafsirOpen,
        'theme': theme,
        'immersiveAutoHide': immersiveAutoHide,
        'focusMode': focusMode,
        'veilMode': veilMode.name,
        'veilWords': veilWords,
        'masteryProfile': masteryProfile.name,
        'autoMaster': autoMaster,
        'ambientDecor': ambientDecor,
        'keepScreenOn': keepScreenOn,
        'dynamicColor': dynamicColor,
        'widgetEnabled': widgetEnabled,
        'remindersEnabled': remindersEnabled,
        'reminderTime': reminderTime,
        'reminderFrequency': reminderFrequency,
        'currentVerseKey': currentVerseKey,
        'coachmarkSeen': coachmarkSeen,
      };

  Settings copyWith({
    String? reciter,
    double? playbackRate,
    AudioRepeatMode? repeatMode,
    int? repeatCount,
    int? rangeCount,
    int? repeatPauseMs,
    String? glossLang,
    String? translationLang,
    String? tafsirLanguage,
    bool? readerWordByWord,
    bool? readerTranslation,
    bool? tajweedColors,
    bool? latinAyahNumbers,
    bool? wordAudio,
    ScrollTempo? scrollTempo,
    double? scrollTempoStrength,
    bool? tafsirOpen,
    String? theme,
    bool? immersiveAutoHide,
    bool? focusMode,
    VeilMode? veilMode,
    int? veilWords,
    MasteryProfile? masteryProfile,
    bool? autoMaster,
    bool? ambientDecor,
    bool? keepScreenOn,
    bool? dynamicColor,
    bool? widgetEnabled,
    bool? remindersEnabled,
    String? reminderTime,
    String? reminderFrequency,
    String? currentVerseKey,
    bool? coachmarkSeen,
  }) =>
      Settings(
        reciter: reciter ?? this.reciter,
        playbackRate: playbackRate ?? this.playbackRate,
        repeatMode: repeatMode ?? this.repeatMode,
        repeatCount: repeatCount ?? this.repeatCount,
        rangeCount: rangeCount ?? this.rangeCount,
        repeatPauseMs: repeatPauseMs ?? this.repeatPauseMs,
        glossLang: glossLang ?? this.glossLang,
        translationLang: translationLang ?? this.translationLang,
        tafsirLanguage: tafsirLanguage ?? this.tafsirLanguage,
        readerWordByWord: readerWordByWord ?? this.readerWordByWord,
        readerTranslation: readerTranslation ?? this.readerTranslation,
        tajweedColors: tajweedColors ?? this.tajweedColors,
        latinAyahNumbers: latinAyahNumbers ?? this.latinAyahNumbers,
        wordAudio: wordAudio ?? this.wordAudio,
        scrollTempo: scrollTempo ?? this.scrollTempo,
        scrollTempoStrength: scrollTempoStrength ?? this.scrollTempoStrength,
        tafsirOpen: tafsirOpen ?? this.tafsirOpen,
        theme: theme ?? this.theme,
        immersiveAutoHide: immersiveAutoHide ?? this.immersiveAutoHide,
        focusMode: focusMode ?? this.focusMode,
        veilMode: veilMode ?? this.veilMode,
        veilWords: veilWords ?? this.veilWords,
        masteryProfile: masteryProfile ?? this.masteryProfile,
        autoMaster: autoMaster ?? this.autoMaster,
        ambientDecor: ambientDecor ?? this.ambientDecor,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        dynamicColor: dynamicColor ?? this.dynamicColor,
        widgetEnabled: widgetEnabled ?? this.widgetEnabled,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderTime: reminderTime ?? this.reminderTime,
        reminderFrequency: reminderFrequency ?? this.reminderFrequency,
        currentVerseKey: currentVerseKey ?? this.currentVerseKey,
        coachmarkSeen: coachmarkSeen ?? this.coachmarkSeen,
      );
}
