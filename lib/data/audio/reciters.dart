/// Récitateurs disponibles + construction d'URL (everyayah).
class Reciter {
  const Reciter(this.id, this.name, this.folder);
  final String id;
  final String name;

  /// Dossier everyayah (ex. `Alafasy_128kbps`).
  final String folder;
}

const reciters = <Reciter>[
  Reciter('ar.alafasy', 'Mishary Al-Afasy', 'Alafasy_128kbps'),
  Reciter('ar.husary', 'Mahmoud Al-Husary', 'Husary_128kbps'),
  Reciter('ar.minshawi', 'Al-Minshawi', 'Minshawy_Murattal_128kbps'),
  Reciter('ar.sudais', 'Abdurrahman As-Sudais', 'Abdurrahmaan_As-Sudais_192kbps'),
];

Reciter reciterById(String id) =>
    reciters.firstWhere((r) => r.id == id, orElse: () => reciters.first);

String _pad3(int n) => n.toString().padLeft(3, '0');

/// URL d'un verset chez everyayah pour un récitateur donné.
String verseAudioUrl(String reciterId, String verseKey) {
  final parts = verseKey.split(':');
  final surah = int.parse(parts[0]);
  final ayah = int.parse(parts[1]);
  final folder = reciterById(reciterId).folder;
  return 'https://everyayah.com/data/$folder/${_pad3(surah)}${_pad3(ayah)}.mp3';
}
