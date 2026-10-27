import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the `unknown`-state rendering (EVO-014): a status read that didn't
/// answer must render neutral — never as denied. Before this, unknown
/// collapsed into the red denied state on every cold start or flaky channel
/// read.
void main() {
  group('PermissionCard', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool granted,
      bool unknown = false,
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
            onGrant: () {},
          ),
        ),
      ),
    );

    testWidgets('granted reads On, no action button, no why', (tester) async {
      await pump(tester, granted: true);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Grant'), findsNothing);
      expect(find.text('Checking…'), findsNothing);
      // Done rows collapse to one line so what is left stands out.
      expect(find.text('Detects reels on screen.'), findsNothing);
    });

    testWidgets('unknown renders neutral "Checking…", not a denied row', (
      tester,
    ) async {
      await pump(tester, granted: false, unknown: true);
      expect(find.text('Checking…'), findsOneWidget);
      expect(find.text('Grant'), findsNothing);
      expect(find.text('On'), findsNothing);
    });

    testWidgets('denied renders the Grant action', (tester) async {
      await pump(tester, granted: false);
      // The Grant button is the status; no separate "Needs access" word.
      expect(find.text('Needs access'), findsNothing);
      expect(find.text('Detects reels on screen.'), findsOneWidget);
      expect(find.text('Grant'), findsOneWidget);
      expect(find.bySemanticsLabel('Grant Accessibility'), findsOneWidget);
      expect(find.text('Checking…'), findsNothing);
      // Highlighted: the brand accent pill, not a quiet text button.
      final grant = tester.widget<LiquidPill>(
        find.ancestor(
          of: find.text('Grant'),
          matching: find.byType(LiquidPill),
        ),
      );
      expect(grant.tint, AppTokens.dark.brand.main);
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
