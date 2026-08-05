import 'package:detoxo/core/design_system/foundations/liquid_glass_border.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/core/design_system/tokens/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The painter reads GlassTokens and nothing else, so the tests register the
// extension directly rather than building AppTheme (which pulls google_fonts
// and stalls under flutter_test).
ThemeData _theme(Brightness brightness) => ThemeData(
  brightness: brightness,
  extensions: [
    if (brightness == Brightness.dark) GlassTokens.dark else GlassTokens.light,
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required ShapeBorder? shape,
  required Brightness brightness,
  double intensity = 1,
  Size size = const Size(120, 150),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme(brightness),
      home: Scaffold(
        body: Center(
          child: SizedBox.fromSize(
            size: size,
            child: LiquidGlassBorder(
              shape: shape,
              intensity: intensity,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
  // MaterialApp lerps ThemeExtensions through AnimatedTheme — without settling,
  // the frame right after a theme change still carries the old GlassTokens.
  await tester.pumpAndSettle();
}

CustomPainter _painterOf(WidgetTester tester) => tester
    .widget<CustomPaint>(
      find.descendant(
        of: find.byType(LiquidGlassBorder),
        matching: find.byType(CustomPaint),
      ),
    )
    .foregroundPainter!;

void main() {
  final shapes = <String, ShapeBorder?>{
    'default squircle': null,
    'explicit radius': AppRadius.continuous(AppRadius.sm),
    'pill': AppRadius.continuous(AppRadius.pill),
    'circle': const CircleBorder(),
  };

  group('paints every shape on both brightnesses', () {
    for (final brightness in Brightness.values) {
      for (final shape in shapes.entries) {
        testWidgets('${shape.key} — ${brightness.name}', (tester) async {
          await _pump(tester, shape: shape.value, brightness: brightness);
          expect(tester.takeException(), isNull);
          expect(find.byType(LiquidGlassBorder), findsOneWidget);
        });
      }
    }
  });

  // The inner-highlight stroke is skipped below ~2.4px — guards the deflate.
  testWidgets('survives a degenerate size', (tester) async {
    await _pump(
      tester,
      shape: null,
      brightness: Brightness.dark,
      size: const Size(1, 1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero intensity paints nothing', (tester) async {
    await _pump(tester, shape: null, brightness: Brightness.dark, intensity: 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not repaint when nothing changed', (tester) async {
    await _pump(
      tester,
      shape: const CircleBorder(),
      brightness: Brightness.dark,
    );
    final first = _painterOf(tester);

    await _pump(
      tester,
      shape: const CircleBorder(),
      brightness: Brightness.dark,
    );
    expect(first.shouldRepaint(_painterOf(tester)), isFalse);
  });

  testWidgets('repaints when the theme flips brightness', (tester) async {
    await _pump(
      tester,
      shape: const CircleBorder(),
      brightness: Brightness.dark,
    );
    final dark = _painterOf(tester);

    await _pump(
      tester,
      shape: const CircleBorder(),
      brightness: Brightness.light,
    );
    expect(dark.shouldRepaint(_painterOf(tester)), isTrue);
  });
}
