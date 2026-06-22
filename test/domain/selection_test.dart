import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/domain/model/selection.dart';

void main() {
  test('round-trip JSON des variantes de Selection', () {
    final cases = <Selection>[
      const SelJuz(5),
      const SelSurah(2, 255, 257),
      const SelReview('Révision', ['2:255', '36:1']),
    ];
    for (final s in cases) {
      final back = Selection.fromJson(s.toJson());
      expect(back, s, reason: 'égalité de valeur après round-trip');
      expect(back.toJson(), s.toJson());
    }
  });

  test('labels lisibles', () {
    expect(const SelSurah(2, 255, 255).label, '2:255');
    expect(const SelSurah(2, 255, 257).label, '2:255–257');
    expect(const SelJuz(3).label, 'Juz 3');
  });
}
