import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, AppChip chip) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: Center(child: chip)),
  ),
);

void main() {
  // The nudge-cap picker's one-digit chips drew a 40 px wide target.
  testWidgets('a one-character chip still takes a 48x48 tap', (tester) async {
    for (final momentary in [false, true]) {
      await _pump(
        tester,
        AppChip(
          label: '4',
          selected: true,
          momentary: momentary,
          onSelected: () {},
        ),
      );
      final size = tester.getSize(find.byType(AppChip));
      expect(size.width, greaterThanOrEqualTo(AppSizes.minTapTarget));
      expect(size.height, greaterThanOrEqualTo(AppSizes.minTapTarget));
    }
  });

  testWidgets('only a picked toggle chip shows the check', (tester) async {
    Future<bool> checked({required bool selected, bool momentary = false}) =>
        _pump(
          tester,
          AppChip(
            label: 'Mon',
            selected: selected,
            momentary: momentary,
            onSelected: () {},
          ),
        ).then((_) => find.byIcon(Icons.check_rounded).evaluate().isNotEmpty);

    expect(await checked(selected: true), isTrue);
    expect(await checked(selected: false), isFalse);
    expect(await checked(selected: true, momentary: true), isFalse);
  });

  // Unpicked chips reserve the check's room, so a Wrap of days never reflows.
  testWidgets('picking a chip keeps its width', (tester) async {
    Future<double> width({required bool selected}) async {
      await _pump(
        tester,
        AppChip(label: 'Mon', selected: selected, onSelected: () {}),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(GlassContainer)).width;
    }

    expect(await width(selected: true), await width(selected: false));
  });
}
