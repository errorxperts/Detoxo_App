import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:detoxo/features/onboarding/presentation/steps/projection_step.dart';
import 'package:detoxo/features/onboarding/presentation/widgets/screen_time_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() => AppTheme.dark();

/// Under Reduce Motion, where `pumpAndSettle` also proves nothing loops.
Future<void> _pumpChild(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: theme ?? _theme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(WidgetTester tester, OnboardingProgress progress) =>
    _pumpChild(tester, ProjectionStep(progress: progress));

void main() {
  testWidgets('scrubbing the horizon recounts the days', (tester) async {
    // 2.5 h × 365 / 24 = 38 days a year.
    await _pump(
      tester,
      const OnboardingProgress(band: ScreenTimeBand.between2And3h),
    );
    expect(find.text('190'), findsOneWidget);
    expect(find.text('of your next 5 years'), findsOneWidget);
    final ring = tester.widget<ProgressRing>(find.byType(ProgressRing));
    expect(ring.palette, AppTokens.dark.brand);
    expect(find.byType(GlassSegmented), findsOneWidget);

    await tester.tap(find.text('10 years'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('380'), findsOneWidget);
    expect(find.text('of your next 10 years'), findsOneWidget);

    await tester.tap(find.text('1 year'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('38'), findsOneWidget);
    expect(find.text('of your next year'), findsOneWidget);
  });

  testWidgets('"Not sure" reads as the average it stands for', (tester) async {
    await _pump(
      tester,
      const OnboardingProgress(band: ScreenTimeBand.dontKnow),
    );
    expect(find.textContaining('At about 3 hours a day'), findsOneWidget);
    expect(find.textContaining('Not sure'), findsNothing);
    // The calm copy: the maths, no blame.
    expect(find.textContaining('the feed did'), findsNothing);
  });

  testWidgets('a record without a band renders the fallback only', (
    tester,
  ) async {
    await _pump(tester, const OnboardingProgress());
    expect(find.textContaining('built to never end'), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);
    expect(find.byType(GlassSegmented), findsNothing);
  });

  testWidgets('the daily-limit dial paints in both themes and steps by 15m', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      var value = const Duration(minutes: 90);
      await _pumpChild(
        tester,
        StatefulBuilder(
          builder: (context, setState) => ScreenTimeDial(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
        theme: theme,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('1h 30m'), findsOneWidget);
      // The slider's increase action, as TalkBack sends it.
      tester
          .widget<Semantics>(
            find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == 'Daily limit',
            ),
          )
          .properties
          .onIncrease!();
      await tester.pumpAndSettle();
      expect(value, const Duration(minutes: 105));
      expect(find.text('1h 45m'), findsOneWidget);
    }
  });
}
