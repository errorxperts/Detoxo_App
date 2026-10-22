import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

/// The surface painters under [of]: a button's own skin, if it has one.
Iterable<DxSurfacePainter> _skins(WidgetTester tester, Finder of) => tester
    .widgetList<CustomPaint>(
      find.descendant(of: of, matching: find.byType(CustomPaint)),
    )
    .map((c) => c.painter)
    .whereType<DxSurfacePainter>();

/// The painted skin itself, inside the 48 dp target.
final Finder _skin = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is DxSurfacePainter,
);

void main() {
  const t = AppTokens.light;

  testWidgets('PrimaryButton: the 54 px soft button, ink label, one tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PrimaryButton(label: 'Save', onPressed: () => taps++)),
    );
    final skin = _skins(tester, find.byType(PrimaryButton)).single;
    expect(skin.gradient, [t.buttonFrom, t.buttonTo]);
    expect(skin.angle, 145);
    expect(skin.shadows, t.shadowButton);
    expect(skin.color, isNull, reason: 'no accent fill');
    expect(tester.getSize(_skin).height, 54);
    expect(tester.widget<Text>(find.text('Save')).style!.color, t.ink);

    await tester.tap(find.text('Save'));
    expect(taps, 1);
  });

  testWidgets('a disabled PrimaryButton is inert and says so', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const PrimaryButton(label: 'Save', onPressed: null)),
    );
    expect(
      tester.getSemantics(find.byType(PrimaryButton)),
      isSemantics(
        label: 'Save',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(PrimaryButton),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.45,
    );
    await tester.tap(find.text('Save'), warnIfMissed: false);
    semantics.dispose();
  });

  testWidgets('SecondaryButton: ink-2 label, no surface, a 48 dp target', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(SecondaryButton(label: 'Cancel', onPressed: () {})),
    );
    expect(_skins(tester, find.byType(SecondaryButton)), isEmpty);
    expect(tester.widget<Text>(find.text('Cancel')).style!.color, t.ink2);
    final size = tester.getSize(find.byType(SecondaryButton));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('a destructive SecondaryButton is over text, never a fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SecondaryButton(
          label: 'Delete rule',
          destructive: true,
          onPressed: () {},
        ),
      ),
    );
    expect(_skins(tester, find.byType(SecondaryButton)), isEmpty);
    expect(
      tester.widget<Text>(find.text('Delete rule')).style!.color,
      t.accentText(t.over),
    );
  });

  testWidgets('LiquidPill: the accent at kPill under the sheen, and taps', (
    tester,
  ) async {
    var taps = 0;
    const tint = Color(0xFF3574FA);
    await tester.pumpWidget(
      _host(
        LiquidPill(
          tint: tint,
          onPressed: () => taps++,
          child: const Text('Unblock'),
        ),
      ),
    );
    final skin = _skins(tester, find.byType(LiquidPill)).single;
    expect(skin.color, tint.withValues(alpha: t.kPill));
    expect(skin.gradient, [t.pillHi, t.pillLo]);
    expect(skin.shadows.last.color, tint.withValues(alpha: t.kPillGlow));
    expect(tester.getSize(_skin).height, 44);
    expect(tester.getSize(find.byType(LiquidPill)).height, 48);

    await tester.tap(find.text('Unblock'));
    expect(taps, 1);
  });

  testWidgets('GlassFab: a glass pill named by its label', (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        GlassFab(
          icon: const Icon(Icons.add_rounded),
          label: 'Add app',
          onPressed: () => taps++,
        ),
      ),
    );
    expect(
      tester
          .widget<GlassContainer>(
            find.descendant(
              of: find.byType(GlassFab),
              matching: find.byType(GlassContainer),
            ),
          )
          .surface,
      DxSurface.glass,
    );
    expect(find.bySemanticsLabel('Add app'), findsOneWidget);
    await tester.tap(find.byType(GlassFab));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('InfoButton opens its message in a sheet; Got it closes it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const InfoButton('Resize on your phone')));
    expect(find.text('Resize on your phone'), findsNothing);

    await tester.tap(find.byType(InfoButton));
    await tester.pumpAndSettle();
    expect(find.text('Resize on your phone'), findsOneWidget);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Resize on your phone'), findsNothing);
  });
}
