import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: ListView(children: [child])),
  ),
);

Finder _icon(IconData icon) => find.byIcon(icon);

void main() {
  testWidgets('a standalone row is exactly one panel', (tester) async {
    await _pump(tester, const GlassListTile(title: 'Theme'));
    expect(find.byType(GlassContainer), findsOneWidget);
    expect(tester.getSize(find.byType(GlassListTile)).height, 56);
  });

  testWidgets('n rows in a PanelGroup share one panel and n-1 hairlines', (
    tester,
  ) async {
    await _pump(
      tester,
      const PanelGroup(
        children: [
          GlassListTile(title: 'One'),
          GlassListTile(title: 'Two'),
          GlassListTile(title: 'Three'),
        ],
      ),
    );
    expect(find.byType(GlassContainer), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect((divider.height, divider.indent, divider.endIndent), (1, 16, 16));
  });

  testWidgets('a row on a sheet draws no surface of its own', (tester) async {
    await _pump(
      tester,
      const GlassContainer(
        surface: DxSurface.sheet,
        child: GlassListTile(title: 'Inside'),
      ),
    );
    expect(find.byType(GlassContainer), findsOneWidget);
  });

  testWidgets('a tappable row with no trailing shows an 18 px ink-3 chevron', (
    tester,
  ) async {
    var taps = 0;
    await _pump(tester, GlassListTile(title: 'Open', onTap: () => taps++));
    final chevron = tester.widget<Icon>(_icon(Icons.chevron_right_rounded));
    expect(chevron.size, 18);
    expect(chevron.color, AppTokens.light.ink3);
    await tester.tap(find.text('Open'));
    expect(taps, 1);
  });

  testWidgets('no chevron without a tap, or with a trailing', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          const GlassListTile(title: 'Static'),
          GlassListTile(
            title: 'Toggle',
            trailing: const Text('On'),
            onTap: () {},
          ),
        ],
      ),
    );
    expect(_icon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('selection rows: a check when picked, nothing when not', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      PanelGroup(
        children: [
          GlassListTile(title: 'Picked', selected: true, onTap: () {}),
          GlassListTile(title: 'Other', selected: false, onTap: () {}),
        ],
      ),
    );
    expect(_icon(Icons.check_rounded), findsOneWidget);
    expect(
      tester.widget<Icon>(_icon(Icons.check_rounded)).color,
      AppTokens.light.ink,
    );
    // An unpicked option is not a navigation row.
    expect(_icon(Icons.chevron_right_rounded), findsNothing);
    expect(
      tester.getSemantics(find.text('Picked')),
      isSemantics(label: 'Picked', isButton: true, isSelected: true),
    );
    handle.dispose();
  });
}
