import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/additional_feature/showcase_view/presentation/widgets/showcase_tooltip_card.dart';
import 'package:detoxo/features/additional_feature/showcase_view/showcase_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

/// Pumps the tour card for [step] at [index] of [total]; returns the
/// (next, skip) tap counts, read after the test's taps.
Future<({int Function() next, int Function() skip})> _pump(
  WidgetTester tester, {
  ShowcaseStep? step,
  int index = 1,
  int total = featureShowcaseStepCount,
  bool reduceMotion = false,
  double textScale = 1,
  ThemeData? theme,
}) async {
  var next = 0;
  var skip = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduceMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: ShowcaseTooltipCard(
            step: step ?? featureShowcaseSteps[index],
            index: index,
            total: total,
            onNext: () => next++,
            onSkip: () => skip++,
          ),
        ),
      ),
    ),
  );
  return (next: () => next, skip: () => skip);
}

void main() {
  testWidgets('Skip and Next are at least 48 x 48', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    for (final button in [SecondaryButton, PrimaryButton]) {
      final size = tester.getSize(find.byType(button));
      expect(size.width, greaterThanOrEqualTo(48), reason: '$button');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$button');
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets("screen readers hear 'Step 2 of 6'", (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 2 of 6'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('tapping Next fires onNext once', (tester) async {
    final taps = await _pump(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(taps.next(), 1);
    expect(taps.skip(), 0);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(taps.skip(), 1);
    expect(taps.next(), 1);
  });

  testWidgets('a glyph step that is the last one reads Done', (tester) async {
    final taps = await _pump(
      tester,
      step: ShowcaseStep(
        key: GlobalKey(),
        icon: Icons.feedback_outlined,
        title: 'Feedback button',
        body: 'Tap it any time to capture the screen, mark it up and send it.',
      ),
      index: 0,
      total: 1,
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.feedback_outlined), findsOneWidget);
    await tester.tap(find.text('Done'));
    expect(taps.next(), 1);
  });

  testWidgets('the card never moves on its own', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('Reduce Motion: no entrance, no scheduled frame', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('neither tour host bobs the tooltip', (tester) async {
    await tester.pumpWidget(
      buildFeatureShowcaseScope(onSeen: () {}, child: const SizedBox()),
    );
    expect(ShowcaseView.get().disableMovingAnimation, isTrue);

    registerScopedShowcase(scope: 'test', onSeen: () {});
    addTearDown(() => unregisterScopedShowcase('test'));
    expect(ShowcaseView.getNamed('test').disableMovingAnimation, isTrue);
  });

  testWidgets("the spotlight dim is the theme's scrim, not black", (
    tester,
  ) async {
    for (final (theme, t) in [
      (AppTheme.light(), AppTokens.light),
      (AppTheme.dark(), AppTokens.dark),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: buildFeatureShowcaseScope(
            onSeen: () {},
            child: showcaseTarget(
              step: featureShowcaseSteps.first,
              index: 0,
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(); // MaterialApp animates a theme swap
      final spot = tester.widget<Showcase>(find.byType(Showcase));
      expect(spot.overlayColor, t.scrim, reason: '${t.brightness}');
      expect(spot.overlayOpacity, t.kScrim0, reason: '${t.brightness}');
    }
  });

  testWidgets('2x text in both themes: the card grows, nothing overflows', (
    tester,
  ) async {
    // The test font sets every glyph 1 em wide, so the body wraps about twice
    // as often as in Manrope: give it a tall screen.
    tester.view
      ..physicalSize = const Size(400, 1200) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await _pump(tester, textScale: 2, theme: theme);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Next'), findsOneWidget);
    }
  });
}
