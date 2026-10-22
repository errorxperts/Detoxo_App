import 'package:detoxo/core/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() => AppTheme.dark();

/// A 360 dp phone at the largest system font size Android offers (2.0x),
/// inside the usual page gutter. An overflow is a FlutterError the test
/// binding turns into a failure, so pumping cleanly IS the check.
Future<void> _pumpLarge(WidgetTester tester, Widget child) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Center(child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('2.0x text on a 360 dp screen', () {
    testWidgets(
      'a three-label GlassSegmented ellipsizes instead of overflowing',
      (tester) async {
        // The widget screen's size and theme pickers, which overflowed by 21 and
        // 16 px — plus an icon, which must survive the squeeze.
        await _pumpLarge(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassSegmented(
                segments: const [
                  (label: 'Small', icon: null),
                  (label: 'Medium', icon: null),
                  (label: 'Large', icon: null),
                ],
                selectedIndex: 1,
                onChanged: (_) {},
                height: AppSizes.controlHeight,
              ),
              GlassSegmented(
                segments: const [
                  (label: 'System', icon: Icons.brightness_auto_rounded),
                  (label: 'Light', icon: Icons.light_mode_rounded),
                  (label: 'Dark', icon: Icons.dark_mode_rounded),
                ],
                selectedIndex: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.brightness_auto_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'a long PrimaryButton label ellipsizes instead of overflowing',
      (tester) async {
        await _pumpLarge(
          tester,
          PrimaryButton(
            label: 'Add to home screen',
            icon: Icons.add_to_home_screen_rounded,
            expand: true,
            onPressed: () {},
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.add_to_home_screen_rounded), findsOneWidget);
      },
    );

    testWidgets('a hugging PrimaryButton still lays out in an unbounded Row', (
      tester,
    ) async {
      // A row gives a non-expanded button unbounded width; the label's
      // Flexible must stay loose there, not demand a bounded flex.
      await _pumpLarge(
        tester,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [PrimaryButton(label: 'OK', onPressed: () {})],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('OK'), findsOneWidget);
    });
  });

  group('screen readers hear a button once', () {
    // TalkBack read "Continue\nContinue": the explicit label and the visible
    // Text both landed in one node.
    Future<void> pump(WidgetTester tester, Widget button) => tester.pumpWidget(
      MaterialApp(
        theme: _theme(),
        home: Scaffold(body: Center(child: button)),
      ),
    );

    testWidgets('PrimaryButton, enabled and disabled', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final onPressed in [() {}, null]) {
        await pump(
          tester,
          PrimaryButton(label: 'Continue', onPressed: onPressed),
        );
        expect(tester.getSemantics(find.text('Continue')).label, 'Continue');
        expect(find.bySemanticsLabel('Continue'), findsOneWidget);
      }
      semantics.dispose();
    });

    testWidgets('SecondaryButton and AnimatedIconButton', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SecondaryButton(label: 'Grant', onPressed: () {}),
            AnimatedIconButton(
              label: 'Upgrade',
              icon: AppIcon.check,
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(tester.getSemantics(find.text('Grant')).label, 'Grant');
      expect(tester.getSemantics(find.text('Upgrade')).label, 'Upgrade');
      semantics.dispose();
    });

    testWidgets('a custom LiquidPill label replaces the visible text', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      for (final onPressed in [() {}, null]) {
        await pump(
          tester,
          LiquidPill(
            tint: const Color(0xFF6E7BFF),
            onPressed: onPressed,
            semanticLabel: 'Grant accessibility access',
            child: const Text('Grant'),
          ),
        );
        expect(
          tester.getSemantics(find.text('Grant')).label,
          'Grant accessibility access',
        );
      }
      semantics.dispose();
    });
  });
}
