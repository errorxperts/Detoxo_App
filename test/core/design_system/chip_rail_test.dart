import 'package:detoxo/core/design_system/components/selection.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme pulls google_fonts, which stalls under flutter_test.
ThemeData _theme() => ThemeData(
  brightness: Brightness.dark,
  extensions: const [GlassTokens.dark],
);

/// Chips wide enough that five overflow the 800 dp test viewport.
Widget _chip(String label) =>
    SizedBox(width: 200, height: 40, child: Text(label));

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    theme: _theme(),
    home: Scaffold(
      body: ChipRail(
        leading: _chip('L'),
        trailing: _chip('T'),
        chips: [for (var i = 0; i < 5; i++) _chip('c$i')],
      ),
    ),
  ),
);

double _y(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label)).dy;

double _x(WidgetTester tester, String label) =>
    tester.getTopLeft(find.text(label)).dx;

void main() {
  testWidgets('splits the chips in half; leading opens row 1, trailing '
      'closes row 2', (tester) async {
    await _pump(tester);
    // 5 ~/ 2 = 2 on top: L c0 c1 / c2 c3 c4 T.
    expect(_y(tester, 'L'), _y(tester, 'c1'));
    expect(_y(tester, 'c2'), greaterThan(_y(tester, 'c1')));
    expect(_y(tester, 'T'), _y(tester, 'c4'));
    expect(_x(tester, 'L'), lessThan(_x(tester, 'c0')));
    expect(_x(tester, 'T'), greaterThan(_x(tester, 'c4')));
  });

  testWidgets('both rows scroll together as one rail', (tester) async {
    await _pump(tester);
    final top = _x(tester, 'c0');
    final bottom = _x(tester, 'c2');
    await tester.drag(find.byType(ChipRail), const Offset(-300, 0));
    await tester.pumpAndSettle();
    final moved = top - _x(tester, 'c0');
    expect(moved, greaterThan(0));
    expect(
      bottom - _x(tester, 'c2'),
      moved,
      reason: 'one scroll view carries both rows',
    );
  });
}
