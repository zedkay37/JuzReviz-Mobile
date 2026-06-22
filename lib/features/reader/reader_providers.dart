import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juzreviz/app/providers.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/domain/model/verse.dart';

/// Versets d'une sélection (use case lecture : corpus → versets ordonnés).
final readerVersesProvider =
    FutureProvider.family<List<Verse>, Selection>((ref, selection) {
  return ref.read(corpusRepositoryProvider).versesForSelection(selection);
});
