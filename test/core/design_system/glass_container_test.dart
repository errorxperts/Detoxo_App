import 'package:detoxo/core/design_system/foundations/glass_container.dart';
import 'package:detoxo/core/design_system/foundations/liquid_glass_border.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme pulls google_fonts, which stalls under flutter_test. GlassContainer
// only needs GlassTokens plus a ColorScheme.
ThemeData _theme(Brightness brightness) => ThemeData(
  brightness: brightness,
  extensions: [
    if (brightness == Brightness.dark) GlassTokens.dark else GlassTokens.light,
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  bool liquidEdge = true,
  bool enableBlur = true,
  bool selected = false,
  bool circle = false,
  Brightness brightness = Brightness.dark,
}) => tester.pumpWidget(
  MaterialApp(
    theme: _theme(brightness),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 200,
          height: 120,
          child: GlassContainer(
            liquidEdge: liquidEdge,
            enableBlur: enableBlur,
            selected: selected,
            circle: circle,
            child: const Text('glass'),
          ),
        ),
      ),
    ),
  ),
);

/// Every shadow list anywhere under the container, flattened.
List<BoxShadow> _shadowsIn(WidgetTester tester) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byType(GlassContainer),
      matching: find.byType(DecoratedBox),
    ),
  ))
    ...switch (box.decoration) {
      final ShapeDecoration d => d.shadows ?? const <BoxShadow>[],
      final BoxDecoration d => d.boxShadow ?? const <BoxShadow>[],
      _ => const <BoxShadow>[],
    },
];

void main() {
  // Depth is supposed to come from the glass itself. A stray BoxShadow puts a
  // grey smudge back under every surface in the app — and one with its colour
  // omitted defaults to opaque black, which is worse.
  group('casts no shadow', () {
    for (final liquidEdge in [true, false]) {
      for (final selected in [true, false]) {
        for (final enableBlur in [true, false]) {
          testWidgets(
            'liquidEdge=$liquidEdge selected=$selected blur=$enableBlur',
            (tester) async {
              await _pump(
                tester,
                liquidEdge: liquidEdge,
                selected: selected,
                enableBlur: enableBlur,
              );
              expect(_shadowsIn(tester), isEmpty);
            },
          );
        }
      }
    }
  });

  testWidgets('lights the edge by default', (tester) async {
    await _pump(tester);
    expect(find.byType(LiquidGlassBorder), findsOneWidget);
  });

  testWidgets('liquidEdge: false falls back to the flat hairline', (
    tester,
  ) async {
    await _pump(tester, liquidEdge: false);
    expect(find.byType(LiquidGlassBorder), findsNothing);
    expect(find.text('glass'), findsOneWidget);
  });

  testWidgets('circle and squircle both render', (tester) async {
    await _pump(tester, circle: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(LiquidGlassBorder), findsOneWidget);
  });
}
