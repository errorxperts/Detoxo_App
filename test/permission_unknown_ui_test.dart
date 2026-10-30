import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the `unknown`-state rendering (EVO-014): a status read that didn't
/// answer must render neutral — never as denied. Before this, unknown
/// collapsed into the red denied state on every cold start or flaky channel
/// read. Also pins the control: a toggle for the grant, a pill for a named
/// action.
void main() {
  group('PermissionCard', () {
    var grants = 0;
    setUp(() => grants = 0);

    Future<void> pump(
      WidgetTester tester, {
      required bool granted,
      bool unknown = false,
      String? actionLabel,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: PermissionCard(
            icon: Icons.security,
            title: 'Accessibility',
            why: 'Detects reels on screen.',
            granted: granted,
            unknown: unknown,
            actionLabel: actionLabel,
            onGrant: () => grants++,
          ),
        ),
      ),
    );

    AppToggle toggle(WidgetTester tester) =>
        tester.widget<AppToggle>(find.byType(AppToggle));

    testWidgets('granted is an on toggle that holds still, no why', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, granted: true);
      expect(toggle(tester).value, isTrue);
      expect(find.byType(LiquidPill), findsNothing);
      expect(find.text('Checking…'), findsNothing);
      // Done rows collapse to one line so what is left stands out.
      expect(find.text('Detects reels on screen.'), findsNothing);
      // Android's to undo: a tap does nothing, and TalkBack gets no action.
      await tester.tap(find.byType(AppToggle), warnIfMissed: false);
      expect(grants, 0);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Accessibility').last),
        matchesSemantics(
          label: 'Accessibility',
          hasToggledState: true,
          isToggled: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('unknown renders neutral "Checking…", not a denied row', (
      tester,
    ) async {
      await pump(tester, granted: false, unknown: true);
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(AppToggle), findsNothing);
      expect(find.byType(LiquidPill), findsNothing);
    });

    testWidgets('denied is an off toggle that asks for the grant', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, granted: false);
      // The toggle is the status; no separate "Needs access" word.
      expect(find.text('Needs access'), findsNothing);
      expect(find.text('Detects reels on screen.'), findsOneWidget);
      expect(find.text('Checking…'), findsNothing);
      expect(toggle(tester).value, isFalse);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Accessibility').last),
        matchesSemantics(
          label: 'Accessibility',
          hasToggledState: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(AppToggle));
      expect(grants, 1);
      semantics.dispose();
    });

    testWidgets('a named action stays the brand accent pill', (tester) async {
      await pump(tester, granted: false, actionLabel: 'Fix this');
      expect(find.byType(AppToggle), findsNothing);
      expect(find.bySemanticsLabel('Fix this Accessibility'), findsOneWidget);
      final pill = tester.widget<LiquidPill>(find.byType(LiquidPill));
      expect(pill.tint, AppTokens.dark.brand.main);
      await tester.tap(find.text('Fix this'));
      expect(grants, 1);
    });

    testWidgets('its own panel standalone, none on a surface', (tester) async {
      await pump(tester, granted: false);
      expect(find.byType(GlassContainer), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: GlassContainer(
              child: PermissionCard(
                icon: Icons.security,
                title: 'Accessibility',
                why: 'Detects reels on screen.',
                granted: true,
                onGrant: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(GlassContainer), findsOneWidget);
    });
  });
}
