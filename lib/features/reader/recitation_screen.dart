import 'package:flutter/widgets.dart';
import 'package:juzreviz/domain/model/selection.dart';
import 'package:juzreviz/features/reader/reader_screen.dart';

/// Écran « Réciter » : écoute karaoké (arabe seul, surlignage du verset en
/// cours, transport audio en vraie zone de bas d'écran). Point d'entrée
/// distinct de [ReaderScreen] (étude silencieuse), même moteur audio/scroll.
class RecitationScreen extends StatelessWidget {
  const RecitationScreen({super.key, required this.selection});
  final Selection selection;

  @override
  Widget build(BuildContext context) =>
      ReaderScreen(selection: selection, mode: ReaderMode.recitation);
}
