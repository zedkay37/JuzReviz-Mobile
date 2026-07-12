import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/core/routing/app_router.dart';
import 'package:juzreviz/domain/model/selection.dart';

void main() {
  const fallback = SelSurah(1, 1, 7);

  test('selectionFromQuery accepte uniquement les bornes canoniques', () {
    expect(selectionFromQuery({'juz': '30'}, fallback), const SelJuz(30));
    expect(selectionFromQuery({'juz': '31'}, fallback), fallback);
    expect(
      selectionFromQuery({'s': '18', 'from': '10', 'to': '1'}, fallback),
      const SelSurah(18, 10, 10),
    );
    expect(selectionFromQuery({'s': '999'}, fallback), fallback);
  });
}
