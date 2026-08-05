import 'package:detoxo/core/design_system/components/toggle.dart';
import 'package:detoxo/core/design_system/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme pulls google_fonts, which stalls under flutter_test.
ThemeData _theme() => ThemeData(
  brightness: Brightness.dark,
  extensions: const [GlassTokens.dark],
);

Future<bool> _pump(
  WidgetTester tester, {
  bool initial = false,
  bool enabled = true,
  String? label,
}) async {
  var value = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme(),
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => AppToggle(
              value: value,
              enabled: enabled,
              label: label,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return value;
}

/// The thumb's left edge, in global coordinates.
double _thumbLeft(WidgetTester tester) => tester
    .getTopLeft(
      find.descendant(of: find.byType(Align), matching: find.byType(Container)),
    )
    .dx;

void main() {
  testWidgets('tap toggles and slides the thumb right', (tester) async {
    await _pump(tester);
    final off = _thumbLeft(tester);

    await tester.tap(find.byType(AppToggle));
    await tester.pumpAndSettle();

    expect(_thumbLeft(tester), greaterThan(off));
  });

  testWidgets('clears the 48dp hit target without a label', (tester) async {
    await _pump(tester);
    expect(
      tester.getSize(find.byType(AppToggle)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('tapping the label row toggles', (tester) async {
    await _pump(tester, label: 'Block reels');
    final off = _thumbLeft(tester);

    await tester.tap(find.text('Block reels'));
    await tester.pumpAndSettle();

    expect(_thumbLeft(tester), greaterThan(off));
  });

  testWidgets('disabled ignores taps', (tester) async {
    await _pump(tester, enabled: false);
    final off = _thumbLeft(tester);

    await tester.tap(find.byType(AppToggle), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(_thumbLeft(tester), off);
  });
}
