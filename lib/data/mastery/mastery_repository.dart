import 'package:juzreviz/data/common/json_store.dart';
import 'package:juzreviz/data/mastery/mastery_state.dart';

class MasteryRepository {
  MasteryRepository(this._store);
  final JsonStore _store;
  static const _name = 'mastery';

  Future<MasteryState> load() async {
    final raw = await _store.read(_name);
    if (raw == null) return const MasteryState();
    return MasteryState.fromJson(raw);
  }

  Future<void> save(MasteryState state) => _store.write(_name, state.toJson());
}
