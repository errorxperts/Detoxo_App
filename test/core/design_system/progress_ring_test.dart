import 'dart:math' as math;

import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final _key = GlobalKey();

Future<void> _pump(
  WidgetTester tester, {
  required double? progress,
  required Brightness brightness,
  AccentPalette? palette,
}) => tester.pumpWidget(
  MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: _key,
          child: ProgressRing(
            progress: progress,
            palette: palette,
            child: const Text('2h 15m'),
          ),
        ),
      ),
    ),
  ),
);

double _distance(Color a, Color b) => math.sqrt(
  math.pow(a.r - b.r, 2) + math.pow(a.g - b.g, 2) + math.pow(a.b - b.b, 2),
);

void main() {
  for (final brightness in Brightness.values) {
    final t = AppTokens.forBrightness(brightness);
    for (final (name, palette) in [('brand', null), ('pause', t.pause)]) {
      for (final progress in const [null, 0.0, 0.5, 1.0]) {
        testWidgets('$progress × $name paints in ${brightness.name}', (
          tester,
        ) async {
          await _pump(
            tester,
            progress: progress,
            brightness: brightness,
            palette: palette,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('2h 15m'), findsOneWidget);
          expect(
            tester.getSize(find.byType(ProgressRing)),
            const Size(300, 300),
          );
        });
      }
    }
  }

  testWidgets('null progress draws the track only: no arc, no knob', (
    tester,
  ) async {
    const white = Color(0xFFFFFFFF);
    // 6 o'clock on the track, where a half arc ends in the white knob (the
    // disc's shadow, painted over it as in the spec, tints it a touch).
    const bottom = Offset(150, 281);
    await _pump(tester, progress: 0.5, brightness: Brightness.light);
    expect(_distance((await _pixels(tester))(bottom), white), lessThan(0.1));

    await _pump(tester, progress: null, brightness: Brightness.light);
    final bare = await _pixels(tester);
    for (final o in const [bottom, Offset(150, 19)]) {
      expect(_distance(bare(o), white), greaterThan(0.15), reason: '$o');
    }
  });

  testWidgets(
    'the arc runs main at bottom-left to deep at top-right (SVG −90° turn)',
    (tester) async {
      await _pump(tester, progress: 1, brightness: Brightness.light);
      final brand = AppTokens.light.brand;
      final pixels = await _pixels(tester);
      // On the track (r 131 from the centre) at 7:30 and 1:30.
      const d = 131 * math.sqrt1_2;
      final bottomLeft = pixels(const Offset(150 - d, 150 + d));
      final topRight = pixels(const Offset(150 + d, 150 - d));
      expect(
        _distance(bottomLeft, brand.main),
        lessThan(_distance(bottomLeft, brand.deep)),
      );
      expect(
        _distance(topRight, brand.deep),
        lessThan(_distance(topRight, brand.main)),
      );
    },
  );
}

/// Reads the ring's rendered pixels; the lookup takes ring coordinates.
Future<Color Function(Offset)> _pixels(WidgetTester tester) async {
  final boundary =
      _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData();
    image.dispose();
    return data!;
  }))!;
  final width = boundary.size.width.round();
  return (Offset o) {
    final i = (o.dy.round() * width + o.dx.round()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  };
}
