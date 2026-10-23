import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
}) => tester.pumpWidget(
  MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 200, height: 120, child: child)),
    ),
  ),
);

Finder _backdrop() => find.descendant(
  of: find.byType(GlassContainer),
  matching: find.byType(BackdropFilter),
);

void main() {
  group('roles', () {
    for (final brightness in Brightness.values) {
      for (final surface in DxSurface.values) {
        testWidgets('${surface.name} paints in ${brightness.name}', (
          tester,
        ) async {
          await _pump(
            tester,
            GlassContainer(surface: surface, child: const Text('glass')),
            brightness: brightness,
          );
          expect(find.text('glass'), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Only the floating roles blur what is behind them.
          final blurs =
              surface == DxSurface.glass || surface == DxSurface.sheet;
          expect(_backdrop(), blurs ? findsOneWidget : findsNothing);
        });
      }
    }

    testWidgets('backdrop: false switches the blur off, not the subtree', (
      tester,
    ) async {
      Widget glass({required bool backdrop}) => GlassContainer(
        surface: DxSurface.glass,
        backdrop: backdrop,
        child: const _Counter(),
      );
      await _pump(tester, glass(backdrop: false));
      expect(tester.widget<BackdropFilter>(_backdrop()).enabled, isFalse);

      tester.state<_CounterState>(find.byType(_Counter)).count = 7;
      await _pump(tester, glass(backdrop: true));
      expect(tester.widget<BackdropFilter>(_backdrop()).enabled, isTrue);
      expect(
        tester.state<_CounterState>(find.byType(_Counter)).count,
        7,
        reason: 'the content kept its state',
      );
    });
  });

  testWidgets('flat keeps only the inset edge light, no drop shadow', (
    tester,
  ) async {
    await _pump(
      tester,
      const GlassContainer(flat: true, child: SizedBox()),
      brightness: Brightness.light,
    );
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(GlassContainer),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((c) => c.painter)
        .whereType<DxSurfacePainter>()
        .single;
    expect(painter.shadows, isNotEmpty);
    expect(painter.shadows.every((s) => s.inset), isTrue);
    expect(
      painter.shadows.length,
      AppTokens.light.shadowCard.where((s) => s.inset).length,
    );
  });

  testWidgets('surfaceOf reports the nearest enclosing role', (tester) async {
    DxSurface? inside;
    DxSurface? outside;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          outside = GlassContainer.surfaceOf(context);
          return GlassContainer(
            surface: DxSurface.sheet,
            child: Builder(
              builder: (context) {
                inside = GlassContainer.surfaceOf(context);
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );
    expect(outside, isNull);
    expect(inside, DxSurface.sheet);
  });

  test('DxSurfacePainter repaints only when a field changes', () {
    const shadows = [DxShadow(color: Colors.black, blur: 8)];
    const a = DxSurfacePainter(color: Colors.white, shadows: shadows);
    expect(
      a.shouldRepaint(
        const DxSurfacePainter(
          color: Colors.white,
          shadows: [DxShadow(color: Colors.black, blur: 8)],
        ),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        const DxSurfacePainter(color: Colors.black, shadows: shadows),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        const DxSurfacePainter(
          color: Colors.white,
          shadows: shadows,
          angle: 145,
        ),
      ),
      isTrue,
    );
  });

  group('cssLine follows the CSS gradient line', () {
    const rect = Rect.fromLTWH(0, 0, 200, 100);

    test('180° runs top to bottom', () {
      final (from, to) = cssLine(rect, 180);
      expect(from.dx, closeTo(100, 1e-9));
      expect(from.dy, closeTo(0, 1e-9));
      expect(to.dy, closeTo(100, 1e-9));
    });

    test('90° runs left to right', () {
      final (from, to) = cssLine(rect, 90);
      expect(from.dx, closeTo(0, 1e-9));
      expect(from.dy, closeTo(50, 1e-9));
      expect(to.dx, closeTo(200, 1e-9));
    });

    test('145° reaches past the corners, as CSS does', () {
      final (from, to) = cssLine(rect, 145);
      // half = (200·sin145° + 100·|cos145°|) / 2 = 98.32
      expect(from.dx, closeTo(43.61, 0.01));
      expect(from.dy, closeTo(-30.54, 0.01));
      expect(to.dx, closeTo(156.39, 0.01));
      expect(to.dy, closeTo(130.54, 0.01));
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => const SizedBox();
}
