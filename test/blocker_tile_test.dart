import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:detoxo/features/dashboard/presentation/widgets/blocker_tile.dart';
import 'package:detoxo/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme pulls google_fonts, which stalls under flutter_test — the tile only
// needs GlassTokens plus a ColorScheme, so build a minimal theme here.
ThemeData _theme(Brightness brightness) => ThemeData(
  brightness: brightness,
  extensions: [
    if (brightness == Brightness.dark) GlassTokens.dark else GlassTokens.light,
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required bool active,
  Brightness brightness = Brightness.dark,
}) => tester.pumpWidget(
  MaterialApp(
    theme: _theme(brightness),
    // The capsule levitation and the status dot repeat forever, which would
    // leave pending timers at the end of every test. Reduced motion is a real
    // code path in both, so exercise that one.
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: Center(
          // ~half a phone's width, as on the dashboard. AspectRatio falls back
          // to constraints.biggest if the height it wants doesn't fit, so the
          // box has to be narrow enough for 4:5 to be satisfiable.
          child: SizedBox(
            width: 180,
            child: BlockerTile(
              image: Assets.images.illustration.block.path,
              title: 'App Blocker',
              caption: active ? '3 apps blocked' : 'Not set up',
              active: active,
              onTap: () {},
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  // The watermark is a scaled/translated overlay inside a Stack — easy to make
  // it demand unbounded width, and AspectRatio silently falls back to
  // constraints.biggest when what it wants doesn't fit. Asserting the real
  // geometry is what catches both.
  for (final brightness in Brightness.values) {
    for (final active in [true, false]) {
      testWidgets('lays out 1:1 — ${brightness.name}, active=$active', (
        tester,
      ) async {
        await _pump(tester, active: active, brightness: brightness);
        // The test bundle has no assets, so a decode failure is expected noise.
        expect(tester.takeException(), anyOf(isNull, isA<FlutterError>()));

        // Square, per `aspectRatio: 4 / 4` in blocker_tile.dart.
        expect(tester.getSize(find.byType(BlockerTile)), const Size(180, 180));
        expect(find.text('App Blocker'), findsOneWidget);
        expect(
          find.text(active ? '3 APPS BLOCKED' : 'NOT SET UP'),
          findsOneWidget,
        );
      });
    }
  }
}
