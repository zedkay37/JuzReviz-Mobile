import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/settings/settings.dart';

/// Charge/persiste les réglages (JSON sanitisé). Source de vérité applicative.
class SettingsRepository {
  SettingsRepository(this._store);
  final JsonStore _store;
  static const _name = 'settings';

  Future<Settings> load() async {
    final raw = await _store.read(_name);
    if (raw == null) return const Settings();
    return Settings.fromJsonSanitized(raw);
  }

  Future<void> save(Settings settings) =>
      _store.write(_name, settings.toJson());
}
