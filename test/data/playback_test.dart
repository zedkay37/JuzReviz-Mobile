import 'package:flutter_test/flutter_test.dart';
import 'package:juzreviz/data/audio/playback.dart';
import 'package:juzreviz/data/settings/settings.dart';

void main() {
  const keys = ['2:1', '2:2', '2:3'];

  group('expandPlayback', () {
    test('off → chaque verset une fois', () {
      expect(expandPlayback(keys, AudioRepeatMode.off), keys);
    });

    test('ayah → chaque verset répété N fois', () {
      expect(
        expandPlayback(keys, AudioRepeatMode.ayah, repeatCount: 2),
        ['2:1', '2:1', '2:2', '2:2', '2:3', '2:3'],
      );
    });

    test('range → passage entier répété N fois', () {
      expect(
        expandPlayback(keys, AudioRepeatMode.range, rangeCount: 2),
        [...keys, ...keys],
      );
    });

    test('progressive → fenêtres cumulatives', () {
      expect(
        expandPlayback(keys, AudioRepeatMode.progressive),
        ['2:1', '2:1', '2:2', '2:1', '2:2', '2:3'],
      );
    });

    test('liste vide → vide', () {
      expect(expandPlayback(const [], AudioRepeatMode.ayah), isEmpty);
    });
  });

  group('scrollAlignmentFor', () {
    test('ahead < sync < behind', () {
      final ahead = scrollAlignmentFor(ScrollTempo.ahead, 1);
      final sync = scrollAlignmentFor(ScrollTempo.sync, 1);
      final behind = scrollAlignmentFor(ScrollTempo.behind, 1);
      expect(ahead, lessThan(sync));
      expect(sync, lessThan(behind));
    });

    test('amplitude nulle si strength 0', () {
      expect(scrollAlignmentFor(ScrollTempo.ahead, 0),
          scrollAlignmentFor(ScrollTempo.sync, 0));
    });
  });
}
