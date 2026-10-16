// Real-boot walk of every onboarding step, with a screenshot at each. Runs on
// an attached Android device that is NOT yet onboarded — a fresh install, or
// after `bash tool/qa.sh -d <serial> --reset prep`:
//
//   E2E_TEST=integration_test/onboarding_e2e_test.dart \
//     SHOTS=build/qa/shots-onboarding bash tool/qa.sh -d <serial> e2e
//
// ONE `testWidgets` only, never `pumpAndSettle` — see app_e2e_test.dart. The
// walk ends on the permissions hand-off and grants nothing.
import 'package:detoxo/features/onboarding/presentation/widgets/screen_time_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ignore: always_use_package_imports — integration_test/ is outside lib/, so
// package: cannot reach it. See the header of qa_walk.dart.
import 'qa_walk.dart';

/// Lets a step's staggered entrance (≈ 0.3 s + 80 ms per child) and the
/// projection's 0.7 s count-up land before the framebuffer is grabbed.
Future<void> landed(WidgetTester tester) => settle(tester, frames: 12);

/// Taps Next and waits for the next step's marker to render.
Future<void> next(WidgetTester tester, String marker) async {
  await tester.tap(find.text('Next'));
  expect(
    await waitFor(tester, find.text(marker)),
    isTrue,
    reason: 'Next did not reach "$marker"',
  );
  await landed(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('walks every onboarding step', (tester) async {
    await bootApp();
    final landedOn = await waitForAny(tester, [
      find.text(kOnboardingMarker),
      find.text(kPermissionsMarker),
      find.text(kPinLockMarker),
      find.text(kHomeMarker),
    ]);
    expect(landedOn, isNot(-1), reason: 'splash never routed anywhere');
    expect(
      landedOn,
      0,
      reason:
          'this device is already onboarded; the walk needs a fresh install '
          '(bash tool/qa.sh -d <serial> --reset prep)',
    );
    await landed(tester);
    await step(tester, 'onb-welcome');

    await next(tester, 'A few quick things');
    await step(tester, 'onb-survey');
    await tester.enterText(find.byType(TextField), 'Sam');
    await tester.tap(find.text('2–3h'));
    await settle(tester);
    await tester.tap(find.text('Sleep'));
    await landed(tester);
    expect(find.text('About 38 days a year'), findsOneWidget);
    await step(tester, 'onb-survey-answered');

    await next(tester, 'That’s the maths, not a judgement');
    expect(find.text('190'), findsOneWidget); // 2.5 h × 365 / 24 × 5
    await step(tester, 'onb-projection');
    await tester.tap(find.text('10 years'), warnIfMissed: false);
    await landed(tester);
    expect(find.text('380'), findsOneWidget);
    await step(tester, 'onb-projection-10y');

    await next(tester, 'What should Detoxo guard?');
    await step(tester, 'onb-selection');

    // SectionHeader uppercases: the marker is the rendered string.
    await next(tester, 'DAILY CEILING');
    expect(find.text('Here’s the deal, Sam'), findsOneWidget);
    await step(tester, 'onb-commitment');
    // A tap at 12 o'clock on the dial's 270° arc lands mid-range, away from
    // the 1 h 30 m default.
    final dial = find.byType(ScreenTimeDial);
    await tester.tapAt(tester.getCenter(dial) + const Offset(0, -100));
    await landed(tester);
    expect(find.text('1h 30m'), findsNothing);
    await step(tester, 'onb-commitment-set');

    await tester.tap(find.text('Get started'));
    expect(
      await waitFor(
        tester,
        find.text(kPermissionsMarker),
        timeout: const Duration(seconds: 45),
      ),
      isTrue,
      reason: 'Get started did not hand off to permissions',
    );
    await landed(tester);
    await step(tester, 'onb-handoff');
  });
}
