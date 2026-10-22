import 'package:detoxo/core/design_system/design_system.dart';
import 'package:detoxo/features/onboarding/domain/entities/onboarding_progress.dart';
import 'package:detoxo/features/onboarding/presentation/steps/projection_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ThemeData _theme() => AppTheme.dark();

Future<void> _pump(WidgetTester tester, OnboardingProgress progress) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: _theme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectionStep(progress: progress),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scrubbing the horizon recounts the days', (tester) async {
    // 2.5 h × 365 / 24 = 38 days a year.
    await _pump(
      tester,
      const OnboardingProgress(band: ScreenTimeBand.between2And3h),
    );
    expect(find.text('190'), findsOneWidget);
    expect(find.text('of your next 5 years'), findsOneWidget);
    expect(find.byType(ProgressRing), findsOneWidget);

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
  });

  testWidgets('a record without a band renders the fallback only', (
    tester,
  ) async {
    await _pump(tester, const OnboardingProgress());
    expect(find.textContaining('built to never end'), findsOneWidget);
    expect(find.byType(ProgressRing), findsNothing);
    expect(find.byType(GlassSegmented), findsNothing);
  });
}
