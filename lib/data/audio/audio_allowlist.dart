/// Allowlist stricte des sources audio (sécurité §11).
const audioAllowedHosts = <String>{
  'everyayah.com',
  'www.everyayah.com',
  'audio.qurancdn.com',
};

bool isAllowedAudioUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.isScheme('https')) return false;
  return audioAllowedHosts.contains(uri.host);
}
