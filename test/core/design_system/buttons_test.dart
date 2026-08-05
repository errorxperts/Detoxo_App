import 'package:detoxo/core/design_system/adaptive/platform_adaptive.dart';
import 'package:detoxo/core/design_system/components/buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final Finder _pill = find.descendant(
  of: find.byType(LiquidPill),
  matching: find.byType(Container),
);

BoxDecoration _pillDecoration(WidgetTester tester) =>
    tester.widget<Container>(_pill).decoration! as BoxDecoration;

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  // The Android skin is what this file is about; without this the branch would
  // follow the host OS (Cupertino on a Mac, Material on CI).
  setUp(() => PlatformAdaptive.debugUseCupertino = false);
  tearDown(() => PlatformAdaptive.debugUseCupertino = null);

  testWidgets('enabled pill paints a brand gradient + glow and fires taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        LiquidPill(
          tint: const Color(0xFF6E7BFF),
          onPressed: () => taps++,
          child: const Text('Grant'),
        ),
      ),
    );

    final deco = _pillDecoration(tester);
    expect(deco.gradient, isNotNull);
    expect(deco.boxShadow, isNotEmpty);

    await tester.tap(find.text('Grant'));
    expect(taps, 1);
  });

  testWidgets('disabled pill drops the glow and swallows taps', (tester) async {
    await tester.pumpWidget(
      _host(
        const LiquidPill(
          tint: Color(0xFF6E7BFF),
          onPressed: null,
          child: Text('Grant'),
        ),
      ),
    );

    expect(_pillDecoration(tester).boxShadow, isNull);
    await tester.tap(find.text('Grant'), warnIfMissed: false);
    // No callback to assert on — reaching here without an exception is the check.
  });

  testWidgets('secondary is a shorter outlined pill, not a small hero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(SecondaryButton(label: 'Grant', onPressed: () {})),
    );

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(SecondaryButton),
        matching: find.byType(Container),
      ),
    );
    final deco = box.decoration! as BoxDecoration;
    expect(deco.gradient, isNull, reason: 'outlined, not filled brand');
    expect(deco.boxShadow, isNull, reason: 'only the hero CTA glows');
    expect(deco.border, isNotNull);
    expect(
      tester.getSize(find.byType(Container).last).height,
      lessThan(44),
      reason: 'shorter than the hero pill',
    );
  });
}
