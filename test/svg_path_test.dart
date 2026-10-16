import 'dart:ui';

import 'package:detoxo/features/content_counter/content_counter_bubble/presentation/svg_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bounds of a square', () {
    expect(
      parseSvgPath('M0 0 h10 v10 z').getBounds(),
      const Rect.fromLTWH(0, 0, 10, 10),
    );
  });

  test('glued negatives', () {
    final b = parseSvgPath('M1 1 q0 8-8 8').getBounds();
    expect(b.left, closeTo(-7, 1e-6));
    expect(b.width, closeTo(8, 1e-6));
  });

  test('the hourglass mark', () {
    final path = parseSvgPath(
      'M9 3 H31 Q37 3 37 9 V17 Q37 23 30 29 L27 32 L30 35 Q37 41 37 47 V55 Q37 61 31 61 H9 Q3 61 3 55 V47 Q3 41 10 35 L13 32 L10 29 Q3 23 3 17 V9 Q3 3 9 3 Z',
    );
    final b = path.getBounds();
    expect(b.left, closeTo(3, 1e-6));
    expect(b.top, closeTo(3, 1e-6));
    expect(b.right, closeTo(37, 1e-6));
    expect(b.bottom, closeTo(61, 1e-6));
  });

  test('unknown command throws', () {
    expect(() => parseSvgPath('M0 0 A1 1 0 0 1 2 2'), throwsFormatException);
  });
}
