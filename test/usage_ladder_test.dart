import 'package:detoxo/features/content_counter/content_counter_core/domain/usage_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('usage ladder', () {
    test('both ladders have 11 stops (0..500 stepping by 50)', () {
      expect(kBandStopsArgb.length, 11);
      expect(kEmojiLadder.length, 11);
    });

    test('bandIndexFor steps every 50 and caps at the last stop', () {
      expect(bandIndexFor(0), 0);
      expect(bandIndexFor(49), 0);
      expect(bandIndexFor(50), 1);
      expect(bandIndexFor(99), 1);
      expect(bandIndexFor(250), 5);
      expect(bandIndexFor(500), 10);
      expect(bandIndexFor(999), 10); // capped
      expect(bandIndexFor(-5), 0); // clamped low
    });

    test('bandColorFor/emojiFor resolve to the indexed stop', () {
      expect(bandColorFor(0).toARGB32(), kBandStopsArgb.first);
      expect(bandColorFor(9999).toARGB32(), kBandStopsArgb.last);
      expect(emojiFor(0), kEmojiLadder.first);
      expect(emojiFor(9999), kEmojiLadder.last);
    });
  });
}
