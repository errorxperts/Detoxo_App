import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: AppTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

Widget _pressable(VoidCallback onTap) => AppPressable(
  onTap: onTap,
  haptic: false,
  semanticLabel: 'Card',
  child: const SizedBox(width: 120, height: 60),
);

double _scale(WidgetTester tester) => tester
    .widget<AnimatedScale>(
      find.descendant(
        of: find.byType(AppPressable),
        matching: find.byType(AnimatedScale),
      ),
    )
    .scale;

void main() {
  testWidgets('Tab draws the focus ring; Enter activates once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(_pressable(() => taps++)));
    expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.widget<FocusRing>(find.byType(FocusRing)).visible, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('pressing scales to .975, and back on release', (tester) async {
    await tester.pumpWidget(_app(_pressable(() {})));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    await tester.pump();
    expect(_scale(tester), 0.975);
    await gesture.up();
    await tester.pump();
    expect(_scale(tester), 1);
  });

  testWidgets('Reduce Motion: no scale while pressed', (tester) async {
    await tester.pumpWidget(_app(_pressable(() {}), reduceMotion: true));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AppPressable)),
    );
    await tester.pump();
    expect(_scale(tester), 1);
    await gesture.up();
  });

  testWidgets('GlassAppBar back button: a 44 px glass circle, by tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GlassScaffold(
                    appBar: GlassAppBar(title: Text('Pushed')),
                    body: SizedBox(),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsOneWidget);
    expect(find.byType(GlassIconButton), findsOneWidget);
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(GlassIconButton),
          matching: find.byType(GlassContainer),
        ),
      ),
      const Size.square(44),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsNothing);
  });
}
